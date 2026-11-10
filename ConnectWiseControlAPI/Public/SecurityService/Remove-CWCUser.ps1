function Remove-CWCUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [string]$User
    )

    if ($PSCmdlet.ShouldProcess($User, 'Delete user')) {
        Invoke-CWCServiceMethod -Service SecurityService -Method DeleteUser -Arguments @($script:InternalUserSource, $User)
    }
}
