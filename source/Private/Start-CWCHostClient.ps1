function Start-CWCHostClient {
    <#
    .SYNOPSIS
        Opens a client launch URL with its registered protocol handler, without exposing the URL.

    .DESCRIPTION
        Uses Process.Start instead of Start-Process: module logging (event 4103) records cmdlet
        parameter bindings, which would put the URL and its access token in the event log, and a
        Start-Process error repeats the URL. On failure the error record is removed from $Error and a
        fixed message is thrown. Windows usually shows an app picker rather than failing when no
        handler is registered, so callers must check for the handler first.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Opens a viewer; Enter-CWCSession owns the user-facing decision.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$Url
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $Url
    $StartInfo.UseShellExecute = $true
    try {
        $null = [System.Diagnostics.Process]::Start($StartInfo)
    }
    catch {
        $ExceptionType = $_.Exception.GetType().Name
        if ($Error.Count -gt 0) { $Error.RemoveAt(0) }
        throw "Could not start the Control client ($ExceptionType)."
    }
}
