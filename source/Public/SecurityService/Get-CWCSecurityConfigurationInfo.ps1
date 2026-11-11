function Get-CWCSecurityConfigurationInfo {
    <#
    .SYNOPSIS
        Returns the server's security configuration (user sources, roles, users).

    .DESCRIPTION
        Calls SecurityService.GetSecurityConfigurationInfo.

    .EXAMPLE
        (Get-CWCSecurityConfigurationInfo).UserSources

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param ()

    Invoke-CWCServiceMethod -Service SecurityService -Method GetSecurityConfigurationInfo -Idempotent
}
