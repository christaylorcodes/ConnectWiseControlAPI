function Get-CWCSecurityConfigurationInfo {
    [CmdletBinding()]
    param ()

    $URI = "https://$($script:CWCServerConnection.Server)/Services/SecurityService.ashx/GetSecurityConfigurationInfo"

    $WebRequestArguments = @{
        Uri = $URI
        Method = 'Post'
    }
    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}