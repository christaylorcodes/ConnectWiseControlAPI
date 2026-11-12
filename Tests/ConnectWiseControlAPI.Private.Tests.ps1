#Requires -Module Pester

<#
.SYNOPSIS
    Mocked tests for private helper functions.

.DESCRIPTION
    Tests Join-Url and Invoke-CWCWebRequest private functions using
    InModuleScope and mocked dependencies.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseControlAPI.Private.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = & (Join-Path $PSScriptRoot 'TestHelpers\Resolve-TestModuleManifest.ps1')
    Import-Module $ManifestPath -Force
}

AfterAll {
    Get-Module 'ConnectWiseControlAPI' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Join-Url
# =============================================================================
Describe 'Join-Url' {

    It 'joins base and child path' {
        InModuleScope 'ConnectWiseControlAPI' {
            $result = Join-Url -Path 'https://server.com' -ChildPath 'Services/Test.ashx'
            $result | Should -Be 'https://server.com/Services/Test.ashx'
        }
    }

    It 'trims trailing slash from Path' {
        InModuleScope 'ConnectWiseControlAPI' {
            $result = Join-Url -Path 'https://server.com/' -ChildPath 'endpoint'
            $result | Should -Be 'https://server.com/endpoint'
        }
    }

    It 'trims leading slash from ChildPath' {
        InModuleScope 'ConnectWiseControlAPI' {
            $result = Join-Url -Path 'https://server.com' -ChildPath '/endpoint'
            $result | Should -Be 'https://server.com/endpoint'
        }
    }

    It 'handles both trailing and leading slashes' {
        InModuleScope 'ConnectWiseControlAPI' {
            $result = Join-Url -Path 'https://server.com/' -ChildPath '/endpoint'
            $result | Should -Be 'https://server.com/endpoint'
        }
    }

    It 'handles multi-segment child paths' {
        InModuleScope 'ConnectWiseControlAPI' {
            $result = Join-Url -Path 'https://server.com' -ChildPath 'Services/PageService.ashx/GetLiveData'
            $result | Should -Be 'https://server.com/Services/PageService.ashx/GetLiveData'
        }
    }
}

# =============================================================================
# Invoke-CWCWebRequest
# =============================================================================
Describe 'Invoke-CWCWebRequest' {

    BeforeEach {
        # Default fake connection in module script scope. Tests that need a
        # different state (no connection, custom headers) override it inline.
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{
                Server  = 'test.example.com'
                Headers = @{ 'Authorization' = 'Basic dGVzdDp0ZXN0' }
            }
        }
    }

    Context 'Connection Check' {
        It 'returns error when not connected' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection = $null
                $result = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'test' } 2>&1
                $result | Should -Match 'Not connected'
            }
        }
    }

    Context 'URI Construction' {
        BeforeEach {
            Mock Invoke-WebRequest -ModuleName 'ConnectWiseControlAPI' {
                [PSCustomObject]@{
                    Content = '{"result":"ok"}'
                    Headers = @{}
                }
            }
        }

        It 'constructs full URI from server and endpoint' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = 'Services/PageService.ashx/GetLiveData'; Method = 'Post' }
                Invoke-CWCWebRequest -Arguments $arguments
                Should -Invoke Invoke-WebRequest -Times 1
                $arguments.URI | Should -Be 'https://test.example.com/Services/PageService.ashx/GetLiveData'
            }
        }

        It 'removes Endpoint key from arguments after constructing URI' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                $arguments.Keys | Should -Not -Contain 'Endpoint'
            }
        }

        It 'sets UseBasicParsing to true' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                $arguments.UseBasicParsing | Should -BeTrue
            }
        }

        It 'passes headers from connection state' {
            InModuleScope 'ConnectWiseControlAPI' {
                $testHeaders = @{
                    'Authorization'        = 'Basic dGVzdDp0ZXN0'
                    'x-anti-forgery-token' = 'abc123'
                }
                $script:CWCServerConnection = @{
                    Server  = 'test.example.com'
                    Headers = $testHeaders
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                $arguments.Headers.Authorization | Should -Be 'Basic dGVzdDp0ZXN0'
                $arguments.Headers.'x-anti-forgery-token' | Should -Be 'abc123'
            }
        }

        It 'passes a copy of the headers, not the connection state hashtable' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                [object]::ReferenceEquals($arguments.Headers, $script:CWCServerConnection.Headers) | Should -BeFalse
            }
        }
    }

    Context 'Debug output' {
        It 'redacts auth headers in debug output' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{}'; Headers = @{} } }
                $script:CWCServerConnection.Headers.'x-anti-forgery-token' = 'antiforgerysecret'
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $DebugPreference = 'Continue'  # not -Debug: PS 5.1 -Debug prompts (Inquire), which fails without a console
                $debugOutput = Invoke-CWCWebRequest -Arguments $arguments 5>&1 | Out-String
                $debugOutput | Should -Not -Match 'dGVzdDp0ZXN0'
                $debugOutput | Should -Not -Match 'antiforgerysecret'
                $debugOutput | Should -Match 'redacted'
            }
        }
    }

    Context 'API secret connection' {
        BeforeEach {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection = @{
                    Server    = 'test.example.com'
                    AuthType  = 'ApiSecret'
                    ApiSecret = ('topsecretvalue' | ConvertTo-SecureString -AsPlainText -Force)
                    Headers   = @{ 'origin' = 'https://test.example.com' }
                }
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ Content = '[]'; Headers = @{ 'Set-Cookie' = 'x=1' } }
                }
            }
        }

        It 'sends the secret as CTRLAuthHeader on RESTful API Manager endpoints' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"; Method = 'Post' }
                Invoke-CWCWebRequest -Arguments $arguments
                Should -Invoke Invoke-WebRequest -Times 1
                $arguments.Headers.CTRLAuthHeader | Should -Be 'topsecretvalue'
                $arguments.Headers.Keys | Should -Not -Contain 'authorization'
            }
        }

        It 'never sends a WebSession on API-secret connections' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection.WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"; Method = 'Post' }
                Invoke-CWCWebRequest -Arguments $arguments
                Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $null -eq $WebSession }
            }
        }

        It 'does not persist the plaintext secret or cookies in connection state' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"; Method = 'Post' }
                Invoke-CWCWebRequest -Arguments $arguments
                $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'CTRLAuthHeader'
                $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'Set-Cookie'
            }
        }

        It 'redacts the secret in debug output' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"; Method = 'Post' }
                $DebugPreference = 'Continue'  # not -Debug: PS 5.1 -Debug prompts (Inquire), which fails without a console
                $debugOutput = Invoke-CWCWebRequest -Arguments $arguments 5>&1 | Out-String
                $debugOutput | Should -Not -Match 'topsecretvalue'
            }
        }

        It 'does not retry extension calls on HTTP 500 (they are not idempotent)' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Start-Sleep {}
                Mock Invoke-WebRequest {
                    $response = [PSCustomObject]@{ StatusCode = 500 }
                    $exception = [System.Exception]::new('500')
                    $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response -Force
                    throw [System.Management.Automation.ErrorRecord]::new($exception, 'x', 'NotSpecified', $null)
                }
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/CreateSession"; Method = 'Post' }
                $null = Invoke-CWCWebRequest -Arguments $arguments -WarningAction SilentlyContinue 2>&1
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            }
        }

        It 'refuses non-extension endpoints without calling the server' {
            InModuleScope 'ConnectWiseControlAPI' {
                $arguments = @{ Endpoint = 'Services/PageService.ashx/GetLiveData'; Method = 'Post' }
                $result = Invoke-CWCWebRequest -Arguments $arguments 2>&1
                $result.Exception.Message | Should -Match 'Connect-CWC -Credentials'
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }

        It 'refuses RESTful API Manager endpoints on a credentials connection' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection = @{
                    Server  = 'test.example.com'
                    Headers = @{ 'Authorization' = 'Basic dGVzdDp0ZXN0' }
                }
                $arguments = @{ Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/GetSessionsByFilter"; Method = 'Post' }
                $result = Invoke-CWCWebRequest -Arguments $arguments 2>&1
                $result.Exception.Message | Should -Match 'Connect-CWC -ApiSecret'
                Should -Invoke Invoke-WebRequest -Times 0
            }
        }
    }

    Context 'Successful Request' {
        It 'returns parsed JSON from response content' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{
                        Content = '{"name":"TestSession","id":42}'
                        Headers = @{}
                    }
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $result = Invoke-CWCWebRequest -Arguments $arguments
                $result.name | Should -Be 'TestSession'
                $result.id | Should -Be 42
            }
        }

        It 'does not store response Set-Cookie as a request header (issue #22)' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{
                        Content = '{"ok":true}'
                        Headers = @{ 'Set-Cookie' = 'session=abc123; Path=/' }
                    }
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                $script:CWCServerConnection.Headers.Keys | Should -Not -Contain 'Set-Cookie'
            }
        }

        It 'sends the connection WebSession so server cookies go back to the server (issue #22)' {
            InModuleScope 'ConnectWiseControlAPI' {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                $script:CWCServerConnection.WebSession = $session
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{}'; Headers = @{} } }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                Invoke-CWCWebRequest -Arguments $arguments
                Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { [object]::ReferenceEquals($WebSession, $session) }
            }
        }

        It 'redacts the WebSession in debug output' {
            InModuleScope 'ConnectWiseControlAPI' {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                $session.Cookies.Add([System.Net.Cookie]::new('.ASPXAUTH', 'cookiesecretvalue', '/', 'test.example.com'))
                $script:CWCServerConnection.WebSession = $session
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{}'; Headers = @{} } }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $DebugPreference = 'Continue'
                $debugOutput = Invoke-CWCWebRequest -Arguments $arguments 5>&1 | Out-String
                $debugOutput | Should -Not -Match 'cookiesecretvalue'
            }
        }
    }

    Context 'Retry on HTTP 500' {
        BeforeAll {
            # Single factory for the fake HTTP 500 error so both retry tests
            # exercise the same catch path: [int]$_.Exception.Response.StatusCode -eq 500.
            # Stored in module script scope so mock bodies (which run in module scope) can see it.
            InModuleScope 'ConnectWiseControlAPI' {
                $script:NewHttp500ErrorRecord = {
                    $exception = [System.Net.WebException]::new('Server Error')
                    $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 500 }) -Force
                    [System.Management.Automation.ErrorRecord]::new(
                        $exception, 'WebError', 'ConnectionError', $null
                    )
                }
            }
        }

        AfterAll {
            InModuleScope 'ConnectWiseControlAPI' {
                Remove-Variable -Name NewHttp500ErrorRecord -Scope Script -ErrorAction SilentlyContinue
            }
        }

        BeforeEach {
            Mock Start-Sleep -ModuleName 'ConnectWiseControlAPI' {}
        }

        It 'does not retry an application exception (errorType body), and keeps the server message' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest {
                    $record = & $script:NewHttp500ErrorRecord
                    $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"errorType":"SecurityException","message":"Needs permission"}')
                    throw $record
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $result = Invoke-CWCWebRequest -Arguments $arguments -MaxRetry 3 2>&1
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly
                "$result" | Should -Match 'Needs permission'
                $result.FullyQualifiedErrorId | Should -BeLike 'CWC.Http500*'
            }
        }

        It 'retries on HTTP 500 and succeeds' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:RetryCallCount = 0
                Mock Invoke-WebRequest {
                    $script:RetryCallCount++
                    if ($script:RetryCallCount -lt 3) {
                        throw (& $script:NewHttp500ErrorRecord)
                    }
                    [PSCustomObject]@{
                        Content = '{"ok":true}'
                        Headers = @{}
                    }
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $result = Invoke-CWCWebRequest -Arguments $arguments -MaxRetry 5
                $result.ok | Should -BeTrue
                Should -Invoke Start-Sleep -Times 2
            }
        }

        It 'fails after max retries' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest {
                    throw (& $script:NewHttp500ErrorRecord)
                }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Get' }
                $result = Invoke-CWCWebRequest -Arguments $arguments -MaxRetry 3 2>&1
                $result | Should -Match 'Max retries hit'
            }
        }

        It 'does not retry by default (the caller must opt in)' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { throw (& $script:NewHttp500ErrorRecord) }
                $arguments = @{ Endpoint = 'Services/Test.ashx'; Method = 'Post' }
                $null = Invoke-CWCWebRequest -Arguments $arguments 2>&1
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            }
        }
    }

    Context 'MFA connection (#12)' {
        BeforeAll {
            InModuleScope 'ConnectWiseControlAPI' {
                # HTTP 500 with a server error body; the failed request (with a login cookie) as TargetObject
                $script:NewServerErrorRecord = {
                    param([string]$Body, $Request, [int]$StatusCode = 500)
                    $exception = [System.Net.WebException]::new('Server Error')
                    $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = $StatusCode }) -Force
                    $record = [System.Management.Automation.ErrorRecord]::new($exception, 'WebError', 'InvalidResult', $Request)
                    $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body)
                    $record
                }
            }
        }

        BeforeEach {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection = @{
                    Server     = 'test.example.com'
                    AuthType   = 'Mfa'
                    Headers    = @{ 'origin' = 'https://test.example.com' }
                    WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                }
            }
        }

        It 'sends the WebSession and no Authorization header' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{}' } }
                $arguments = @{ Endpoint = 'Services/PageService.ashx/GetEligibleHosts'; Method = 'Post' }
                $null = Invoke-CWCWebRequest -Arguments $arguments
                Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $null -ne $WebSession }
                $arguments.Headers.Keys | Should -Not -Contain 'authorization'
            }
        }

        It 'says the login may have expired on a permission error' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null) }
                $result = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/PageService.ashx/GetSessionDetails'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'MFA login has expired'
                @($err | Where-Object { $_.FullyQualifiedErrorId -like 'CWC.Http500*' }).Count | Should -BeGreaterThan 0
            }
        }

        It 'suggests Connect-CWC -Force on an MFA connection refused with 401 Needs permission, not on a 500' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null 401) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/ToolboxService.ashx/WriteToolboxFileContent'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'MFA login has expired'
                "$err" | Should -Match 'Connect-CWC with -Force'
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/ToolboxService.ashx/WriteToolboxFileContent'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Not -Match 'Connect-CWC with -Force'
            }
        }

        It 'says the login may have expired on an anti-forgery error' {
            InModuleScope 'ConnectWiseControlAPI' {
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"InvalidOperationException","message":"Invalid anti-forgery token"}' $null) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/PageService.ashx/AddSessionEvents'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Match 'MFA login has expired'
            }
        }

        It 'does not add the hint on a credentials connection' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection.AuthType = 'Credentials'
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/PageService.ashx/GetSessionDetails'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Not -Match 'MFA login'
            }
        }

        It 'suggests Connect-CWC -Force on a credentials connection refused with 401 <Case>' -ForEach @(
            @{ Case = 'Needs permission'; Status = 401; LoggingIn = $false; Expected = $true }
            @{ Case = 'while connecting'; Status = 401; LoggingIn = $true; Expected = $false }
            @{ Case = 'but not on a 500'; Status = 500; LoggingIn = $false; Expected = $false }
        ) {
            InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Status = $Status; LoggingIn = $LoggingIn; Expected = $Expected } {
                param($Status, $LoggingIn, $Expected)
                $script:CWCServerConnection.AuthType = 'Credentials'
                if ($LoggingIn) { $script:CWCServerConnection.LoggingIn = $True }
                $script:HintStatus = $Status
                Mock Invoke-WebRequest {
                    throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null $script:HintStatus)
                }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/ToolboxService.ashx/WriteToolboxFileContent'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                ("$err" -match 'Connect-CWC with -Force') | Should -Be $Expected
            }
        }

        It 'does not suggest an expired login while logging in' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:CWCServerConnection.LoggingIn = $True
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $null) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/PageService.ashx/GetEligibleHosts'; Method = 'Post' } -ErrorAction SilentlyContinue -ErrorVariable err
                "$err" | Should -Not -Match 'MFA login'
            }
        }
        It 'strips the login cookie from the failed request kept on the error record' {
            InModuleScope 'ConnectWiseControlAPI' {
                $script:FailedRequest = [System.Net.WebRequest]::Create('https://test.example.com/Services/PageService.ashx/GetSessionDetails')
                $script:FailedRequest.Headers.Add('Cookie', '.ASPXAUTH=cookiesecretvalue')
                $script:FailedRequest.CookieContainer = New-Object System.Net.CookieContainer
                Mock Invoke-WebRequest { throw (& $script:NewServerErrorRecord '{"errorType":"SecurityException","message":"Needs permission"}' $script:FailedRequest) }
                $null = Invoke-CWCWebRequest -Arguments @{ Endpoint = 'Services/PageService.ashx/GetSessionDetails'; Method = 'Post' } -ErrorAction SilentlyContinue
                $script:FailedRequest.Headers['Cookie'] | Should -BeNullOrEmpty
                $script:FailedRequest.CookieContainer | Should -BeNullOrEmpty
            }
        }
    }
}

# =============================================================================
# MFA helpers (#12)
# =============================================================================
Describe 'Get-CWCTotpCode' {

    # RFC 6238 appendix B test key "12345678901234567890" in Base32
    It 'matches the RFC 6238 SHA-1 test vector at T=<Time> (<Digits> digits)' -TestCases @(
        @{ Time = 59; Digits = 8; Expected = '94287082' }
        @{ Time = 59; Digits = 6; Expected = '287082' }
        @{ Time = 1111111109; Digits = 8; Expected = '07081804' }
        @{ Time = 1234567890; Digits = 8; Expected = '89005924' }
        @{ Time = 20000000000; Digits = 8; Expected = '65353130' }
    ) {
        param($Time, $Digits, $Expected)
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Time = $Time; Digits = $Digits; Expected = $Expected } {
            param($Time, $Digits, $Expected)
            $Secret = ConvertTo-SecureString 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' -AsPlainText -Force
            Get-CWCTotpCode -Secret $Secret -UnixTime $Time -Digits $Digits | Should -Be $Expected
        }
    }

    It 'accepts the ms: prefix, lowercase, spaces and padding' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Secret = ConvertTo-SecureString 'MS:gezd gnbv gy3t qojq gezd gnbv gy3t qojq====' -AsPlainText -Force
            Get-CWCTotpCode -Secret $Secret -UnixTime 59 | Should -Be '287082'
        }
    }

    It 'keeps leading zeros' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Secret = ConvertTo-SecureString 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' -AsPlainText -Force
            Get-CWCTotpCode -Secret $Secret -UnixTime 1111111109 -Digits 8 | Should -Be '07081804'
        }
    }

    It 'rejects a secret that is not Base32, without echoing it' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Secret = ConvertTo-SecureString 'not-base32-secret!' -AsPlainText -Force
            $err = $null
            try { Get-CWCTotpCode -Secret $Secret -UnixTime 59 } catch { $err = $_ }
            "$err" | Should -Match 'not valid Base32'
            "$err" | Should -Not -Match 'secret!'
        }
    }

    It 'accepts an otpauth:// link and any type prefix' -TestCases @(
        @{ Text = 'otpauth://totp/CW%20Control:user?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=x' }
        @{ Text = 'totp:GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' }
    ) {
        param($Text)
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Text = $Text } {
            param($Text)
            $Secret = ConvertTo-SecureString $Text -AsPlainText -Force
            Get-CWCTotpCode -Secret $Secret -UnixTime 59 | Should -Be '287082'
        }
    }

    It 'names the kind of bad character, not the character itself, for digits' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Secret = ConvertTo-SecureString 'GEZD9NBV' -AsPlainText -Force
            $err = $null
            try { Get-CWCTotpCode -Secret $Secret -UnixTime 59 } catch { $err = $_ }
            "$err" | Should -Match 'digit 0, 1, 8 or 9'
            "$err" | Should -Not -Match 'GEZD'
        }
    }

    It 'rejects a secret that decodes to nothing' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Secret = ConvertTo-SecureString 'ms:A' -AsPlainText -Force
            { Get-CWCTotpCode -Secret $Secret -UnixTime 59 } | Should -Throw '*empty or too short*'
        }
    }
}

Describe 'ConvertFrom-CWCBase32' {
    It 'decodes RFC 4648 vectors' -TestCases @(
        @{ Text = 'MY======'; Expected = 'f' }
        @{ Text = 'MZXW6==='; Expected = 'foo' }
        @{ Text = 'MZXW6YTBOI======'; Expected = 'foobar' }
    ) {
        param($Text, $Expected)
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Text = $Text; Expected = $Expected } {
            param($Text, $Expected)
            [Text.Encoding]::ASCII.GetString((ConvertFrom-CWCBase32 -Text $Text)) | Should -Be $Expected
        }
    }
}

Describe 'Get-CWCTotpLoginCode' {

    BeforeEach {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCLastTotpStep = @{}
            Mock Start-Sleep {}
            Mock Get-CWCTotpCode { "$UnixTime" }
        }
    }

    It 'uses the current step when there is time left' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCUnixTime { [int64]3010 }   # 10 s into step 100
            $Secret = ConvertTo-SecureString 'GEZDGNBV' -AsPlainText -Force
            $Result = Get-CWCTotpLoginCode -Secret $Secret -Key 'server|user'
            $Result.Code | Should -Be '3010'
            $Result.Step | Should -Be 100
            Should -Invoke Start-Sleep -Times 0
        }
    }

    It 'waits for the next step when fewer than 3 seconds are left' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCUnixTime { [int64]3028 }   # 2 s left
            $Secret = ConvertTo-SecureString 'GEZDGNBV' -AsPlainText -Force
            $Result = Get-CWCTotpLoginCode -Secret $Secret -Key 'server|user'
            $Result.Code | Should -Be '3030'
            $Result.Step | Should -Be 101
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 2 }
        }
    }

    It 'waits for the next step when this one was already sent for the same server and user' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCUnixTime { [int64]3010 }
            $script:CWCLastTotpStep['server|user'] = 100
            $Secret = ConvertTo-SecureString 'GEZDGNBV' -AsPlainText -Force
            (Get-CWCTotpLoginCode -Secret $Secret -Key 'server|user').Code | Should -Be '3030'
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 20 }
            # Another user is independent
            (Get-CWCTotpLoginCode -Secret $Secret -Key 'server|other').Code | Should -Be '3010'
        }
    }

    It 'does not record the step itself (the caller does, once the server has seen the code)' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Get-CWCUnixTime { [int64]3010 }
            $Secret = ConvertTo-SecureString 'GEZDGNBV' -AsPlainText -Force
            $null = Get-CWCTotpLoginCode -Secret $Secret -Key 'server|user'
            $script:CWCLastTotpStep.Count | Should -Be 0
        }
    }
}
Describe 'Get-CWCIdentityHash' {
    It 'matches for the same user (any case) and password, and differs for another password' {
        InModuleScope 'ConnectWiseControlAPI' {
            $a = [pscredential]::new('User', (ConvertTo-SecureString 'pw1' -AsPlainText -Force))
            $b = [pscredential]::new('user', (ConvertTo-SecureString 'pw1' -AsPlainText -Force))
            $c = [pscredential]::new('user', (ConvertTo-SecureString 'pw2' -AsPlainText -Force))
            Get-CWCIdentityHash -Credentials $a | Should -Be (Get-CWCIdentityHash -Credentials $b)
            Get-CWCIdentityHash -Credentials $a | Should -Not -Be (Get-CWCIdentityHash -Credentials $c)
            Get-CWCIdentityHash -Credentials $a | Should -Not -Match 'pw1'
        }
    }
}

# =============================================================================
# Invoke-CWCServiceMethod
# =============================================================================
Describe 'Invoke-CWCServiceMethod' {

    BeforeEach {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{
                Server  = 'test.example.com'
                Headers = @{ 'Authorization' = 'Basic dGVzdDp0ZXN0' }
            }
            $script:ServiceMethodCall = $null
            Mock Invoke-CWCWebRequest {
                param($Arguments, $MaxRetry, [switch]$SensitiveBody)
                $script:ServiceMethodCall = @{ Arguments = $Arguments; MaxRetry = $MaxRetry; SensitiveBody = [bool]$SensitiveBody }
            }
        }
    }

    It 'builds built-in service endpoints' {
        InModuleScope 'ConnectWiseControlAPI' {
            Invoke-CWCServiceMethod -Service PageService -Method GetEligibleHosts
            $script:ServiceMethodCall.Arguments.Endpoint | Should -Be 'Services/PageService.ashx/GetEligibleHosts'
            $script:ServiceMethodCall.Arguments.Keys | Should -Not -Contain 'Body'
        }
    }

    It 'builds RESTful API Manager and other extension endpoints' {
        InModuleScope 'ConnectWiseControlAPI' {
            Invoke-CWCServiceMethod -RestApi -Method CreateSession -Arguments 1
            $script:ServiceMethodCall.Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/CreateSession"
            Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method GetRemoteWorkforceSessions -Arguments @()
            $script:ServiceMethodCall.Arguments.Endpoint | Should -Be "App_Extensions/$($script:CWCRemoteWorkforceExtensionID)/Service.ashx/GetRemoteWorkforceSessions"
        }
    }

    It 'serializes arguments as a JSON array (<Name>)' -TestCases @(
        @{ Name = 'single value'; Value = (, 'only'); Expected = '["only"]' }
        @{ Name = 'empty list'; Value = (, @()); Expected = '[]' }
        @{ Name = 'nested group'; Value = (, @(@('Machines'), 'x')); Expected = '[["Machines"],"x"]' }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Value = $Value[0]; Expected = $Expected } {
            param($Value, $Expected)
            Invoke-CWCServiceMethod -Service PageService -Method Test -Arguments $Value
            ($script:ServiceMethodCall.Arguments.Body -replace '\s', '') | Should -Be $Expected
        }
    }

    It 'retries only idempotent calls' {
        InModuleScope 'ConnectWiseControlAPI' {
            Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments 1
            $script:ServiceMethodCall.MaxRetry | Should -Be 0
            Invoke-CWCServiceMethod -Service PageService -Method GetSessionDetails -Arguments 1 -Idempotent
            $script:ServiceMethodCall.MaxRetry | Should -BeGreaterThan 0
        }
    }

    It 'keeps sensitive arguments out of verbose output and marks the body sensitive' {
        InModuleScope 'ConnectWiseControlAPI' {
            $verbose = Invoke-CWCServiceMethod -Service SecurityService -Method SaveUser -Arguments @('user', 'hunter2secret') -Sensitive -Verbose 4>&1 | Out-String
            $verbose | Should -Not -Match 'hunter2secret'
            $script:ServiceMethodCall.SensitiveBody | Should -BeTrue
        }
    }

}

Describe 'Connection-type mismatch through Invoke-CWCServiceMethod' {

    It 'names the public function the user called, not the private helpers' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest {}
            $script:CWCServerConnection = @{
                Server    = 'test.example.com'
                AuthType  = 'ApiSecret'
                ApiSecret = ('s' | ConvertTo-SecureString -AsPlainText -Force)
                Headers   = @{}
            }
            $result = Get-CWCSessionGroup 2>&1
            ($result | Out-String) | Should -Match 'Get-CWCSessionGroup is not available'
            Should -Invoke Invoke-WebRequest -Times 0
        }
    }
}


# =============================================================================
# Host client launch (Enter-CWCSession helpers)
# =============================================================================
Describe 'New-CWCHostLaunchUrl' {

    It 'builds the web client format and escapes key, token and title like encodeURIComponent' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Url = New-CWCHostLaunchUrl -Scheme 'sc-0123456789abcdef' -RelayHost 'relay.example.com' -RelayPort 443 `
                -SessionID '11111111-2222-3333-4444-555555555555' -PublicKey 'Bg+A/b==' -AccessToken 'T+o/k=' `
                -SessionType 'Support' -Title "B$([char]0x00FC)ro PC #1"
            $Url | Should -BeExactly 'sc-0123456789abcdef://relay.example.com:443/11111111-2222-3333-4444-555555555555/Bg%2BA%2Fb%3D%3D/T%2Bo%2Fk%3D//Support/B%C3%BCro%20PC%20%231/None/'
        }
    }

    It 'fills participant name, attributes and logon session when given' {
        InModuleScope 'ConnectWiseControlAPI' {
            $Url = New-CWCHostLaunchUrl -Scheme 'sc-1' -RelayHost 'h' -RelayPort 80 -SessionID ([guid]::Empty) -PublicKey 'k' `
                -AccessToken 't' -SessionType 'Access' -ParticipantName 'A B' -Attributes 'SuspendedInput' -LogonSessionID '0'
            $Url | Should -BeExactly 'sc-1://h:80/00000000-0000-0000-0000-000000000000/k/t/A%20B/Access//SuspendedInput/0'
        }
    }
}

Describe 'Get-CWCHostLaunchContext' {

    BeforeEach {
        InModuleScope 'ConnectWiseControlAPI' {
            $script:CWCServerConnection = @{ Server = 'test.example.com'; Headers = @{} }
        }
    }

    It 'reads scheme, relay and key from Script.ashx and caches them on the connection' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ Content = 'SC={"res":{},"context":{"clp":{"h":"relay.example.com","p":8041,"k":"Bg+A\/b=="},"x":1,"instanceUrlScheme":"sc-0123456789abcdef"}};' }
            }
            $Context = Get-CWCHostLaunchContext
            $Context.Scheme | Should -Be 'sc-0123456789abcdef'
            $Context.RelayHost | Should -Be 'relay.example.com'
            $Context.RelayPort | Should -Be 8041
            $Context.PublicKey | Should -BeExactly 'Bg+A/b=='
            $null = Get-CWCHostLaunchContext
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://test.example.com/Script.ashx' -and -not $Headers }
            $script:CWCServerConnection.HostLaunch.Scheme | Should -Be 'sc-0123456789abcdef'
        }
    }

    It 'rejects a scheme that is not sc-<id>' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"clp":{"h":"h","p":80,"k":"k"},"instanceUrlScheme":"javascript"}' } }
            { Get-CWCHostLaunchContext -ErrorAction Stop } | Should -Throw '*did not publish client launch settings*'
            $script:CWCServerConnection.HostLaunch | Should -BeNullOrEmpty
        }
    }

    It 'rejects an invalid <Case>' -ForEach @(
        @{ Case = 'port'; Clp = '{"h":"h","p":70000,"k":"k"}' }
        @{ Case = 'host'; Clp = '{"h":"h/../x","p":80,"k":"k"}' }
        @{ Case = 'key'; Clp = '{"h":"h","p":80,"k":""}' }
    ) {
        InModuleScope 'ConnectWiseControlAPI' -Parameters @{ Clp = $Clp } {
            param($Clp)
            $script:TestClpJson = $Clp
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = "{`"clp`":$($script:TestClpJson),`"instanceUrlScheme`":`"sc-1`"}" } }
            { Get-CWCHostLaunchContext -ErrorAction Stop } | Should -Throw '*incomplete or invalid*'
        }
    }

    It 'reports a failed request' {
        InModuleScope 'ConnectWiseControlAPI' {
            Mock Invoke-WebRequest { throw 'Connection refused' }
            { Get-CWCHostLaunchContext -ErrorAction Stop } | Should -Throw '*Could not read the client launch settings*Connection refused*'
        }
    }
}

Describe 'Start-CWCHostClient' {

    It 'throws a fixed message and leaves no trace of the URL in $Error' -Skip:([Environment]::OSVersion.Platform -ne 'Win32NT') {
        InModuleScope 'ConnectWiseControlAPI' {
            $Missing = Join-Path ([IO.Path]::GetTempPath()) 'cwc-missing-SECRETTOKEN\client.exe'
            { Start-CWCHostClient -Url $Missing } | Should -Throw 'Could not start the ScreenConnect client (*).'
            ($Error | Out-String) | Should -Not -Match 'SECRETTOKEN'
        }
    }
}