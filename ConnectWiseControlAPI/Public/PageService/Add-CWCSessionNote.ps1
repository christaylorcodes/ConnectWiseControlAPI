function Add-CWCSessionNote {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$SessionId,
        [Parameter(Mandatory=$True)]
        [string]$Note,
        [string[]]$Group = 'All Machines'
    )

    $Endpoint = 'Services/PageService.ashx/AddSessionEvents'

    $params = @{
        SessionID = $SessionId
        EventType = 32
        Data = $Note
    }
    $Body = ConvertTo-Json @($Group,@($params))

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    $Data =  Invoke-CWCWebRequest -Arguments $WebRequestArguments
}