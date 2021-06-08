function Get-CWCSecurityConfigurationInfo {
    [CmdletBinding()]
    param ()

    $Endpoint = 'Services/SecurityService.ashx/GetSecurityConfigurationInfo'

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Method = 'Post'
    }
    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}