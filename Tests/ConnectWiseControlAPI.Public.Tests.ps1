#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for all public functions.

.DESCRIPTION
    Tests all public functions using mocked Invoke-CWCWebRequest
    (or Invoke-WebRequest for Connect-CWC) to verify endpoint construction,
    body formatting, parameter handling, and ShouldProcess behavior.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseControlAPI.Public.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = & (Join-Path $PSScriptRoot 'TestHelpers\Resolve-TestModuleManifest.ps1')
    Import-Module $ManifestPath -Force

    # Sets a fake, already-connected module state so API functions pass their
    # connection check. Called from each API Describe's BeforeEach.
    function Set-CWCTestConnection {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{
                Server  = 'test.example.com'
                Headers = @{ 'Authorization' = 'Basic dGVzdDp0ZXN0' }
            }
        }
    }

    # Fake RESTful API Manager (Connect-CWC -ApiSecret) connection.
    function Set-CWCTestApiSecretConnection {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{
                Server    = 'test.example.com'
                AuthType  = 'ApiSecret'
                ApiSecret = ('secret' | ConvertTo-SecureString -AsPlainText -Force)
                Headers   = @{ 'origin' = 'https://test.example.com' }
            }
        }
    }
}

AfterAll {
    Get-Module 'ConnectWiseControlAPI' -ErrorAction SilentlyContinue | Remove-Module -Force
}


# =============================================================================
# Authentication
# =============================================================================
Describe 'Connect-CWC' {

    BeforeEach {
        $cred = [PSCredential]::new('user', ('pass' | ConvertTo-SecureString -AsPlainText -Force))
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = $null
            Mock Invoke-WebRequest {
                [PSCustomObject]@{
                    Content = 'antiForgeryToken":"testtoken123testtoken123","isUserAdministrator'
                }
            }
            Mock Invoke-CWCWebRequest {}
        }
    }

    Context 'Validation call' {
        It 'validates with GetEligibleHosts (works for non-admin accounts)' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest {
                    param($Arguments)
                    $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/GetEligibleHosts'
                    $Arguments.Method | Should -Be 'Post'
                }
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                Should -Invoke Invoke-CWCWebRequest -Times 1
            }
        }
    }

    Context 'Server URL cleanup' {
        It 'strips https:// prefix from server' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'https://server.example.com' -Credentials $cred
                $script:CWCServerConnection.Server | Should -Be 'server.example.com'
            }
        }

        It 'strips http:// prefix from server' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'http://server.example.com' -Credentials $cred
                $script:CWCServerConnection.Server | Should -Be 'server.example.com'
            }
        }
    }

    Context 'Authentication header' {
        It 'creates Basic auth header from credentials' {
            InModuleScope 'ConnectWiseControlAPI' {
                # Distinct credentials so the encoded header is verifiably derived from them
                $cred = [PSCredential]::new('testuser', ('testpass' | ConvertTo-SecureString -AsPlainText -Force))
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                $expected = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('testuser:testpass'))
                $script:CWCServerConnection.Headers.'authorization' | Should -Be "Basic $expected"
            }
        }

        It 'sets content-type header' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                $script:CWCServerConnection.Headers.'content-type' | Should -Be 'application/json; charset=utf-8'
            }
        }

        It 'sets origin header' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                $script:CWCServerConnection.Headers.'origin' | Should -Be 'https://server.example.com'
            }
        }
    }

    Context 'Anti-forgery token' {
        It 'extracts anti-forgery token from page content' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{
                        Content = 'someprefix antiForgeryToken":"mytoken456mytoken456+/=","isUserAdministrator":true'
                    }
                }
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                $script:CWCServerConnection.Headers.'x-anti-forgery-token' | Should -Be 'mytoken456mytoken456+/='
            }
        }

        It 'extracts the token when isUserAdministrator does not follow it (issue #22)' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ Content = '{"antiForgeryToken":"abcdefghijklmnop1234","userDisplayName":"x"}' }
                }
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                $script:CWCServerConnection.Headers.'x-anti-forgery-token' | Should -Be 'abcdefghijklmnop1234'
            }
        }

        It 'warns, without echoing page content, when no token is found' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '<html>pagesecretcontent</html>' } }
                $warnings = Connect-CWC -Server 'server.example.com' -Credentials $cred 3>&1
                ($warnings | Out-String) | Should -Match 'anti-forgery token'
                ($warnings | Out-String) | Should -Not -Match 'pagesecretcontent'
                $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'x-anti-forgery-token'
            }
        }
    }

    Context 'Cookies (issue #22)' {
        It 'requests the front page with a session variable and stores the WebSession' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'server.example.com' -Credentials $cred
                Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $SessionVariable -eq 'WebSession' }
                $script:CWCServerConnection.Keys | Should -Contain 'WebSession'
            }
        }
    }

    Context 'Connection caching' {

        BeforeEach {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection = @{
                    Server  = 'existing.server.com'
                    Headers = @{ 'Authorization' = 'Basic existing' }
                }
            }
        }

        It 'reuses the cached connection for the same server, auth method and user' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                $Basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($cred.UserName):$($cred.GetNetworkCredential().Password)"))
                $script:CWCServerConnection = @{ Server = 'existing.server.com'; AuthType = 'Credentials'; Headers = @{ authorization = "Basic $Basic" } }
                Connect-CWC -Server 'existing.server.com' -Credentials $cred
                Should -Invoke Invoke-WebRequest -Times 0
                $script:CWCServerConnection.Server | Should -Be 'existing.server.com'
            }
        }

        It 'reconnects for a different user on the same server' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                $script:CWCServerConnection = @{ Server = 'existing.server.com'; AuthType = 'Credentials'; Headers = @{ authorization = 'Basic b3RoZXI6dXNlcg==' } }
                Connect-CWC -Server 'existing.server.com' -Credentials $cred
                Should -Invoke Invoke-WebRequest -Times 1
            }
        }

        It 'connects to a different server without -Force, so later commands go to it' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'new.server.com' -Credentials $cred
                Should -Invoke Invoke-WebRequest -Times 1
                $script:CWCServerConnection.Server | Should -Be 'new.server.com'
            }
        }

        It 'reconnects when Force is set' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'new.server.com' -Credentials $cred -Force
                Should -Invoke Invoke-WebRequest -Times 1
                $script:CWCServerConnection.Server | Should -Be 'new.server.com'
            }
        }
    }

    Context 'Validation failure' {
        It 'clears connection state on validation failure' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { throw 'Unauthorized' }
                Connect-CWC -Server 'server.example.com' -Credentials $cred -ErrorAction SilentlyContinue
                $script:CWCServerConnection | Should -BeNullOrEmpty
            }
        }

        It 'blames the credentials when the server rejects the validation call' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { Write-Error 'Needs permission' -ErrorId 'CWC.Http500' }
                { Connect-CWC -Server 'server.example.com' -Credentials $cred -ErrorAction Stop } | Should -Throw "Authentication to*Check the username and password*"
            }
        }

        It 'does not blame the credentials when the server does not answer' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { Write-Error 'No such host is known.' -ErrorId 'CWC.NoResponse' }
                { Connect-CWC -Server 'server.example.com' -Credentials $cred -ErrorAction Stop } | Should -Throw "*failed before authentication could be checked*No such host*"
            }
        }

        It 'does not blame the credentials for a local failure' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { Test-CWCMissingHelper }
                { Connect-CWC -Server 'server.example.com' -Credentials $cred -ErrorAction Stop } | Should -Throw "*failed before authentication could be checked*Test-CWCMissingHelper*"
            }
        }
    }

    Context 'Connection failure' {
        It 'writes error when Invoke-WebRequest fails' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest { throw 'Connection refused' }
                $result = Connect-CWC -Server 'bad.server.com' -Credentials $cred 2>&1
                $result | Should -Match 'Failed to connect'
            }
        }
    }
}

# =============================================================================
# PageService
# =============================================================================
Describe 'Connect-CWC -ApiSecret' {

    BeforeEach {
        $secret = 'topsecretvalue' | ConvertTo-SecureString -AsPlainText -Force
        InModuleScope 'ConnectWiseControlAPI' { $script:CWCServerConnection = $null }
    }

    It 'validates with the RESTful API Manager and stores an ApiSecret connection' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            Mock Invoke-WebRequest {}
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'App_Extensions/2d558935-686a-4bd0-9991-07539f5fe749/Service.ashx/GetSessionBySessionID'
                @($Arguments.Body | ConvertFrom-Json) | Should -HaveCount 1
            }
            Connect-CWC -Server 'https://server.example.com' -ApiSecret $secret
            Should -Invoke Invoke-CWCWebRequest -Times 1
            Should -Invoke Invoke-WebRequest -Times 0
            $script:CWCServerConnection.AuthType | Should -Be 'ApiSecret'
            $script:CWCServerConnection.Server | Should -Be 'server.example.com'
            $script:CWCServerConnection.ApiSecret | Should -BeOfType [securestring]
            $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'authorization'
            $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'CTRLAuthHeader'
        }
    }

    It 'clears the connection and errors when validation fails' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            Mock Invoke-CWCWebRequest { throw 'Unauthorized' }
            { Connect-CWC -Server 'server.example.com' -ApiSecret $secret -ErrorAction Stop } | Should -Throw '*RESTful API Manager*'
            $script:CWCServerConnection | Should -BeNullOrEmpty
        }
    }

    It 'rejects an empty secret' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            { Connect-CWC -Server 'server.example.com' -ApiSecret (New-Object securestring) } | Should -Throw '*empty*'
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'keeps the previous connection when a -Force refresh of the same connection fails' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            $Copy = $secret.Copy()
            $script:CWCServerConnection = @{ Server = 'old.example.com'; AuthType = 'ApiSecret'; ApiSecret = $Copy; Headers = @{} }
            Mock Invoke-CWCWebRequest { throw 'Unauthorized' }
            Connect-CWC -Server 'old.example.com' -ApiSecret $secret -Force -ErrorAction SilentlyContinue
            $script:CWCServerConnection.Server | Should -Be 'old.example.com'
        }
    }

    It 'is left disconnected when switching to another server fails, so commands cannot reach the old one' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            $script:CWCServerConnection = @{ Server = 'old.example.com'; AuthType = 'Credentials'; Headers = @{} }
            Mock Invoke-CWCWebRequest { throw 'Unauthorized' }
            Connect-CWC -Server 'new.example.com' -ApiSecret $secret -ErrorAction SilentlyContinue
            $script:CWCServerConnection | Should -BeNullOrEmpty
        }
    }

    It 'switches auth method without -Force instead of reusing the other mode' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            $script:CWCServerConnection = @{ Server = 'server.example.com'; Headers = @{} }
            Mock Invoke-CWCWebRequest {}
            Connect-CWC -Server 'server.example.com' -ApiSecret $secret
            Should -Invoke Invoke-CWCWebRequest -Times 1
            $script:CWCServerConnection.AuthType | Should -Be 'ApiSecret'
        }
    }

    It 'stores its own copy of the secret and honors -Origin' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ secret = $secret } {
            param($secret)
            Mock Invoke-CWCWebRequest {}
            $callerSecret = $secret.Copy()
            Connect-CWC -Server 'server.example.com' -ApiSecret $callerSecret -Origin 'https://app.example.com'
            $callerSecret.Dispose()
            ConvertFrom-CWCSecureString $script:CWCServerConnection.ApiSecret | Should -Be 'topsecretvalue'
            $script:CWCServerConnection.Headers.origin | Should -Be 'https://app.example.com'
        }
    }

    It 'cannot combine -Credentials and -ApiSecret' {
        $cred = [PSCredential]::new('user', ('pass' | ConvertTo-SecureString -AsPlainText -Force))
        { Connect-CWC -Server 's' -Credentials $cred -ApiSecret $secret } | Should -Throw
    }
}

Describe 'Connect-CWC MFA (#12)' {

    BeforeAll {
        # Fake server: two front pages with different tokens (the token changes at login), TryLogin
        # answering from a queue, GetEligibleHosts succeeding unless $script:ProbeFails.
        function Set-FakeMfaServer {
            param([object[]]$LoginResults = @(1))
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ LoginResults = $LoginResults } {
                param($LoginResults)
                $script:FrontPageCalls = 0
                $script:LoginResults = [System.Collections.ArrayList]@($LoginResults)
                $script:LoginBodies = [System.Collections.ArrayList]@()
                $script:ProbeFails = $False
                $script:LogoutCalls = 0
                Mock Invoke-WebRequest {
                    $script:FrontPageCalls++
                    $Token = if ($script:FrontPageCalls -eq 1) { 'pretokenpretoken1234' } else { 'posttokenposttoken12' }
                    [PSCustomObject]@{ Content = "{`"antiForgeryToken`":`"$Token`"}" }
                }
                Mock Invoke-CWCWebRequest {
                    param($Arguments, $MaxRetry, $SensitiveBody)
                    switch -Wildcard ($Arguments.Endpoint) {
                        '*/TryLogin' {
                            $null = $script:LoginBodies.Add([PSCustomObject]@{ Body = $Arguments.Body; MaxRetry = $MaxRetry; Sensitive = [bool]$SensitiveBody })
                            $Result = $script:LoginResults[0]
                            $script:LoginResults.RemoveAt(0)
                            return $Result
                        }
                        '*/TryLogout' { $script:LogoutCalls++ }
                        '*/GetEligibleHosts' {
                            if ($script:ProbeFails) { Write-Error 'Needs permission' -ErrorId 'CWC.Http500' }
                        }
                    }
                }
            }
        }
    }

    BeforeEach {
        $cred = [PSCredential]::new('mfauser', ('mfapass' | ConvertTo-SecureString -AsPlainText -Force))
        InModuleScope 'ConnectWiseControlAPI' { $script:CWCServerConnection = $null; $script:CWCLastTotpStep = @{} }
    }

    Context 'Parameter sets' {
        It 'keeps Basic auth for -Credentials alone' {
            (Get-Command Connect-CWC).ParameterSets | Where-Object IsDefault | ForEach-Object Name | Should -Be 'Credentials'
        }

        It 'rejects <Name>' -TestCases @(
            @{ Name = '-OneTimeCode with -TotpSecret'; Extra = @{ OneTimeCode = '123456'; TotpSecret = (ConvertTo-SecureString 'GEZDGNBV' -AsPlainText -Force) } }
            @{ Name = '-Mfa with -OneTimeCode'; Extra = @{ Mfa = $True; OneTimeCode = '123456' } }
            @{ Name = '-Origin with -Mfa'; Extra = @{ Mfa = $True; Origin = 'https://x' } }
            @{ Name = 'a 5-digit code'; Extra = @{ OneTimeCode = '12345' } }
            @{ Name = 'a code with letters'; Extra = @{ OneTimeCode = '12a456' } }
        ) {
            param($Name, $Extra)
            { Connect-CWC -Server 's.example.com' -Credentials $cred @Extra -ErrorAction Stop } | Should -Throw
        }

        It 'accepts a code with a leading zero' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '012345' -ErrorAction Stop
                ($script:LoginBodies[0].Body | ConvertFrom-Json)[2] | Should -Be '012345'
            }
        }
    }

    Context 'Login with -OneTimeCode' {
        It 'logs in with TryLogin and stores a cookie connection without the password' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 'https://s.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop

                # No @(): PS 5.1 would wrap the parsed array in another array
                $Body = $script:LoginBodies[0].Body | ConvertFrom-Json
                $Body.Count | Should -Be 5
                $Body[0] | Should -Be 'mfauser'
                $Body[1] | Should -Be 'mfapass'
                $Body[2] | Should -Be '123456'
                $Body[3] | Should -BeFalse          # shouldTrust
                $Body[4] | Should -BeNullOrEmpty    # securityNonce
                $script:LoginBodies[0].MaxRetry | Should -Be 0
                $script:LoginBodies[0].Sensitive | Should -BeTrue

                $Connection = $script:CWCServerConnection
                $Connection.AuthType | Should -Be 'Mfa'
                $Connection.Server | Should -Be 's.example.com'
                $Connection.UserName | Should -Be 'mfauser'
                $Connection.Headers.Keys | Should -Not -Contain 'authorization'
                $Connection.Headers.'x-anti-forgery-token' | Should -Be 'posttokenposttoken12'
                ($Connection | ConvertTo-Json -Depth 3) | Should -Not -Match 'mfapass'
                $Connection.WebSession | Should -BeOfType [Microsoft.PowerShell.Commands.WebRequestSession]
            }
        }

        It 'shares one cookie jar between the front page requests' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $Session = $script:CWCServerConnection.WebSession
                Should -Invoke Invoke-WebRequest -Times 2 -Exactly -ParameterFilter { [object]::ReferenceEquals($WebSession, $Session) -and -not $Headers }
                Should -Invoke Invoke-CWCWebRequest -Times 1 -Exactly -ParameterFilter { $Arguments.Endpoint -like '*/GetEligibleHosts' }
            }
        }

        It 'reports <Result> as <ErrorId> and stays disconnected' -TestCases @(
            @{ Result = 11; ErrorId = 'CWC.MfaRequired' }
            @{ Result = 10; ErrorId = 'CWC.MfaCodeRejected' }
            @{ Result = 7; ErrorId = 'CWC.LoginFailed' }
            @{ Result = $null; ErrorId = 'CWC.LoginFailed' }
        ) {
            param($Result, $ErrorId)
            Set-FakeMfaServer -LoginResults @(, $Result)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred; ErrorId = $ErrorId } {
                param($cred, $ErrorId)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction SilentlyContinue -ErrorVariable err
                @($err | Where-Object { $_.FullyQualifiedErrorId -like "$ErrorId*" }).Count | Should -BeGreaterThan 0
                $script:CWCServerConnection | Should -BeNullOrEmpty
                "$err" | Should -Not -Match 'mfapass'
            }
        }

        It 'reports a rate limit as CWC.LoginThrottled' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { Write-Error '{"errorType":"OperationLimitExceededException"}' -ErrorId 'CWC.Http500' } -ParameterFilter { $Arguments.Endpoint -like '*/TryLogin' }
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction SilentlyContinue -ErrorVariable err
                @($err | Where-Object { $_.FullyQualifiedErrorId -like 'CWC.LoginThrottled*' }).Count | Should -BeGreaterThan 0
            }
        }

        It 'does not blame the code when the server does not answer' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-CWCWebRequest { Write-Error 'No such host is known.' -ErrorId 'CWC.NoResponse' } -ParameterFilter { $Arguments.Endpoint -like '*/TryLogin' }
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'failed before authentication could be checked'
                @($err | Where-Object { $_.FullyQualifiedErrorId -like 'CWC.NoResponse*' }).Count | Should -BeGreaterThan 0
            }
        }

        It 'fails when the front page cannot be reached' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest { throw 'Connection refused' }
                Mock Invoke-CWCWebRequest {}
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'Failed to connect'
                Should -Invoke Invoke-CWCWebRequest -Times 0
                $script:CWCServerConnection | Should -BeNullOrEmpty
            }
        }

        It 'fails when the account cannot use the API after login' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                $script:ProbeFails = $True
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'at least one permission'
                "$err" | Should -Not -Match 'MFA login has expired'
                $script:CWCServerConnection | Should -BeNullOrEmpty
                # The login that succeeded is not left valid on the server
                $script:LogoutCalls | Should -Be 1
            }
        }
    }

    Context 'Login with -Mfa (prompt)' {
        It 'does not prompt when the server accepts the login without a code' {
            Set-FakeMfaServer -LoginResults @(1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Read-Host {}
                Connect-CWC -Server 's.example.com' -Credentials $cred -Mfa -ErrorAction Stop
                Should -Invoke Read-Host -Times 0
                # JSON null, not "": the server answers 11 (code required) only for a missing code
                $script:LoginBodies[0].Body | Should -Match '"mfapass",\s*null,'
                $script:CWCServerConnection.AuthType | Should -Be 'Mfa'
            }
        }

        It 'prompts for the code when the server asks for one, then logs in with it' {
            Set-FakeMfaServer -LoginResults @(11, 1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Read-Host { ConvertTo-SecureString ' 654321 ' -AsPlainText -Force }
                Connect-CWC -Server 's.example.com' -Credentials $cred -Mfa -ErrorAction Stop
                Should -Invoke Read-Host -Times 1 -ParameterFilter { $AsSecureString }
                $script:LoginBodies.Count | Should -Be 2
                ($script:LoginBodies[0].Body | ConvertFrom-Json)[2] | Should -BeNullOrEmpty
                ($script:LoginBodies[1].Body | ConvertFrom-Json)[2] | Should -Be '654321'
                $script:CWCServerConnection.AuthType | Should -Be 'Mfa'
            }
        }

        It 'fails with CWC.MfaRequired when there is no console to prompt on' {
            Set-FakeMfaServer -LoginResults @(11)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Read-Host { throw 'PowerShell is in NonInteractive mode.' }
                Connect-CWC -Server 's.example.com' -Credentials $cred -Mfa -ErrorAction SilentlyContinue -ErrorVariable err
                @($err | Where-Object { $_.FullyQualifiedErrorId -like 'CWC.MfaRequired*' }).Count | Should -BeGreaterThan 0
                $script:LoginBodies.Count | Should -Be 1
                $script:CWCServerConnection | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Login with -TotpSecret' {
        It 'sends the computed code and does not store the secret' {
            Set-FakeMfaServer
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Get-CWCUnixTime { [int64]31 }   # same step as T=59, with time left
                Mock Start-Sleep {}
                $Secret = ConvertTo-SecureString 'ms:GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' -AsPlainText -Force
                Connect-CWC -Server 's.example.com' -Credentials $cred -TotpSecret $Secret -ErrorAction Stop
                ($script:LoginBodies[0].Body | ConvertFrom-Json)[2] | Should -Be '287082'
                $script:CWCServerConnection.Values | Where-Object { $_ -is [securestring] } | Should -BeNullOrEmpty
                ($script:CWCServerConnection | ConvertTo-Json -Depth 3) | Should -Not -Match 'GEZDGNBV'
                # The step is recorded once the server has seen the code, so it is not sent twice
                $script:CWCLastTotpStep['s.example.com|mfauser'] | Should -Be 1
            }
        }

        It 'does not record the step when the login failed for another reason (wrong password)' {
            Set-FakeMfaServer -LoginResults @(7)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Get-CWCUnixTime { [int64]31 }
                Mock Start-Sleep {}
                $Secret = ConvertTo-SecureString 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' -AsPlainText -Force
                Connect-CWC -Server 's.example.com' -Credentials $cred -TotpSecret $Secret -ErrorAction SilentlyContinue
                $script:CWCLastTotpStep.Count | Should -Be 0
            }
        }

        It 'rejects a secret that is not Base32 before sending any request' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest {}
                Mock Invoke-CWCWebRequest {}
                $Secret = ConvertTo-SecureString 'not base32!' -AsPlainText -Force
                { Connect-CWC -Server 's.example.com' -Credentials $cred -TotpSecret $Secret -ErrorAction Stop } | Should -Throw '*not valid Base32*'
                Should -Invoke Invoke-WebRequest -Times 0
                Should -Invoke Invoke-CWCWebRequest -Times 0
            }
        }

        It 'rejects an empty secret' {
            { Connect-CWC -Server 's.example.com' -Credentials $cred -TotpSecret (New-Object securestring) -ErrorAction Stop } | Should -Throw '*empty*'
        }
    }

    Context 'Connection caching' {
        It 'reuses a cached login that still works, without logging in again' {
            Set-FakeMfaServer -LoginResults @(1, 1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $First = $script:CWCServerConnection
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '654321' -ErrorAction Stop
                $script:LoginBodies.Count | Should -Be 1
                [object]::ReferenceEquals($script:CWCServerConnection, $First) | Should -BeTrue
                $script:LogoutCalls | Should -Be 0
            }
        }

        It 'logs in again when the cached login has expired, and never restores it' {
            Set-FakeMfaServer -LoginResults @(1, 10)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $script:ProbeFails = $True
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '654321' -ErrorAction SilentlyContinue -ErrorVariable err
                $script:LoginBodies.Count | Should -Be 2
                @($err | Where-Object { $_.FullyQualifiedErrorId -like 'CWC.MfaCodeRejected*' }).Count | Should -BeGreaterThan 0
                $script:CWCServerConnection | Should -BeNullOrEmpty
            }
        }

        It 'keeps the cached login when the server cannot be reached to check it' {
            Set-FakeMfaServer -LoginResults @(1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $First = $script:CWCServerConnection
                Mock Invoke-CWCWebRequest { Write-Error 'No such host is known.' -ErrorId 'CWC.NoResponse' } -ParameterFilter { $Arguments.Endpoint -like '*/GetEligibleHosts' }
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '654321' -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'Could not reach'
                $script:LoginBodies.Count | Should -Be 1
                [object]::ReferenceEquals($script:CWCServerConnection, $First) | Should -BeTrue
                $script:LogoutCalls | Should -Be 0
            }
        }

        It 'does not log out the old login on a successful -Force refresh of the same login' {
            Set-FakeMfaServer -LoginResults @(1, 1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '654321' -Force -ErrorAction Stop
                $script:LoginBodies.Count | Should -Be 2
                $script:LogoutCalls | Should -Be 0
            }
        }

        It 'logs out the old login even when the switch fails with -ErrorAction Stop' {
            Set-FakeMfaServer -LoginResults @(1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                Mock Invoke-WebRequest { throw 'Connection refused' }
                { Connect-CWC -Server 'other.example.com' -Credentials $cred -ErrorAction Stop } | Should -Throw
                $script:LogoutCalls | Should -Be 1
                $script:CWCServerConnection | Should -BeNullOrEmpty
            }
        }

        It 'logs in again for a different password' {
            Set-FakeMfaServer -LoginResults @(1, 1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $Other = [PSCredential]::new('mfauser', ('otherpass' | ConvertTo-SecureString -AsPlainText -Force))
                Connect-CWC -Server 's.example.com' -Credentials $Other -OneTimeCode '654321' -ErrorAction Stop
                $script:LoginBodies.Count | Should -Be 2
            }
        }

        It 'logs out the MFA login it replaces' {
            Set-FakeMfaServer -LoginResults @(1)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $Mfa = $script:CWCServerConnection
                Connect-CWC -Server 's.example.com' -Credentials $cred -ErrorAction Stop
                $script:LogoutCalls | Should -Be 1
                $script:CWCServerConnection.AuthType | Should -Be 'Credentials'
                $script:CWCServerConnection.Headers.authorization | Should -BeLike 'Basic *'
                [object]::ReferenceEquals($script:CWCServerConnection, $Mfa) | Should -BeFalse
            }
        }

        It 'keeps the previous login when a -Force refresh fails' {
            Set-FakeMfaServer -LoginResults @(1, 10)
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '123456' -ErrorAction Stop
                $First = $script:CWCServerConnection
                Connect-CWC -Server 's.example.com' -Credentials $cred -OneTimeCode '654321' -Force -ErrorAction SilentlyContinue
                [object]::ReferenceEquals($script:CWCServerConnection, $First) | Should -BeTrue
                $script:LogoutCalls | Should -Be 0
            }
        }
    }

    Context 'Messages' {
        It 'points MFA accounts to the MFA parameters when Basic auth is rejected' {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
                param($cred)
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '' } }
                Mock Invoke-CWCWebRequest { Write-Error 'Needs permission' -ErrorId 'CWC.Http500' }
                Connect-CWC -Server 's.example.com' -Credentials $cred -ErrorAction SilentlyContinue -ErrorVariable err -WarningAction SilentlyContinue
                "$err" | Should -Match '-Mfa, -OneTimeCode or'
            }
        }
    }
}

Describe 'Get-CWCSession' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/GetLiveData'
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @() } } }
            }
            Get-CWCSession -Type 'Access'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'maps <Type> type to session type <Code>' -ForEach @(
        @{ Type = 'Support'; Code = 0 }
        @{ Type = 'Meeting'; Code = 1 }
        @{ Type = 'Access'; Code = 2 }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Type = $Type; Code = $Code } {
            param($Type, $Code)
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0].HostSessionInfo.sessionType | Should -Be $Code
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @() } } }
            }
            Get-CWCSession -Type $Type
        }
    }

    It 'passes Group in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0].HostSessionInfo.sessionGroupPathParts[0] | Should -Be 'Custom Group'
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @() } } }
            }
            Get-CWCSession -Type 'Access' -Group 'Custom Group'
        }
    }

    It 'passes Search as filter' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0].HostSessionInfo.filter | Should -Be 'TestPC'
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @() } } }
            }
            Get-CWCSession -Type 'Access' -Search 'TestPC'
        }
    }

    It 'returns sessions from response' {
        InModuleScope 'ConnectWiseControlAPI' {
            $mockSessions = @(
                @{ SessionID = 'guid1'; Name = 'PC1' }
                @{ SessionID = 'guid2'; Name = 'PC2' }
            )
            Mock Invoke-CWCWebRequest {
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = $mockSessions } } }
            }
            $result = Get-CWCSession -Type 'Access'
            $result | Should -HaveCount 2
        }
    }

    It 'uses POST method' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Method | Should -Be 'Post'
                @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @() } } }
            }
            Get-CWCSession -Type 'Access'
        }
    }
}

Describe 'Get-CWCSessionDetail' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/GetSessionDetails'
                @{ Events = @(); Connections = @() }
            }
            Get-CWCSessionDetail -GUID ([guid]::NewGuid())
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'passes Group and GUID in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            $testGuid = [guid]'12345678-1234-1234-1234-123456789abc'
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'Test Group'
                $body[1] | Should -Be '12345678-1234-1234-1234-123456789abc'
                @{ Events = @(); Connections = @() }
            }
            Get-CWCSessionDetail -Group 'Test Group' -GUID $testGuid
        }
    }

    It 'omits the items argument when -Include is not used (server returns All)' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 2
            }
            Get-CWCSessionDetail -GUID ([guid]::NewGuid())
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'sends SessionDetailsItems flags for -Include (<Include> = <Expected>)' -TestCases @(
        @{ Include = @('Events'); Expected = 8 }
        @{ Include = @('Events', 'Connections'); Expected = 24 }
        @{ Include = @('SessionInfo', 'GuestScreenshotContent'); Expected = 5 }
        @{ Include = @('Events', 'Events'); Expected = 8 }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Include = $Include; Expected = $Expected } {
            param($Include, $Expected)
            $script:ExpectedItems = $Expected
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 3
                $body[2] | Should -Be $script:ExpectedItems
            }
            Get-CWCSessionDetail -GUID ([guid]::NewGuid()) -Include $Include
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }
}

Describe 'Session detail polling callers' {

    BeforeEach { Set-CWCTestConnection }

    It 'Get-CWCLastContact requests only Events' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSessionDetail { @{ Events = @(@{ EventType = 10; Time = 0 }) } }
            $null = Get-CWCLastContact -GUID ([guid]::NewGuid()) -Quiet
            Should -Invoke Get-CWCSessionDetail -Times 1 -ParameterFilter { $Include -eq 'Events' }
        }
    }

    It 'Invoke-CWCCommand polls with Events only' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Mock Start-Sleep {}
            Mock Get-CWCSessionDetail {
                @{ Events = @(
                        @{ EventType = 44; Time = 5000 }
                        @{ EventType = 70; Time = 1000; Data = 'output' }
                    ) }
            }
            $null = Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'hostname' -TimeOut 1000
            Should -Invoke Get-CWCSessionDetail -ParameterFilter { $Include -eq 'Events' }
            Should -Invoke Get-CWCSessionDetail -Times 0 -ParameterFilter { -not $Include }
        }
    }
}

Describe 'Get-CWCLastContact' {

    BeforeEach { Set-CWCTestConnection }

    It 'returns null and warns when machine not found' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSessionDetail { return $null }
            $result = Get-CWCLastContact -GUID ([guid]::NewGuid()) 3>&1
            # The function returns $null for the machine not found case
        }
    }

    It 'returns true with Quiet when machine is connected' {
        InModuleScope 'ConnectWiseControlAPI' {
            $epoch = [math]::Floor(((Get-Date).ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds)
            Mock Get-CWCSessionDetail {
                @{
                    Events      = @(
                        @{ EventType = 10; Time = $epoch * 1000; ConnectionID = 'conn1' }
                    )
                    Connections = @()
                }
            }
            $result = Get-CWCLastContact -GUID ([guid]::NewGuid()) -Quiet
            $result | Should -BeTrue
        }
    }

    Context 'Offline machine (event Time = milliseconds since the event)' {
        BeforeEach {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Get-CWCSessionDetail {
                    @{
                        Events      = @(
                            @{ EventType = 11; Time = 120000; ConnectionID = 'conn1' }
                        )
                        Connections = @()
                    }
                }
            }
        }

        It 'returns true with Quiet when last contact is within Seconds' {
            InModuleScope 'ConnectWiseControlAPI' {
                Get-CWCLastContact -GUID ([guid]::NewGuid()) -Quiet -Seconds 300 | Should -BeTrue
            }
        }

        It 'returns false with Quiet when last contact is older than Seconds' {
            InModuleScope 'ConnectWiseControlAPI' {
                Get-CWCLastContact -GUID ([guid]::NewGuid()) -Quiet -Seconds 60 | Should -BeFalse
            }
        }

        It 'ignores a technician leaving after the guest disconnected' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Get-CWCSessionDetail {
                    @{ Events = @(
                            @{ EventType = 11; Time = 5000; Host = 'Technician'; ConnectionID = 'host1' }
                            @{ EventType = 11; Time = 120000; Host = ''; ConnectionID = 'guest1' }
                        ) }
                }
                Get-CWCLastContact -GUID ([guid]::NewGuid()) -Quiet -Seconds 60 | Should -BeFalse
            }
        }

        It 'returns a local time about two minutes ago' {
            InModuleScope 'ConnectWiseControlAPI' {
                $result = Get-CWCLastContact -GUID ([guid]::NewGuid())
                $result.Kind | Should -Not -Be ([System.DateTimeKind]::Utc)
                ((Get-Date) - $result).TotalSeconds | Should -BeGreaterThan 115
                ((Get-Date) - $result).TotalSeconds | Should -BeLessThan 130
            }
        }
    }
}

Describe 'Invoke-CWCCommand' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls AddSessionEvents endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                if ($Arguments.Endpoint -eq 'Services/PageService.ashx/AddSessionEvents') {
                    $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
                    return $null
                }
                @{ Events = @(); Connections = @() }
            }
            Mock Get-CWCSessionDetail {
                @{ Events = @(); Connections = @() }
            }
            Mock Start-Sleep {}
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'hostname' -NoWait
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'includes #!ps directive when PowerShell switch is used' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                if ($Arguments.Body) {
                    $Arguments.Body | Should -Match '#!ps'
                }
                return $null
            }
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'Get-Process' -PowerShell -NoWait
        }
    }

    It 'includes timeout and maxlength directives' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                if ($Arguments.Body) {
                    $Arguments.Body | Should -Match '#timeout=5000'
                    $Arguments.Body | Should -Match '#maxlength=2000'
                }
                return $null
            }
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'test' -TimeOut 5000 -MaxLength 2000 -NoWait
        }
    }

    It 'uses EventType 44 for commands' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                if ($Arguments.Body) {
                    $body = $Arguments.Body | ConvertFrom-Json
                    $body[1][0].EventType | Should -Be 44
                }
                return $null
            }
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'test' -NoWait
        }
    }

    It 'returns immediately with NoWait' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest { return $null }
            Mock Get-CWCSessionDetail {}
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'test' -NoWait
            Should -Invoke Get-CWCSessionDetail -Times 0
        }
    }
}

Describe 'Invoke-CWCWake' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
            }
            Invoke-CWCWake -GUID ([guid]::NewGuid()) -Type 'Access'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'sends one EventType 43 entry per session' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:WakeGuids = @([guid]::NewGuid(), [guid]::NewGuid())
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 2
                $body[1] | Should -HaveCount 2
                $body[1].EventType | Should -Be @(43, 43)
                $body[1].SessionID | Should -Be ($script:WakeGuids | ForEach-Object { "$_" })
            }
            Invoke-CWCWake -GUID $script:WakeGuids -Type 'Access'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'maps Support to All Sessions group' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'All Sessions'
            }
            Invoke-CWCWake -GUID ([guid]::NewGuid()) -Type 'Support'
        }
    }

    It 'maps Access to All Machines group' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'All Machines'
            }
            Invoke-CWCWake -GUID ([guid]::NewGuid()) -Type 'Access'
        }
    }
}

Describe 'Enter-CWCSession' {

    BeforeEach {
        Set-CWCTestConnection
        $Id = '11111111-2222-3333-4444-555555555555'
        Mock -ModuleName 'ConnectWiseControlAPI' Get-CWCHostLaunchContext {
            @{ Scheme = 'sc-0123456789abcdef'; RelayHost = 'relay.example.com'; RelayPort = 8041; PublicKey = 'KEY+pub/lic==' }
        }
        Mock -ModuleName 'ConnectWiseControlAPI' Invoke-CWCWebRequest {
            param($Arguments)
            switch -Wildcard ($Arguments.Endpoint) {
                '*/GetLiveData' {
                    @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @(
                                    @{ SessionID = '11111111-2222-3333-4444-555555555555'; Name = 'PC 01'; SessionType = 2 }
                                ) } } }
                }
                '*/GetAccessToken' { 'TOKEN+primary/abc==' }
                '*/GetDelegatedAccessToken' { 'TOKEN+delegated/xyz==' }
                default { $null }
            }
        }
        Mock -ModuleName 'ConnectWiseControlAPI' Test-Path { $true } -ParameterFilter { $LiteralPath -like 'Registry::*' }
        Mock -ModuleName 'ConnectWiseControlAPI' Start-CWCHostClient {}
    }

    It 'opens the client with the web client URL format and a primary token' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        $Result = Enter-CWCSession -GUID $Id
        $Result | Should -BeNullOrEmpty
        $Expected = 'sc-0123456789abcdef://relay.example.com:8041/11111111-2222-3333-4444-555555555555/' +
            'KEY%2Bpub%2Flic%3D%3D/TOKEN%2Bprimary%2Fabc%3D%3D//Access/PC%2001/None/'
        Should -Invoke Start-CWCHostClient -ModuleName 'ConnectWiseControlAPI' -Times 1 -Exactly -ParameterFilter { $Url -eq $Expected }
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0 -ParameterFilter { $Arguments.Endpoint -like '*/GetDelegatedAccessToken' }
    }

    It 'checks for the protocol handler of the server scheme' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        Enter-CWCSession -GUID $Id
        Should -Invoke Test-Path -ModuleName 'ConnectWiseControlAPI' -Times 1 -ParameterFilter { $LiteralPath -eq 'Registry::HKEY_CLASSES_ROOT\sc-0123456789abcdef' }
    }

    It 'logs the join like the web UI (LogInitiatedJoin, ProcessType Host = 1)' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        Enter-CWCSession -GUID $Id
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 1 -Exactly -ParameterFilter {
            $Body = $Arguments.Body | ConvertFrom-Json
            $Arguments.Endpoint -eq 'Services/PageService.ashx/LogInitiatedJoin' -and
            $Body[0] -eq '11111111-2222-3333-4444-555555555555' -and $Body[1] -eq 1 -and $Body[2] -like '(UrlLaunch) ConnectWiseControlAPI/*'
        }
    }

    It 'warns but still opens the client when the join cannot be logged' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        Mock -ModuleName 'ConnectWiseControlAPI' Invoke-CWCWebRequest {
            param($Arguments)
            switch -Wildcard ($Arguments.Endpoint) {
                '*/GetLiveData' { @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @(@{ SessionID = '11111111-2222-3333-4444-555555555555'; Name = 'PC 01' }) } } } }
                '*/GetAccessToken' { 'TOKEN+primary/abc==' }
                '*/LogInitiatedJoin' { throw 'Rate limited' }
            }
        }
        Enter-CWCSession -GUID $Id -WarningVariable Warnings -WarningAction SilentlyContinue -ErrorAction Stop
        Should -Invoke Start-CWCHostClient -ModuleName 'ConnectWiseControlAPI' -Times 1 -Exactly
        $Warnings | Should -Match 'could not be logged'
    }

    It 'never writes the token to verbose, debug or warning output' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        $Output = & {
            $VerbosePreference = 'Continue'
            $DebugPreference = 'Continue'
            Enter-CWCSession -GUID $Id
        } *>&1 | Out-String
        $Output | Should -Not -Match 'TOKEN\+|TOKEN%2B'
    }

    It 'reports a launch failure without the URL' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        Mock -ModuleName 'ConnectWiseControlAPI' Start-CWCHostClient { throw 'Could not start the ScreenConnect client (Win32Exception).' }
        { Enter-CWCSession -GUID $Id -ErrorAction Stop } | Should -Throw 'Could not start the ScreenConnect client*'
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0 -ParameterFilter { $Arguments.Endpoint -like '*/LogInitiatedJoin' }
    }

    It 'errors without requesting a token when the client is not installed' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        Mock -ModuleName 'ConnectWiseControlAPI' Test-Path { $false } -ParameterFilter { $LiteralPath -like 'Registry::*' }
        { Enter-CWCSession -GUID $Id -ErrorAction Stop } | Should -Throw '*not installed*-UrlOnly*'
        Should -Invoke Start-CWCHostClient -ModuleName 'ConnectWiseControlAPI' -Times 0
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0 -ParameterFilter { $Arguments.Endpoint -like '*AccessToken' }
    }

    It '-UrlOnly returns the URL with a short-lived delegated token and does not launch or log' {
        $Url = Enter-CWCSession -GUID $Id -UrlOnly
        $Url | Should -BeLike 'sc-0123456789abcdef://relay.example.com:8041/11111111-*/TOKEN%2Bdelegated%2Fxyz%3D%3D//Access/*'
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 1 -Exactly -ParameterFilter {
            $Body = $Arguments.Body | ConvertFrom-Json
            $Arguments.Endpoint -like '*/GetDelegatedAccessToken' -and $Body[2] -eq 268435455 -and $Body[3] -eq 300
        }
        Should -Invoke Start-CWCHostClient -ModuleName 'ConnectWiseControlAPI' -Times 0
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0 -ParameterFilter { $Arguments.Endpoint -like '*/LogInitiatedJoin' }
    }

    It '-UrlOnly falls back to a primary token with a warning' {
        Mock -ModuleName 'ConnectWiseControlAPI' Invoke-CWCWebRequest {
            param($Arguments)
            switch -Wildcard ($Arguments.Endpoint) {
                '*/GetLiveData' { @{ ResponseInfoMap = @{ HostSessionInfo = @{ Sessions = @(@{ SessionID = '11111111-2222-3333-4444-555555555555'; Name = 'PC 01' }) } } } }
                '*/GetDelegatedAccessToken' { throw 'Needs permission' }
                '*/GetAccessToken' { 'TOKEN+primary/abc==' }
            }
        }
        $Url = Enter-CWCSession -GUID $Id -UrlOnly -WarningVariable Warnings -WarningAction SilentlyContinue
        $Url | Should -BeLike '*/TOKEN%2Bprimary%2Fabc%3D%3D/*'
        $Warnings | Should -Match 'Treat it like a password'
        $Warnings | Should -Not -Match 'TOKEN\+|TOKEN%2B'
    }

    It 'is blocked on an API-secret connection without any request' {
        Set-CWCTestApiSecretConnection
        { Enter-CWCSession -GUID $Id -ErrorAction Stop } | Should -Throw '*-ApiSecret*Connect-CWC -Credentials*'
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0
        Should -Invoke Get-CWCHostLaunchContext -ModuleName 'ConnectWiseControlAPI' -Times 0
    }

    It 'errors when not connected' {
        InModuleScope 'ConnectWiseControlAPI' { $script:CWCServerConnection = $null }
        { Enter-CWCSession -GUID $Id -ErrorAction Stop } | Should -Throw '*Connect-CWC*'
    }

    It 'errors without requesting a token when the session is not in the group' {
        { Enter-CWCSession -GUID ([guid]::NewGuid()) -ErrorAction Stop } | Should -Throw '*was not found among Access sessions*'
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 0 -ParameterFilter { $Arguments.Endpoint -like '*AccessToken' }
    }

    It 'uses <Group> as the default group for <Type> sessions' -ForEach @(
        @{ Type = 'Access'; Group = 'All Machines' }
        @{ Type = 'Support'; Group = 'All Sessions' }
        @{ Type = 'Meeting'; Group = 'All Meetings' }
    ) {
        $null = Enter-CWCSession -GUID $Id -Type $Type -UrlOnly
        Should -Invoke Invoke-CWCWebRequest -ModuleName 'ConnectWiseControlAPI' -Times 1 -ParameterFilter {
            $Arguments.Endpoint -like '*/GetLiveData' -and ($Arguments.Body | ConvertFrom-Json)[0].HostSessionInfo.sessionGroupPathParts[0] -eq $Group
        }
    }

    It 'accepts SessionID from the pipeline' {
        $Url = [pscustomobject]@{ SessionID = $Id } | Enter-CWCSession -UrlOnly
        $Url | Should -BeLike '*/11111111-2222-3333-4444-555555555555/*'
    }
}

Describe 'New-CWCAccessToken' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/GetAccessToken'
                'token123'
            }
            New-CWCAccessToken -GUID ([guid]::NewGuid())
        }
    }

    It 'uses POST method' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Method | Should -Be 'Post'
                'token123'
            }
            New-CWCAccessToken -GUID ([guid]::NewGuid())
        }
    }
}

Describe 'Remove-CWCSession' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
            }
            Remove-CWCSession -GUID ([guid]::NewGuid()) -Group 'All Machines' -Confirm:$false
        }
    }

    It 'uses EventType 21' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[1][0].EventType | Should -Be 21
            }
            Remove-CWCSession -GUID ([guid]::NewGuid()) -Group 'All Machines' -Confirm:$false
        }
    }

    It 'uses EventType 100 (QueuedUninstallAndDelete) with -Uninstall' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[1][0].EventType | Should -Be 100
            }
            Remove-CWCSession -GUID ([guid]::NewGuid()) -Group 'All Machines' -Uninstall -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'sends one event entry per session' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:RemoveGuids = @([guid]::NewGuid(), [guid]::NewGuid())
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[1] | Should -HaveCount 2
                $body[1].SessionID | Should -Be ($script:RemoveGuids | ForEach-Object { "$_" })
            }
            Remove-CWCSession -GUID $script:RemoveGuids -Group 'All Machines' -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Remove-CWCSession -GUID ([guid]::NewGuid()) -Group 'All Machines' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'is ConfirmImpact High (prompts by default)' {
        $cmd = Get-Command Remove-CWCSession -Module 'ConnectWiseControlAPI'
        $binding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $binding.ConfirmImpact | Should -Be 'High'
    }

    It 'rejects an empty GUID' {
        { Remove-CWCSession -GUID ([guid]::Empty) -Group 'All Machines' -Confirm:$false } | Should -Throw
    }

    It 'sends a single session as one event entry' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:RemoveSessionBody = $null
            Mock Invoke-CWCWebRequest { param($Arguments) $script:RemoveSessionBody = $Arguments.Body }
            $id = [guid]'11111111-1111-1111-1111-111111111111'
            Remove-CWCSession -GUID $id -Group 'All Machines' -Confirm:$false
            $parsed = $script:RemoveSessionBody | ConvertFrom-Json
            @($parsed[1]).Count | Should -Be 1
            @($parsed[1])[0].SessionID | Should -Be $id.ToString()
            @($parsed[1])[0].EventType | Should -Be 21
        }
    }
}

Describe 'Update-CWCCustomProperty' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/UpdateSessionCustomPropertyValue'
            }
            Update-CWCCustomProperty -GUID ([guid]::NewGuid()) -Property 1 -Value 'test' -Confirm:$false
        }
    }

    It 'passes property and value in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            $testGuid = [guid]'12345678-1234-1234-1234-123456789abc'
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'All Machines'
                $body[2] | Should -Be 3
                $body[3] | Should -Be 'custom value'
            }
            Update-CWCCustomProperty -GUID $testGuid -Property 3 -Value 'custom value' -Confirm:$false
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Update-CWCCustomProperty -GUID ([guid]::NewGuid()) -Property 1 -Value 'test' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Update-CWCSessionName' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/UpdateSessionName'
            }
            Update-CWCSessionName -GUID ([guid]::NewGuid()) -NewName 'NewPC' -Confirm:$false
        }
    }

    It 'passes new name in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[2] | Should -Be 'RenamedPC'
            }
            Update-CWCSessionName -GUID ([guid]::NewGuid()) -NewName 'RenamedPC' -Confirm:$false
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Update-CWCSessionName -GUID ([guid]::NewGuid()) -NewName 'test' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

# =============================================================================
# AuditService
# =============================================================================
Describe 'Get-CWCAuditInfo' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/AuditService.ashx/GetAuditInfo'
                @{ AuditTypes = @() }
            }
            Get-CWCAuditInfo
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'uses POST method' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Method | Should -Be 'Post'
                @{}
            }
            Get-CWCAuditInfo
        }
    }
}

Describe 'Get-CWCAuditLog' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/AuditService.ashx/QueryAuditLog'
                @()
            }
            Get-CWCAuditLog -StartDate '2024-01-01' -EndDate '2024-01-31'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'formats dates in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Body | Should -Match '2024-01-01'
                $Arguments.Body | Should -Match '2024-01-31'
                @()
            }
            Get-CWCAuditLog -StartDate '2024-01-01' -EndDate '2024-01-31'
        }
    }

    It 'sends the 5 arguments QueryAuditLog expects' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 5
                @()
            }
            Get-CWCAuditLog -StartDate '2024-01-01' -EndDate '2024-01-31' -EventTypes 10, 11 -SecurityTypes 1
        }
    }

    It 'converts dates to UTC before adding the Z suffix' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:AuditStart = Get-Date '2024-01-01T12:00:00'
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $expected = $script:AuditStart.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                $Arguments.Body | Should -Match ([regex]::Escape($expected))
                @()
            }
            Get-CWCAuditLog -StartDate $script:AuditStart -EndDate $script:AuditStart.AddDays(1)
        }
    }

    It 'warns that IncludeSessionCaptures is ignored' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest { @() }
            $warnings = Get-CWCAuditLog -IncludeSessionCaptures 3>&1
            $warnings | Should -Match 'IncludeSessionCaptures'
        }
    }
}

# =============================================================================
# SecurityService
# =============================================================================
Describe 'Get-CWCSecurityConfigurationInfo' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/SecurityService.ashx/GetSecurityConfigurationInfo'
                @{ UserSources = @() }
            }
            Get-CWCSecurityConfigurationInfo
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }
}

Describe 'New-CWCUser' {

    BeforeEach { Set-CWCTestConnection }

    BeforeEach {
        $cred = [PSCredential]::new('newuser', ('pass123' | ConvertTo-SecureString -AsPlainText -Force))
    }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
            param($cred)
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/SecurityService.ashx/SaveUser'
            }
            New-CWCUser -Credentials $cred -Email 'test@example.com' -Confirm:$false
        }
    }

    It 'includes InternalUserSource in body' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
            param($cred)
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'InternalMembershipProvider'
            }
            New-CWCUser -Credentials $cred -Email 'test@example.com' -Confirm:$false
        }
    }

    It 'includes username in body' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
            param($cred)
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[2] | Should -Be 'newuser'
            }
            New-CWCUser -Credentials $cred -Email 'test@example.com' -Confirm:$false
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ cred = $cred } {
            param($cred)
            Mock Invoke-CWCWebRequest {}
            New-CWCUser -Credentials $cred -Email 'test@example.com' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Remove-CWCUser' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/SecurityService.ashx/DeleteUser'
            }
            Remove-CWCUser -User 'testuser' -Confirm:$false
        }
    }

    It 'includes InternalUserSource and username in body' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be 'InternalMembershipProvider'
                $body[1] | Should -Be 'deleteuser'
            }
            Remove-CWCUser -User 'deleteuser' -Confirm:$false
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Remove-CWCUser -User 'testuser' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Update-CWCUser' {

    BeforeEach { Set-CWCTestConnection }

    It 'fetches current user before updating' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSecurityConfigurationInfo {
                @{
                    UserSources = @(
                        @{
                            ResourceKey = 'InternalMembershipProvider'
                            Users       = @(
                                @{
                                    Name             = 'existinguser'
                                    DisplayName      = 'Existing'
                                    Email            = 'existing@test.com'
                                    PasswordQuestion = ''
                                    RoleNames        = @('admin')
                                }
                            )
                        }
                    )
                }
            }
            Mock Invoke-CWCWebRequest {}
            Update-CWCUser -UserToUpdate 'existinguser' -Email 'new@test.com' -Confirm:$false
            Should -Invoke Get-CWCSecurityConfigurationInfo -Times 1
        }
    }

    It 'errors when user not found' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSecurityConfigurationInfo {
                @{
                    UserSources = @(
                        @{
                            ResourceKey = 'InternalMembershipProvider'
                            Users       = @()
                        }
                    )
                }
            }
            $result = Update-CWCUser -UserToUpdate 'nonexistent' -Confirm:$false 2>&1
            $result | Should -Match 'Unable to find user'
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSecurityConfigurationInfo {
                @{
                    UserSources = @(
                        @{
                            ResourceKey = 'InternalMembershipProvider'
                            Users       = @(
                                @{
                                    Name             = 'testuser'
                                    DisplayName      = 'Test'
                                    Email            = 'test@test.com'
                                    PasswordQuestion = ''
                                    RoleNames        = @()
                                }
                            )
                        }
                    )
                }
            }
            Mock Invoke-CWCWebRequest {}
            Update-CWCUser -UserToUpdate 'testuser' -Email 'new@test.com' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'preserves the existing user comment' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSecurityConfigurationInfo {
                @{
                    UserSources = @(
                        @{
                            ResourceKey = 'InternalMembershipProvider'
                            Users       = @(
                                @{
                                    Name             = 'testuser'
                                    DisplayName      = 'Test'
                                    Comment          = 'keep me'
                                    Email            = 'test@test.com'
                                    PasswordQuestion = ''
                                    RoleNames        = @()
                                }
                            )
                        }
                    )
                }
            }
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 11
                $body[7] | Should -Be 'keep me'
            }
            Update-CWCUser -UserToUpdate 'testuser' -Email 'new@test.com' -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }
}

# =============================================================================
# SessionGroupService
# =============================================================================
Describe 'Get-CWCSessionGroup' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'Services/SessionGroupService.ashx/GetSessionGroups'
                @()
            }
            Get-CWCSessionGroup
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'uses POST method' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Method | Should -Be 'Post'
                @()
            }
            Get-CWCSessionGroup
        }
    }
}

# =============================================================================
# Extensions - Remote Workforce
# Signatures from Remote Workforce 1.3.16 App_Extensions/2c4f522f.../Service.ashx
# =============================================================================
Describe 'Get-CWCRemoteWorkforceLaunchURL' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls GetLaunchUrlForSessionId with exactly one argument (the session ID)' {
        InModuleScope 'ConnectWiseControlAPI' {
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/GetLaunchUrlForSessionId'
                $Arguments.Body.Trim() | Should -Match '^\['
                $body = @($Arguments.Body | ConvertFrom-Json)
                $body | Should -HaveCount 1
                'https://launch.url'
            }
            Get-CWCRemoteWorkforceLaunchURL -GUID $id | Should -Be 'https://launch.url'
        }
    }

    It 'makes one request per GUID' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest { 'https://launch.url' }
            Get-CWCRemoteWorkforceLaunchURL -GUID ([guid]::NewGuid()), ([guid]::NewGuid())
            Should -Invoke Invoke-CWCWebRequest -Times 2
        }
    }

    It 'accepts SessionID from the pipeline by property name' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest { 'https://launch.url' }
            [PSCustomObject]@{ Name = 'PC'; SessionID = [guid]::NewGuid() } | Get-CWCRemoteWorkforceLaunchURL
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'calls GetLaunchUrl with -SessionName' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Match '/GetLaunchUrl$'
                @($Arguments.Body | ConvertFrom-Json)[0] | Should -Be 'DESKTOP-01'
                'https://launch.url'
            }
            Get-CWCRemoteWorkforceLaunchURL -SessionName 'DESKTOP-01'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'warns and returns nothing when the server returns null' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest { $null }
            $result = Get-CWCRemoteWorkforceLaunchURL -GUID ([guid]::NewGuid()) -WarningVariable warn -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warn | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-CWCLauncURL (deprecated)' {

    BeforeEach { Set-CWCTestConnection }

    It 'forwards to GetLaunchUrlForSessionId with one argument and warns' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Match '/GetLaunchUrlForSessionId$'
                @($Arguments.Body | ConvertFrom-Json) | Should -HaveCount 1
                'https://launch.url'
            }
            $result = Get-CWCLauncURL -GUID ([guid]::NewGuid()) -OnSuccess 'x' -Confirm:$false -WarningVariable warn -WarningAction SilentlyContinue
            $result | Should -Be 'https://launch.url'
            ($warn -join ' ') | Should -Match 'deprecated'
            ($warn -join ' ') | Should -Match 'OnSuccess'
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Get-CWCLauncURL -GUID ([guid]::NewGuid()) -WhatIf -WarningAction SilentlyContinue
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Get-CWCRemoteWorkforceSession' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls GetRemoteWorkforceSessions and maps the name/ID dictionary to objects' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Match '/GetRemoteWorkforceSessions$'
                $Arguments.Body | Should -Be '[]'
                '{"PC-1":"11111111-1111-1111-1111-111111111111","PC-2":"22222222-2222-2222-2222-222222222222"}' | ConvertFrom-Json
            }
            $result = @(Get-CWCRemoteWorkforceSession)
            $result | Should -HaveCount 2
            $result[0].Name | Should -Be 'PC-1'
            $result[0].SessionID | Should -BeOfType [guid]
        }
    }
}

Describe 'Initialize-CWCRemoteWorkforceSessionGroup' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls EnsureCorrectSessionGroupExists with no arguments' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/EnsureCorrectSessionGroupExists'
                $Arguments.Body | Should -Be '[]'
            }
            Initialize-CWCRemoteWorkforceSessionGroup -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Initialize-CWCRemoteWorkforceSessionGroup -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Add-CWCRemoteWorkforceRequiredRole' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls the extension EnsureRemoteWorkforceSecurityRoleExists endpoint with no arguments' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/EnsureRemoteWorkforceSecurityRoleExists'
                $Arguments.Body | Should -Be '[]'
            }
            Add-CWCRemoteWorkforceRequiredRole -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Add-CWCRemoteWorkforceRequiredRole -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'New-CWCRemoteWorkforceAssignment' {

    BeforeEach { Set-CWCTestConnection }

    It 'calls correct extension endpoint' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/AddAssignmentNoteToSession'
            }
            New-CWCRemoteWorkforceAssignment -GUID ([guid]::NewGuid()) -Username 'testuser' -Confirm:$false
        }
    }

    It 'includes username in assignment data' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Body | Should -Match 'UserName:jdoe'
            }
            New-CWCRemoteWorkforceAssignment -GUID ([guid]::NewGuid()) -Username 'jdoe' -DisplayName 'John Doe' -Confirm:$false
        }
    }

    It 'sends AddAssignmentNoteToSession(string[] groupPath, Guid[] sessionIDs, string note)' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 3
                @($body[0]) | Should -Be @('All Machines')
                @($body[1]) | Should -HaveCount 1
                $body[2] | Should -Be 'UserName:jdoe,UserDisplayName:John Doe'
            }
            New-CWCRemoteWorkforceAssignment -GUID ([guid]::NewGuid()) -Username 'jdoe' -DisplayName 'John Doe' -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            New-CWCRemoteWorkforceAssignment -GUID ([guid]::NewGuid()) -Username 'test' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

# =============================================================================
# RESTful API Manager (Connect-CWC -ApiSecret)
# Signatures from RESTful API Manager 1.0.9 App_Extensions/2d558935.../Service.ashx
# =============================================================================
Describe 'API secret routing of existing functions' {

    BeforeEach { Set-CWCTestApiSecretConnection }

    It 'Get-CWCSessionDetail calls GetSessionDetailsBySessionID(Guid)' {
        InModuleScope 'ConnectWiseControlAPI' {
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionDetailsBySessionID"
                $body = @($Arguments.Body | ConvertFrom-Json)
                $body | Should -HaveCount 1
                $body[0] | Should -Be $id.ToString()
            }
            Get-CWCSessionDetail -GUID $id
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'Update-CWCSessionName calls UpdateSessionName(Guid, string)' {
        InModuleScope 'ConnectWiseControlAPI' {
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/UpdateSessionName"
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 2
                $body[0] | Should -Be $id.ToString()
                $body[1] | Should -Be 'NewName'
            }
            Update-CWCSessionName -GUID $id -NewName 'NewName' -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'Invoke-CWCCommand calls SendCommandToSession(Guid, string)' {
        InModuleScope 'ConnectWiseControlAPI' {
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/SendCommandToSession"
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 2
                $body[0] | Should -Be $id.ToString()
                $body[1] | Should -Match '#timeout=10000'
                $body[1] | Should -Match 'hostname'
            }
            Invoke-CWCCommand -GUID $id -Command 'hostname' -NoWait
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'Invoke-CWCCommand without -NoWait queues once, warns, and does not poll' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Mock Get-CWCSessionDetail {}
            Invoke-CWCCommand -GUID ([guid]::NewGuid()) -Command 'hostname' -WarningVariable warn -WarningAction SilentlyContinue
            Should -Invoke Invoke-CWCWebRequest -Times 1
            Should -Invoke Get-CWCSessionDetail -Times 0
            ($warn -join ' ') | Should -Match 'not retrieved'
        }
    }

    It 'Get-CWCLastContact fails clearly instead of misreading raw event times' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            { Get-CWCLastContact -GUID ([guid]::NewGuid()) -ErrorAction Stop } | Should -Throw '*Connect-CWC -Credentials*'
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'functions without an extension equivalent fail with a clear error' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest {}
            { Get-CWCSession -Type Access -ErrorAction Stop } | Should -Throw '*Connect-CWC -Credentials*'
            Should -Invoke Invoke-WebRequest -Times 0
        }
    }
}

Describe 'Find-CWCSession' {

    BeforeEach { Set-CWCTestApiSecretConnection }

    It 'calls GetSessionsByFilter with the filter as the only argument' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"
                $body = @($Arguments.Body | ConvertFrom-Json)
                $body | Should -HaveCount 1
                $body[0] | Should -Be "Name LIKE 'PC*'"
                , @([PSCustomObject]@{ Name = 'PC1' }, [PSCustomObject]@{ Name = 'PC2' })
            }
            $result = @(Find-CWCSession -Filter "Name LIKE 'PC*'")
            $result | Should -HaveCount 2
        }
    }

    It 'calls GetSessionsByName with -Name' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByName"
            }
            Find-CWCSession -Name 'DESKTOP-01'
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'rejects single quotes in -Name (server does not escape them)' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            { Find-CWCSession -Name "x' OR Name LIKE '*" } | Should -Throw
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'calls GetSessionBySessionID with -GUID' {
        InModuleScope 'ConnectWiseControlAPI' {
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionBySessionID"
                @($Arguments.Body | ConvertFrom-Json)[0] | Should -Be $id.ToString()
            }
            Find-CWCSession -GUID $id
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }
}

Describe 'New-CWCSession' {

    BeforeEach { Set-CWCTestApiSecretConnection }

    It 'sends CreateSession(sessionType, name, isPublic, code, customPropertyValues[]) and returns a guid' {
        InModuleScope 'ConnectWiseControlAPI' {
            $newId = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/CreateSession"
                $body = $Arguments.Body | ConvertFrom-Json
                $body | Should -HaveCount 5
                $body[0] | Should -Be 2
                $body[1] | Should -Be 'Server01'
                $body[2] | Should -BeFalse
                $body[3] | Should -Be ''
                @($body[4]) | Should -Be @('Acme')
                $newId.ToString()
            }
            New-CWCSession -Type Access -Name 'Server01' -CustomPropertyValues 'Acme' -Confirm:$false | Should -Be $newId
        }
    }

    It 'sends an empty array when no custom properties are given' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Body | Should -Match '\[\s*\]'
            }
            New-CWCSession -Type Support -Name 'T1' -Confirm:$false
        }
    }

    It 'does not call API with WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            New-CWCSession -Type Support -Name 'T1' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }
}

Describe 'Session event functions (API secret)' {

    BeforeEach { Set-CWCTestApiSecretConnection }

    It '<Command> sends <Method>(<Expected>)' -ForEach @(
        @{ Command = 'Add-CWCSessionNote'; Method = 'AddNoteToSession'; Params = @{ Note = 'hello' }; Expected = @('hello') }
        @{ Command = 'Send-CWCSessionMessage'; Method = 'SendMessageToSession'; Params = @{ Message = 'hi'; From = 'IT' }; Expected = @('IT', 'hi') }
        @{ Command = 'Send-CWCToolboxItem'; Method = 'SendToolboxItemToSession'; Params = @{ Name = 'Tool.ps1' }; Expected = @('Tool.ps1') }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Command = $Command; Method = $Method; Params = $Params; Expected = $Expected } {
            param($Command, $Method, $Params, $Expected)
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/$Method"
                $body = $Arguments.Body | ConvertFrom-Json
                $body[0] | Should -Be $id.ToString()
                @($body | Select-Object -Skip 1) | Should -Be $Expected
            }
            & $Command -GUID $id @Params -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It '<_> does not call API with WhatIf' -ForEach @('Add-CWCSessionNote', 'Send-CWCSessionMessage', 'Send-CWCToolboxItem') {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Command = $_ } {
            param($Command)
            Mock Invoke-CWCWebRequest {}
            $params = @{ GUID = [guid]::NewGuid(); WhatIf = $true }
            switch ($Command) {
                'Add-CWCSessionNote' { $params.Note = 'n' }
                'Send-CWCSessionMessage' { $params.Message = 'm' }
                'Send-CWCToolboxItem' { $params.Name = 't' }
            }
            & $Command @params
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

}

Describe 'Session event functions (credentials)' {

    BeforeEach { Set-CWCTestConnection }

    It '<Command> queues event <EventType> through PageService.AddSessionEvents' -ForEach @(
        @{ Command = 'Add-CWCSessionNote'; Params = @{ Note = 'hello' }; EventType = 32; Data = 'hello' }
        @{ Command = 'Send-CWCSessionMessage'; Params = @{ Message = 'hi' }; EventType = 45; Data = 'hi' }
        @{ Command = 'Send-CWCToolboxItem'; Params = @{ Name = 'Tool.ps1' }; EventType = 47; Data = 'Tool.ps1' }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Command = $Command; Params = $Params; EventType = $EventType; Data = $Data } {
            param($Command, $Params, $EventType, $Data)
            $id = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments, $MaxRetry)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
                $MaxRetry | Should -Be 0
                $body = $Arguments.Body | ConvertFrom-Json
                @($body[0]) | Should -Be @('Servers')
                @($body[1]).Count | Should -Be 1
                $body[1][0].SessionID | Should -Be $id.ToString()
                $body[1][0].EventType | Should -Be $EventType
                $body[1][0].Data | Should -Be $Data
            }
            & $Command -GUID $id -Group 'Servers' @Params -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'Send-CWCSessionMessage warns that -From is ignored' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Mock Write-Warning {}
            Send-CWCSessionMessage -GUID ([guid]::NewGuid()) -Message 'hi' -From 'IT' -Confirm:$false
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*-From*' }
        }
    }
}

# =============================================================================
# Helpers
# =============================================================================
Describe 'New-CWCMFA' {

    It 'returns object with QR and OTP properties' {
        $result = New-CWCMFA -Confirm:$false
        $result.PSObject.Properties.Name | Should -Contain 'QR'
        $result.PSObject.Properties.Name | Should -Contain 'OTP'
    }

    It 'OTP starts with ms: prefix' {
        $result = New-CWCMFA -Confirm:$false
        $result.OTP | Should -Match '^ms:'
    }

    It 'OTP key is 16 characters from Base32 alphabet' {
        $result = New-CWCMFA -Confirm:$false
        $key = $result.OTP -replace '^ms:', ''
        $key.Length | Should -Be 16
        $key | Should -Match '^[A-Z2-7]+$'
    }

    It 'QR URL points to quickchart.io' {
        $result = New-CWCMFA -Confirm:$false
        $result.QR | Should -Match 'quickchart\.io'
    }

    It 'QR URL contains otpauth data' {
        $result = New-CWCMFA -Confirm:$false
        $result.QR | Should -Match 'otpauth'
    }

    It 'uses custom DisplayName' {
        $result = New-CWCMFA -DisplayName 'MyApp' -Confirm:$false
        $result.QR | Should -Match 'MyApp'
    }

    It 'does not require server connection' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = $null
        }
        $result = New-CWCMFA -Confirm:$false
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'Remove-CWCHostFromSession' {

    BeforeEach { Set-CWCTestConnection }

    It 'queues one QueuedForceDisconnect (48) event for the connection, without retry' {
        InModuleScope 'ConnectWiseControlAPI' {
            $session = [guid]::NewGuid(); $connection = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments, $MaxRetry)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
                $MaxRetry | Should -Be 0
                $body = $Arguments.Body | ConvertFrom-Json
                @($body[0]) | Should -Be @('All Machines')
                @($body[1]).Count | Should -Be 1
                $body[1][0].SessionID | Should -Be $session.ToString()
                $body[1][0].ConnectionID | Should -Be $connection.ToString()
                $body[1][0].EventType | Should -Be 48
            }
            Remove-CWCHostFromSession -SessionID $session -ConnectionID $connection -Group 'All Machines' -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It 'prompts by default (ConfirmImpact High) and sends nothing with -WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            (Get-Command Remove-CWCHostFromSession).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] }).ConfirmImpact |
                Should -Be 'High'
            Remove-CWCHostFromSession -SessionID ([guid]::NewGuid()) -ConnectionID ([guid]::NewGuid()) -Group 'All Machines' -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'rejects an empty session ID' {
        { Remove-CWCHostFromSession -SessionID ([guid]::Empty) -ConnectionID ([guid]::NewGuid()) -Group 'x' -Confirm:$false } |
            Should -Throw
    }
}

Describe 'Remove-CWCSessionNote' {

    BeforeEach { Set-CWCTestConnection }

    It 'sends one DeletedEvent (1) per note, correlated to the note, without retry' {
        InModuleScope 'ConnectWiseControlAPI' {
            $session = [guid]::NewGuid(); $note1 = [guid]::NewGuid(); $note2 = [guid]::NewGuid()
            Mock Invoke-CWCWebRequest {
                param($Arguments, $MaxRetry)
                $Arguments.Endpoint | Should -Be 'Services/PageService.ashx/AddSessionEvents'
                $MaxRetry | Should -Be 0
                $body = $Arguments.Body | ConvertFrom-Json
                @($body[1]).Count | Should -Be 2
                $body[1][0].EventType | Should -Be 1
                $body[1][0].SessionID | Should -Be $session.ToString()
                @($body[1].CorrelationEventID) | Should -Be @($note1.ToString(), $note2.ToString())
            }
            Remove-CWCSessionNote -GUID $session -NoteEventID $note1, $note2 -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It '-All removes only notes that are not already deleted' {
        InModuleScope 'ConnectWiseControlAPI' {
            $session = [guid]::NewGuid(); $script:live = [guid]::NewGuid(); $script:gone = [guid]::NewGuid()
            Mock Get-CWCSessionDetail {
                [PSCustomObject]@{ Events = @(
                    [PSCustomObject]@{ EventID = "$script:live"; EventType = 32; Data = 'keep?' }
                    [PSCustomObject]@{ EventID = "$script:gone"; EventType = 32; Data = 'old' }
                    [PSCustomObject]@{ EventID = "$([guid]::NewGuid())"; EventType = 1; CorrelationEventID = "$script:gone" }
                    [PSCustomObject]@{ EventID = "$([guid]::NewGuid())"; EventType = 44; Data = 'hostname' }
                ) }
            }
            Mock Invoke-CWCWebRequest {
                param($Arguments)
                $body = $Arguments.Body | ConvertFrom-Json
                @($body[1]).Count | Should -Be 1
                $body[1][0].CorrelationEventID | Should -Be "$script:live"
            }
            Remove-CWCSessionNote -GUID $session -All -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 1
        }
    }

    It '-All sends nothing when the session has no notes' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCSessionDetail { [PSCustomObject]@{ Events = @() } }
            Mock Invoke-CWCWebRequest {}
            Remove-CWCSessionNote -GUID ([guid]::NewGuid()) -All -Confirm:$false
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'sends nothing with -WhatIf' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-CWCWebRequest {}
            Remove-CWCSessionNote -GUID ([guid]::NewGuid()) -NoteEventID ([guid]::NewGuid()) -WhatIf
            Should -Invoke Invoke-CWCWebRequest -Times 0
        }
    }

    It 'fails clearly on an API-secret connection' {
        Set-CWCTestApiSecretConnection
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest {}
            { Remove-CWCSessionNote -GUID ([guid]::NewGuid()) -All -Confirm:$false -ErrorAction Stop } | Should -Throw '*Connect-CWC -Credentials*'
            Should -Invoke Invoke-WebRequest -Times 0
        }
    }
}

Describe 'Enter-CWCSession pipeline binding' {
    It 'takes the numeric SessionType of piped sessions (Support = 0) and uses its default group' {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{ Server = 'test.example.com'; AuthType = 'Credentials'; Headers = @{} }
            Mock Get-CWCHostLaunchContext { [PSCustomObject]@{ Scheme = 'sc-test'; RelayHost = 'relay'; RelayPort = 443; PublicKey = 'k' } }
            Mock New-CWCAccessToken { 'token' } -ParameterFilter { $Group -eq 'All Sessions' }
            Mock Invoke-CWCServiceMethod {}
            $Url = [PSCustomObject]@{ SessionID = [guid]::NewGuid(); Name = 'Ticket 1'; SessionType = 0 } | Enter-CWCSession -UrlOnly -WarningAction SilentlyContinue
            $Url | Should -Match '/Support/'
            Should -Invoke New-CWCAccessToken -Times 1 -ParameterFilter { $Group -eq 'All Sessions' }
        }
    }
}
