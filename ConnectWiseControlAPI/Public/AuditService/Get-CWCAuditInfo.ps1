function Get-CWCAuditInfo {
    [CmdletBinding()]
    param ()

    Invoke-CWCServiceMethod -Service AuditService -Method GetAuditInfo -Idempotent
}
