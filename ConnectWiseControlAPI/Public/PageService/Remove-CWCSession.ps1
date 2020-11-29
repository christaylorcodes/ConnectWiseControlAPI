function Remove-CWCSession
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID,
        [Parameter(Mandatory = $True)]
        [string]$Group
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/AddEventToSessions"

    $SessionEventType = 21
    if ($GUID.count -eq 1)
    {
        $Body = ConvertTo-Json @(@($Group), @($GUID), $SessionEventType, '')
    }
    else
    {
        $Body = ConvertTo-Json @(@($Group), $GUID, $SessionEventType, '')
    }

    $WebRequestArguments = @{
        Uri    = $URI
        Body   = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Remove-CWCSession"))
    {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}