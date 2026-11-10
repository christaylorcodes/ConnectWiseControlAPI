function Remove-CWCUser {
    <#
    .SYNOPSIS
        Deletes an internal user.

    .DESCRIPTION
        Calls SecurityService.DeleteUser.

    .PARAMETER User
        User name of the account to delete.

    .EXAMPLE
        Remove-CWCUser -User 'jdoe'

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [string]$User
    )

    if ($PSCmdlet.ShouldProcess($User, 'Delete user')) {
        Invoke-CWCServiceMethod -Service SecurityService -Method DeleteUser -Arguments @($script:InternalUserSource, $User)
    }
}
