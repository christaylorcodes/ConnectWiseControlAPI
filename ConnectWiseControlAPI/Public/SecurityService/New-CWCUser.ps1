function New-CWCUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [SecureString]$Password,
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
        $UserName,
        $Password,
        $Password,
        $OTP,
        $DisplayName,
        '',
        $Email,
        $SecurityGroups,
        $ForcePassChange
    )
    Write-Verbose $Body


    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "New-CWCUser")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}