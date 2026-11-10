function New-CWCUser {
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