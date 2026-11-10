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

    # Check that we have cached connection info
    if (!$script:CWCServerConnection) {
        $ErrorMessage = @()
        $ErrorMessage += 'Not connected to a Control server.'
        $ErrorMessage += '--> $CWCServerConnection variable not found.'
        $ErrorMessage += "----> Run 'Connect-CWC' to initialize the connection before issuing other CWC cmdlets."
        return Write-Error ($ErrorMessage | Out-String)
    }

    # The two auth methods reach different endpoints: an API secret is only accepted by the
    # RESTful API Manager extension, and that extension ignores Basic auth sessions.
    $IsApiSecretConnection = Test-CWCApiSecretConnection
    $IsRestApiEndpoint = $Arguments.Endpoint -like "App_Extensions/$($script:CWCRestApiExtensionID)/*"
    if ($IsApiSecretConnection -ne $IsRestApiEndpoint) {
        # Name the public function the user called, not the private request helpers.
        $Caller = Get-PSCallStack | Select-Object -Skip 1 -ExpandProperty Command |
            Where-Object { $_ -notin 'Invoke-CWCServiceMethod', 'Invoke-CWCWebRequest' } | Select-Object -First 1
        if (-not $Caller -or $Caller -eq '<ScriptBlock>') { $Caller = 'This command' }
        if ($IsApiSecretConnection) {
            return Write-Error "$Caller is not available when connected with -ApiSecret (RESTful API Manager). Connect with 'Connect-CWC -Credentials' to use it."
        }
        return Write-Error "$Caller requires the RESTful API Manager extension. Connect with 'Connect-CWC -ApiSecret' to use it."
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
                foreach ($SecretHeader in 'Authorization', 'CTRLAuthHeader', 'x-anti-forgery-token') {
                    try { $null = $FailedRequest.Headers.Remove($SecretHeader) } catch { Write-Verbose "Could not strip $SecretHeader from the failed request." }
                }
            }

            # Retry on HTTP 500 when the caller allows it (no response yields 0)
            $StatusCode = [int]$_.Exception.Response.StatusCode
            if ($StatusCode -eq 500 -and $Retry -lt $MaxRetry) {
                $Retry++
                # Exponential backoff: 2, 4, 8 ... seconds
                $Wait = [math]::Pow(2, $Retry)
                Write-Warning "HTTP 500 from the server; retry $Retry/$MaxRetry in $Wait seconds."
                Start-Sleep -Seconds $Wait
                continue
            }

            # Build the error message, keeping the server's error body
            $ErrorMessage = @()
            if ($StatusCode -eq 500 -and $MaxRetry -gt 0) { $ErrorMessage += "Max retries hit ($MaxRetry). Status: 500" }

            if ($_.Exception.Response -and $PSVersionTable.PSVersion.Major -lt 6) {
                # Error bodies are not always JSON (IIS 401/404 pages) and the stream may be unreadable;
                # don't let reading or parsing it mask the status.
                $ErrBody = $null
                try {
                    $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $ErrBody = $Reader.ReadToEnd() | ConvertFrom-Json
                }
                catch { $ErrBody = $null }

                if ($ErrBody.code) {
                    $ErrorMessage += 'An exception has been thrown.'
                    $ErrorMessage += "--> $($ErrBody.code)"
                    if ($ErrBody.code -eq 'Unauthorized') {
                        $ErrorMessage += "-----> $($ErrBody.message)"
                        $ErrorMessage += "-----> Use 'Disconnect-CWC' or 'Connect-CWC -Force' to set new authentication."
                    }
                    else {
                        $ErrorMessage += "-----> $($ErrBody.code): $($ErrBody.message)"
                        $ErrorMessage += '-----> ^ Error has not been documented please report. ^'
                    }
                }
                elseif ($_.Exception.message) {
                    $ErrorMessage += 'An exception has been thrown.'
                    $ErrorMessage += "--> $($_.Exception.message)"
                }
            }

            if ($_.ErrorDetails) {
                $ErrorMessage += 'An error has been thrown.'
                $ErrorMessage += "--> $($_.ErrorDetails.code)"
                $ErrorMessage += "--> $($_.ErrorDetails.message)"
                if ($_.ErrorDetails.errors.message) {
                    $ErrorMessage += "-----> $($_.ErrorDetails.errors.message)"
                }
            }

            # Nothing beyond the retry line: fall back to the exception itself
            if ($ErrorMessage.Count -le 1) { $ErrorMessage += "$_" }
            $ErrorMessage += $_.ScriptStackTrace

            return Write-Error ($ErrorMessage | Out-String)
        }
    }

    return $Result.content | ConvertFrom-Json
}