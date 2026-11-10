function New-CWCUser {
    <#
    .SYNOPSIS
        Creates an internal user.

    .DESCRIPTION
        Calls SecurityService.SaveUser. The password is never written to verbose or debug output.

    .PARAMETER Credentials
        User name and password of the new user.

    .PARAMETER OTP
        The OTP key used for MFA. Can be generated with New-CWCMFA.

    .PARAMETER DisplayName
        Display name.

    .PARAMETER Email
        Email address.

    .PARAMETER SecurityGroups
        Roles the user is a member of.

    .PARAMETER ForcePassChange
        Force the user to change their password at next login. Defaults to $true.

    .EXAMPLE
        New-CWCUser -Credentials (Get-Credential -UserName 'jdoe') -Email 'jdoe@example.com' -SecurityGroups 'Technicians'

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [pscredential]$Credentials,
        [string]$OTP,
        [string]$DisplayName,
        [Parameter(Mandatory=$True)]
        [string]$Email,
        [string[]]$SecurityGroups = @(),
        [boolean]$ForcePassChange = $true
    )

    $SaveUserArguments = @(
        $script:InternalUserSource,
        $null,
        $Credentials.UserName,
        $Credentials.GetNetworkCredential().Password,
        $Credentials.GetNetworkCredential().Password,
        $OTP,
        $DisplayName,
        '',
        $Email,
        $SecurityGroups,
        $ForcePassChange
    )

    if ($PSCmdlet.ShouldProcess($Credentials.UserName, "New-CWCUser")) {
        Invoke-CWCServiceMethod -Service SecurityService -Method SaveUser -Arguments $SaveUserArguments -Sensitive
    }
}
