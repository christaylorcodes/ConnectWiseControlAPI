function Get-CWCAuditLog {
    <#
    .SYNOPSIS
        Returns audit log entries for a time range.

    .DESCRIPTION
        Calls AuditService.QueryAuditLog. Times are converted to UTC.

    .PARAMETER StartDate
        Start of the time range. Defaults to 24 hours ago. Local times are converted to UTC.

    .PARAMETER EndDate
        End of the time range. Defaults to now. Local times are converted to UTC.

    .PARAMETER SessionName
        Only return entries for sessions with this name.

    .PARAMETER IncludeSessionCaptures
        Deprecated. The server no longer accepts this option; it is ignored with a warning.

    .PARAMETER EventTypes
        Session event type numbers to include, for example 44 (QueuedCommand) or 70 (RanCommand).

    .PARAMETER SecurityTypes
        Security event type numbers to include.

    .EXAMPLE
        Get-CWCAuditLog -StartDate (Get-Date).AddDays(-7) -SessionName 'DESKTOP-01'

        Returns the last 7 days of audit entries for the session named DESKTOP-01.

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param (
        [datetime]$StartDate = (Get-Date).AddDays(-1),
        [datetime]$EndDate = (Get-Date),
        [string]$SessionName,
        # Deprecated: QueryAuditLog no longer accepts this argument. Kept so existing scripts don't break.
        [switch]$IncludeSessionCaptures,
        [int[]]$EventTypes,
        [int[]]$SecurityTypes
    )

    if ($IncludeSessionCaptures) {
        Write-Warning '-IncludeSessionCaptures is no longer supported by the ScreenConnect server and is ignored.'
    }

    # Server signature: QueryAuditLog(minTime, maxTime, sessionName, sessionEventTypes[], securityEventTypes[])
    # Invariant culture: some cultures use another calendar (th-TH) or time separator.
    $Invariant = [Globalization.CultureInfo]::InvariantCulture
    Invoke-CWCServiceMethod -Service AuditService -Method QueryAuditLog -Idempotent -Arguments @(
        $StartDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', $Invariant),
        $EndDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', $Invariant),
        $SessionName,
        $EventTypes,
        $SecurityTypes
    )
}
