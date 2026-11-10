function Get-CWCAuditInfo {
    <#
    .SYNOPSIS
        Shows the current audit settings.

    .DESCRIPTION
        Calls AuditService.GetAuditInfo.

    .EXAMPLE
        Get-CWCAuditInfo

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param ()

    Invoke-CWCServiceMethod -Service AuditService -Method GetAuditInfo -Idempotent
}
