function Get-CWCAuditLog {
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
        Write-Warning '-IncludeSessionCaptures is no longer supported by the Control server and is ignored.'
    }

    # Server signature: QueryAuditLog(minTime, maxTime, sessionName, sessionEventTypes[], securityEventTypes[])
    Invoke-CWCServiceMethod -Service AuditService -Method QueryAuditLog -Idempotent -Arguments @(
        $StartDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ'),
        $EndDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ'),
        $SessionName,
        $EventTypes,
        $SecurityTypes
    )
}
