function Remove-CWCSessionNote {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$SessionId,
        [guid]$NoteEventId,
        [string[]]$Group = 'All Machines'
    )

    $Endpoint = 'Services/PageService.ashx/AddSessionEvents'

    $params = @{
        SessionID = $SessionId
        EventType = 1
        CorrelationEventID = $NoteEventId
    }
    $Body = ConvertTo-Json @($Group,@($params))
    Write-Host $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    $Data =  Invoke-CWCWebRequest -Arguments $WebRequestArguments

}