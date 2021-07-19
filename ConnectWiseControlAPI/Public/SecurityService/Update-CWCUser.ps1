function Update-CWCUser {
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

    $Endpoint = 'Services/SecurityService.ashx/SaveUser'

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
        '',
        $User.Email,
        $User.RoleNames,
        $False
    )

    if($NewUserName){ $Update[2] = $NewUserName }
    if($Password){
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $Update[3] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        $Update[4] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        Remove-Variable bstr
    }
    if($OTP){ $Update[5] = $OTP }
    if($DisplayName){ $Update[6] = $DisplayName }
    if($Email){ $Update[8] = $Email }
    if($SecurityGroups){ $Update[9] = $SecurityGroups }
    if($ForcePassChange){ $Update[10] = $True }

    $Body = ConvertTo-Json $Update

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Update-CWCUser")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}