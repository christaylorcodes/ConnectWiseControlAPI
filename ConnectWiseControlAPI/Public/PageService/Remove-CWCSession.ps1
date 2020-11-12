function Remove-CWCSession {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$True)]
        [guid[]]$GUID,
        [Parameter(Mandatory=$True)]
        [ValidateSet('Access','Meeting','Support')]
        $Type
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/AddEventToSessions"

    switch($Type){
        'Support'   {$Group = 'All Sessions'}
        'Access'    {$Group = 'All Machines'}
        default     {return Write-Error "Unknown Type, $Type"}
    }

    $SessionEventType = 21
    if($GUID.count -eq 1){
        $Body = ConvertTo-Json @(@($Group),@($GUID),$SessionEventType,'')
    }
    else {
        $Body = ConvertTo-Json @(@($Group),$GUID,$SessionEventType,'')
    }

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Remove-CWCSession")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}