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

    $Endpoint = 'Services/SecurityService.ashx/SaveUser'

    $Body = ConvertTo-Json @(
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

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "New-CWCUser")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}