function New-CWCUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [pscredential]$Credentials,
        [string]$OTP,
        [string]$DisplayName,
        [string]$Email,
        [string[]]$SecurityGroups,
        [boolean]$ForcePassChange = $true
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/SecurityService.ashx/SaveUser"

    $Body = ConvertTo-Json -Depth 10 @(
        'XmlMembershipProvider',
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
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "New-CWCUser")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}