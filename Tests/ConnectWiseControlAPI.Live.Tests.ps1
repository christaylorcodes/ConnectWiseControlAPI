#Requires -Module Pester

<#
.SYNOPSIS
    Live integration tests against a real ConnectWise ScreenConnect server.

.DESCRIPTION
    Read-only tests that verify actual API connectivity, authentication,
    and response parsing against a live CWC instance. No data is modified.

    Requires environment variables:
        $env:CWC_SERVER   - CWC server hostname (e.g. 'screenconnect.example.com')
        $env:CWC_USER     - Username for Basic auth
        $env:CWC_PASSWORD  - Password for Basic auth

    All tests are skipped when environment variables are not set.

    The module connects once in the top-level BeforeAll and shared read-only
    data (Access sessions) is fetched once there. Per-endpoint data is fetched
    once in each Describe's BeforeAll and the It blocks assert on the cached
    results, keeping the number of network calls to a minimum.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseControlAPI.Live.Tests.ps1 -Output Detailed

    Set environment variables first:
        $env:CWC_SERVER = 'screenconnect.example.com'
        $env:CWC_USER = 'apiuser'
        $env:CWC_PASSWORD = 'password'
#>

BeforeDiscovery {
    $script:HasCredentials = [bool]($env:CWC_SERVER -and $env:CWC_USER -and $env:CWC_PASSWORD)
}

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (& (Join-Path $PSScriptRoot 'TestHelpers\Resolve-TestModuleManifest.ps1')) -Force

    # Variables set in BeforeDiscovery do not survive into the Run phase (Pester 5),
    # so the credential check must be re-evaluated here for the run-time code paths.
    $script:HasCredentials = [bool]($env:CWC_SERVER -and $env:CWC_USER -and $env:CWC_PASSWORD)
    if ($script:HasCredentials) {
        $script:TestServer = $env:CWC_SERVER
        $script:TestCredentials = [PSCredential]::new(
            $env:CWC_USER,
            ($env:CWC_PASSWORD | ConvertTo-SecureString -AsPlainText -Force)
        )

        # Single connection shared by every Describe
        Connect-CWC -Server $script:TestServer -Credentials $script:TestCredentials -Force

        # Access sessions are used by the Session, Session Detail and Last Contact tests
        $script:AccessSessionsError = $null
        try {
            $script:AccessSessions = Get-CWCSession -Type 'Access' -Limit 5
        }
        catch {
            $script:AccessSessionsError = $_
        }
        $script:HasSessions = @($script:AccessSessions | Where-Object { $null -ne $_ }).Count -gt 0
        if ($script:HasSessions) {
            $script:TestSessionGuid = @($script:AccessSessions)[0].SessionID
        }
    }
}

AfterAll {
    # Runs once, after every Describe in this file has finished
    InModuleScope 'ConnectWiseControlAPI' {
        $script:CWCServerConnection = $null
    }
    Get-Module 'ConnectWiseControlAPI' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Authentication
# =============================================================================
Describe 'Live: Connect-CWC' -Skip:(-not $script:HasCredentials) {

    BeforeAll {
        # Connection state established by the top-level BeforeAll - read once
        $module = Get-Module 'ConnectWiseControlAPI'
        $script:Connection = & $module { $script:CWCServerConnection }
    }

    AfterAll {
        # 'rejects invalid credentials' clears the connection - restore it for later Describes
        Connect-CWC -Server $script:TestServer -Credentials $script:TestCredentials -Force
    }

    It 'authenticates successfully' {
        { Connect-CWC -Server $script:TestServer -Credentials $script:TestCredentials -Force } | Should -Not -Throw
    }

    It 'sets CWCServerConnection after auth' {
        $script:Connection | Should -Not -BeNullOrEmpty
        $script:Connection.Server | Should -Not -BeNullOrEmpty
        $script:Connection.Headers | Should -Not -BeNullOrEmpty
    }

    It 'stores the correct server name' {
        $cleanServer = $script:TestServer -replace 'http.*://', ''
        $script:Connection.Server | Should -Be $cleanServer
    }

    It 'extracts an anti-forgery token' {
        $script:Connection.Headers.'x-anti-forgery-token' | Should -Not -BeNullOrEmpty
    }

    It 'skips reconnect when already connected' {
        # Already connected - call should return quickly without error
        { Connect-CWC -Server $script:TestServer -Credentials $script:TestCredentials } | Should -Not -Throw
    }

    It 'rejects invalid credentials' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = $null
        }
        $badCred = [PSCredential]::new('baduser', ('badpass' | ConvertTo-SecureString -AsPlainText -Force))
        $result = Connect-CWC -Server $script:TestServer -Credentials $badCred 2>&1
        $hasError = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $hasError | Should -Not -BeNullOrEmpty
    }
}

# =============================================================================
# Session Groups (simplest read-only call)
# =============================================================================
Describe 'Live: Get-CWCSessionGroup' -Skip:(-not $script:HasCredentials) {

    BeforeAll {
        $script:Groups = Get-CWCSessionGroup
    }

    It 'returns session groups' {
        $script:Groups | Should -Not -BeNullOrEmpty
    }

    It 'returns an array or collection' {
        @($script:Groups).Count | Should -BeGreaterThan 0
    }
}

# =============================================================================
# Sessions
# =============================================================================
Describe 'Live: Get-CWCSession' -Skip:(-not $script:HasCredentials) {

    It 'returns Access sessions without error' {
        # Fetched once in the top-level BeforeAll
        $script:AccessSessionsError | Should -BeNullOrEmpty
    }

    It 'returns Support sessions without error' {
        { Get-CWCSession -Type 'Support' } | Should -Not -Throw
    }

    It 'returns Meeting sessions without error' {
        { Get-CWCSession -Type 'Meeting' } | Should -Not -Throw
    }

    It 'accepts a Group parameter' {
        { Get-CWCSession -Type 'Access' -Group 'All Machines' } | Should -Not -Throw
    }

    It 'accepts a Search parameter' {
        { Get-CWCSession -Type 'Access' -Search 'nonexistent-machine-xyz' } | Should -Not -Throw
    }

    It 'returns session objects with expected properties' {
        if (-not $script:HasSessions) {
            Set-ItResult -Inconclusive -Because 'No Access sessions found on server'
            return
        }
        $first = @($script:AccessSessions)[0]
        # Sessions should have at minimum a SessionID and Name
        $first.PSObject.Properties.Name | Should -Contain 'SessionID'
        $first.PSObject.Properties.Name | Should -Contain 'Name'
    }
}

# =============================================================================
# Session Detail
# =============================================================================
Describe 'Live: Get-CWCSessionDetail' -Skip:(-not $script:HasCredentials) {

    BeforeAll {
        if ($script:HasSessions) {
            $script:SessionDetail = Get-CWCSessionDetail -GUID $script:TestSessionGuid
        }
    }

    # HasSessions is only known at run time, so skip inside each It rather than via -Skip
    It 'returns detail for a real session' {
        if (-not $script:HasSessions) { Set-ItResult -Skipped -Because 'no sessions'; return }
        $script:SessionDetail | Should -Not -BeNullOrEmpty
    }

    It 'detail contains Events property' {
        if (-not $script:HasSessions) { Set-ItResult -Skipped -Because 'no sessions'; return }
        $script:SessionDetail.PSObject.Properties.Name | Should -Contain 'Events'
    }

    It 'detail contains Connections property' {
        if (-not $script:HasSessions) { Set-ItResult -Skipped -Because 'no sessions'; return }
        $script:SessionDetail.PSObject.Properties.Name | Should -Contain 'Connections'
    }
}

# =============================================================================
# Last Contact
# =============================================================================
Describe 'Live: Get-CWCLastContact' -Skip:(-not $script:HasCredentials) {

    It 'returns a datetime or null for a real session' {
        if (-not $script:HasSessions) { Set-ItResult -Skipped -Because 'no sessions'; return }
        $result = Get-CWCLastContact -GUID $script:TestSessionGuid -ErrorAction SilentlyContinue
        if ($null -ne $result) {
            $result | Should -BeOfType [datetime]
        }
    }

    It 'returns boolean with Quiet switch' {
        if (-not $script:HasSessions) { Set-ItResult -Skipped -Because 'no sessions'; return }
        $result = Get-CWCLastContact -GUID $script:TestSessionGuid -Quiet -Seconds 86400 -ErrorAction SilentlyContinue
        if ($null -ne $result) {
            $result | Should -BeOfType [bool]
        }
    }
}

# =============================================================================
# Audit Service
# =============================================================================
Describe 'Live: Get-CWCAuditInfo' -Skip:(-not $script:HasCredentials) {

    BeforeAll {
        $script:AuditInfoError = $null
        try {
            $script:AuditInfo = Get-CWCAuditInfo
        }
        catch {
            $script:AuditInfoError = $_
        }
    }

    It 'returns audit info without error' {
        $script:AuditInfoError | Should -BeNullOrEmpty
    }

    It 'returns data' {
        $script:AuditInfo | Should -Not -BeNullOrEmpty
    }
}

Describe 'Live: Get-CWCAuditLog' -Skip:(-not $script:HasCredentials) {

    It 'returns audit log for date range without error' {
        $end = Get-Date
        $start = $end.AddDays(-1)
        { Get-CWCAuditLog -StartDate $start -EndDate $end } | Should -Not -Throw
    }
}

# =============================================================================
# Security Service
# =============================================================================
Describe 'Live: Get-CWCSecurityConfigurationInfo' -Skip:(-not $script:HasCredentials) {

    BeforeAll {
        $script:SecurityConfigError = $null
        try {
            $script:SecurityConfig = Get-CWCSecurityConfigurationInfo
        }
        catch {
            $script:SecurityConfigError = $_
        }
    }

    It 'returns security configuration without error' {
        $script:SecurityConfigError | Should -BeNullOrEmpty
    }

    It 'contains UserSources' {
        $script:SecurityConfig | Should -Not -BeNullOrEmpty
        $script:SecurityConfig.PSObject.Properties.Name | Should -Contain 'UserSources'
    }

    It 'contains InternalMembershipProvider source' {
        $internal = $script:SecurityConfig.UserSources | Where-Object { $_.ResourceKey -eq 'InternalMembershipProvider' }
        $internal | Should -Not -BeNullOrEmpty
    }
}
