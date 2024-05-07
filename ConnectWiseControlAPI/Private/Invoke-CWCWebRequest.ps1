function Invoke-CWCWebRequest {
    [CmdletBinding()]
    param(
        $Arguments,
        [int]$MaxRetry = 5
    )

    # Check that we have cached connection info
    if (!$script:CWCServerConnection) {
        $ErrorMessage = @()
        $ErrorMessage += 'Not connected to a Control server.'
        $ErrorMessage += '--> $CWCServerConnection variable not found.'
        $ErrorMessage += "----> Run 'Connect-CWC' to initialize the connection before issuing other CWC cmdlets."
        return Write-Error ($ErrorMessage | Out-String)
    }

    $BaseURI = "https://$($script:CWCServerConnection.Server)"
    $Arguments.URI = Join-Url $BaseURI $Arguments.Endpoint
    $Arguments.remove('Endpoint')
    $Arguments.Headers = $script:CWCServerConnection.Headers
    $Arguments.UseBasicParsing = $true
    Write-Debug "Arguments: $($Arguments | ConvertTo-Json)"

    # Issue request
    try { $Result = Invoke-WebRequest @Arguments }
    catch {
        # Start error message
        $ErrorMessage = @()

        if ($_.Exception.Response -and $PSVersionTable.PSVersion.Major -lt 6) {
            # Read exception response
            $ErrorStream = $_.Exception.Response.GetResponseStream()
            $Reader = New-Object System.IO.StreamReader($ErrorStream)
            $script:ErrBody = $Reader.ReadToEnd() | ConvertFrom-Json

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
            $script:ErrDetails = $_.ErrorDetails
            $ErrorMessage += "--> $($ErrDetails.code)"
            $ErrorMessage += "--> $($ErrDetails.message)"
            if ($ErrDetails.errors.message) {
                $ErrorMessage += "-----> $($ErrDetails.errors.message)"
            }
        }

        if ($ErrorMessage.Length -lt 1) { $ErrorMessage = $_ }
        else { $ErrorMessage += $_.ScriptStackTrace }

        return Write-Error ($ErrorMessage | Out-String)
    }

    # Not sure this will be hit with current iwr error handling
    # May need to move to catch block need to find test
    # TODO Find test for retry
    # Retry the request
    $Retry = 0
    while ($Retry -lt $MaxRetry -and $Result.StatusCode -eq 500) {
        $Retry++
        # ConnectWise Manage recommended wait time
        $Wait = $([math]::pow( 2, $Retry))
        Write-Warning "Issue with request, status: $($Result.StatusCode) $($Result.StatusDescription)"
        Write-Warning "$($Retry)/$($MaxRetry) retries, waiting $($Wait)ms."
        Start-Sleep -Milliseconds $Wait
        $Result = Invoke-WebRequest @Arguments -UseBasicParsing
    }
    if ($Retry -ge $MaxRetry) {
        return Write-Error "Max retries hit. Status: $($Result.StatusCode) $($Result.StatusDescription)"
    }

    if ($script:CWCServerConnection -and $script:CWCServerConnection.Headers) {
        $script:CWCServerConnection.Headers.'Set-Cookie' = $Result.Headers['Set-Cookie']
    }

    if ($Arguments.OutFile) {
        return $Result
    }
    return $Result.content | ConvertFrom-Json
}