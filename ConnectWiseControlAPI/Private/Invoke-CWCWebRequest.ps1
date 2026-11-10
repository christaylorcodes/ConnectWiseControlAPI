function Invoke-CWCWebRequest {
    [CmdletBinding()]
    param(
        $Arguments,
        # Retries on HTTP 500. Off by default: only the caller knows whether a request is safe to repeat
        # (Invoke-CWCServiceMethod -Idempotent).
        [int]$MaxRetry = 0,
        # Body holds a secret: keep it out of debug output.
        [switch]$SensitiveBody
    )

    # Errors carry an ErrorId so callers can tell them apart without parsing text:
    # CWC.NotConnected, CWC.AuthModeMismatch, CWC.Http<status> (the server answered), CWC.NoResponse.
    if (!$script:CWCServerConnection) {
        return Write-Error "Not connected to a Control server. Run 'Connect-CWC' first." -ErrorId 'CWC.NotConnected' -Category ConnectionError
    }

    # The two auth methods reach different endpoints: an API secret is only accepted by the
    # RESTful API Manager extension, and that extension ignores Basic auth sessions.
    $IsApiSecretConnection = Test-CWCApiSecretConnection
    $IsRestApiEndpoint = $Arguments.Endpoint -like "App_Extensions/$($script:CWCRestApiExtensionID)/*"
    if ($IsApiSecretConnection -ne $IsRestApiEndpoint) {
        # Name the public function the user called: the outermost exported function on the call stack
        # (not a private helper, nor a public function it calls internally).
        $PublicFunctions = @($ExecutionContext.SessionState.Module.ExportedFunctions.Keys)
        $Caller = Get-PSCallStack | Select-Object -ExpandProperty Command |
            Where-Object { $_ -in $PublicFunctions } | Select-Object -Last 1
        if (-not $Caller -or $Caller -eq '<ScriptBlock>') { $Caller = 'This command' }
        $Required = if ($IsApiSecretConnection) { 'Credentials' } else { 'ApiSecret' }
        return Write-Error (Get-CWCAuthModeMessage -Command $Caller -Required $Required) -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
    }

    $BaseURI = "https://$($script:CWCServerConnection.Server)"
    $Arguments.URI = Join-Url $BaseURI $Arguments.Endpoint
    $Arguments.remove('Endpoint')
    $Arguments.UseBasicParsing = $true

    # Copy so per-request headers (the API secret) never persist in the connection state
    $Headers = @{} + $script:CWCServerConnection.Headers
    if ($IsApiSecretConnection) {
        $Headers.CTRLAuthHeader = ConvertFrom-CWCSecureString $script:CWCServerConnection.ApiSecret
    }
    $Arguments.Headers = $Headers

    # Credentials connections send back the cookies the server set (via the WebRequestSession from
    # Connect-CWC); Invoke-WebRequest stores new Set-Cookie values in it automatically.
    # API-secret connections are stateless and never carry cookies.
    if (-not $IsApiSecretConnection -and $script:CWCServerConnection.WebSession) {
        $Arguments.WebSession = $script:CWCServerConnection.WebSession
    }

    # Only build the redacted copy when debug output is on: this runs on every request.
    if ($DebugPreference -ne 'SilentlyContinue') {
        $RedactedHeaderNames = @('authorization', 'ctrlauthheader', 'x-anti-forgery-token', 'cookie', 'set-cookie')
        $DebugArguments = @{} + $Arguments
        if ($DebugArguments.WebSession) { $DebugArguments.WebSession = '<redacted>' }
        if ($SensitiveBody -and $DebugArguments.Body) { $DebugArguments.Body = '<redacted>' }
        $DebugArguments.Headers = @{}
        foreach ($HeaderName in $Headers.Keys) {
            $DebugArguments.Headers[$HeaderName] = if ($RedactedHeaderNames -contains $HeaderName.ToLower()) { '<redacted>' } else { $Headers[$HeaderName] }
        }
        Write-Debug "Arguments: $($DebugArguments | ConvertTo-Json)"
    }

    # Issue request with retry on HTTP 500
    $Retry = 0
    while ($true) {
        try {
            $Result = Invoke-WebRequest @Arguments
            break
        }
        catch {
            # The failed request object (with auth headers) stays on the error record in $Error:
            # HttpRequestMessage on PS 6+, HttpWebRequest on PS 5.1. Strip the secrets from it.
            # Type-name check: a [System.Net.Http.HttpRequestMessage] literal fails on PS 5.1 when the assembly isn't loaded.
            $FailedRequest = $_.TargetObject
            if ($FailedRequest -and $FailedRequest.GetType().FullName -in 'System.Net.Http.HttpRequestMessage', 'System.Net.HttpWebRequest') {
                # Cookie: the .ASPXAUTH login cookie of MFA and credentials connections
                foreach ($SecretHeader in 'Authorization', 'CTRLAuthHeader', 'x-anti-forgery-token', 'Cookie') {
                    try { $null = $FailedRequest.Headers.Remove($SecretHeader) } catch { Write-Verbose "Could not strip $SecretHeader from the failed request." }
                }
                # PS 5.1's HttpWebRequest also references the whole cookie jar
                if ($FailedRequest.PSObject.Properties['CookieContainer']) {
                    try { $FailedRequest.CookieContainer = $null } catch { Write-Verbose 'Could not strip the cookies from the failed request.' }
                }
                # PS 6+ also keeps the request body on the HttpRequestMessage (e.g. a new user's password)
                if ($SensitiveBody -and $FailedRequest.PSObject.Properties['Content']) {
                    try { $FailedRequest.Content = $null } catch { Write-Verbose 'Could not strip the body from the failed request.' }
                }
            }

            # The server's error body, e.g. {"errorType":"SecurityException","message":"Needs permission"}
            $StatusCode = [int]$_.Exception.Response.StatusCode
            $ServerMessage = $_.ErrorDetails.Message
            if (-not $ServerMessage -and $_.Exception.Response -and $PSVersionTable.PSVersion.Major -lt 6) {
                # Fallback for Windows PowerShell when ErrorDetails is empty; the stream may be unreadable.
                try { $ServerMessage = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() }
                catch { $ServerMessage = $null }
            }

            # Retry on HTTP 500 when the caller allows it (no response yields 0). Control answers
            # application exceptions with 500 + {"errorType": ...}: permission failures (including a wrong
            # password), bad arguments, missing sessions. Those fail the same way again, so only retry a
            # 500 without an errorType (a server fault) or one that names a rate limit or timeout.
            $ServerErrorType = $null
            try { $ServerErrorType = ("$ServerMessage" | ConvertFrom-Json -ErrorAction Stop).errorType } catch { $ServerErrorType = $null }
            $IsTransient = -not $ServerErrorType -or "$ServerErrorType" -match 'RateLimit|Timeout|Throttl'
            if ($StatusCode -eq 500 -and $IsTransient -and $Retry -lt $MaxRetry) {
                $Retry++
                # Exponential backoff: 2, 4, 8 ... seconds
                $Wait = [math]::Pow(2, $Retry)
                Write-Warning "HTTP 500 from the server; retry $Retry/$MaxRetry in $Wait seconds."
                Start-Sleep -Seconds $Wait
                continue
            }

            # Build the error message, keeping the server's error body
            $ErrorMessage = @()
            if ($StatusCode -eq 500 -and $Retry -gt 0 -and $Retry -ge $MaxRetry) { $ErrorMessage += "Max retries hit ($MaxRetry). Status: 500" }
            elseif ($StatusCode -gt 0) { $ErrorMessage += "HTTP $StatusCode" }
            if ($ServerMessage) { $ErrorMessage += $ServerMessage }
            else { $ErrorMessage += "$_" }

            # An expired MFA login makes requests run as an anonymous user: they fail with a permission
            # error, or an anti-forgery error because the token belonged to the login.
            if ($StatusCode -gt 0 -and $script:CWCServerConnection.AuthType -eq 'Mfa' -and -not $script:CWCServerConnection.LoggingIn -and
                ("$ServerErrorType" -match 'Security' -or "$ServerMessage" -match 'anti-?forgery|Needs permission')) {
                $ErrorMessage += 'If the MFA login has expired, run Connect-CWC again.'
            }

            if ($StatusCode -gt 0) { $ErrorId = "CWC.Http$StatusCode"; $Category = 'InvalidResult' }
            else { $ErrorId = 'CWC.NoResponse'; $Category = 'ConnectionError' }
            return Write-Error ($ErrorMessage -join ' ') -ErrorId $ErrorId -Category $Category
        }
    }

    return $Result.content | ConvertFrom-Json
}