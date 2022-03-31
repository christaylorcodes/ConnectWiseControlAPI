function Get-CWCAuditInfo {
    [CmdletBinding()]
    param ()

    $Endpoint = 'Services/AuditService.ashx/GetAuditInfo'

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Method   = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}
