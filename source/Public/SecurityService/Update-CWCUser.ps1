function Update-CWCUser {
    <#
    .SYNOPSIS
        Updates an internal user.

    .DESCRIPTION
        Reads the user, applies the given changes and saves it (SecurityService.SaveUser). Parameters not
        given keep their current values. The password is never written to verbose or debug output.

    .PARAMETER UserToUpdate
        User name of the account to update.

    .PARAMETER NewUserName
        New user name.

    .PARAMETER Password
        New password.

    .PARAMETER OTP
        The OTP key used for MFA. Can be generated with New-CWCMFA.

    .PARAMETER DisplayName
        New display name.

    .PARAMETER Email
        New email address.

    .PARAMETER SecurityGroups
        Roles the user should be a member of.

    .PARAMETER ForcePassChange
        Force the user to change their password at next login.

    .EXAMPLE
        Update-CWCUser -UserToUpdate 'jdoe' -Password (Read-Host -AsSecureString)

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [string]$UserToUpdate,
        [string]$NewUserName,
        [secureString]$Password,
        [string]$OTP,
        [string]$DisplayName,
        [string]$Email,
        [string[]]$SecurityGroups,
        [boolean]$ForcePassChange = $False
    )

    $Security = Get-CWCSecurityConfigurationInfo -ErrorAction Stop
    $Internal = $Security.UserSources | Where-Object { $_.ResourceKey -eq $script:InternalUserSource }
    $User = $Internal.Users | Where-Object { $_.Name -eq $UserToUpdate }
    if(!$User){ return Write-Error "Unable to find user $UserToUpdate" }

    $Update = @(
        $script:InternalUserSource,
        $UserToUpdate,
        $User.Name,
        $null,
        $null,
        $User.PasswordQuestion,
        $User.DisplayName,
        $User.Comment,
        $User.Email,
        $User.RoleNames,
        $False
    )

    if($NewUserName){ $Update[2] = $NewUserName }
    if($Password){
        $PasswordPlain = ConvertFrom-CWCSecureString $Password
        $Update[3] = $PasswordPlain
        $Update[4] = $PasswordPlain
    }
    if($OTP){ $Update[5] = $OTP }
    if($DisplayName){ $Update[6] = $DisplayName }
    if($Email){ $Update[8] = $Email }
    if($SecurityGroups){ $Update[9] = $SecurityGroups }
    if($ForcePassChange){ $Update[10] = $True }

    if ($PSCmdlet.ShouldProcess($UserToUpdate, "Update-CWCUser")) {
        Invoke-CWCServiceMethod -Service SecurityService -Method SaveUser -Arguments $Update -Sensitive
    }
}
