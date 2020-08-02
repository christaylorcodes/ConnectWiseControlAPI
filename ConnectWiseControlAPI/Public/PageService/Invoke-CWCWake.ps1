function Invoke-CWCWake {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [guid[]]$GUID,
        [Parameter(Mandatory=$True)]
        [ValidateSet('Support','Access')]
        [string]$Type
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/AddEventToSessions"

    switch($Type){
        'Support'   {$Group = 'All Sessions'}
        'Access'    {$Group = 'All Machines'}
        default     {Write-Error "Unknown Type, $Type";return}
    }

    $SessionEventType = 43

    if($GUID.count -eq 1){
        $Body = ConvertTo-Json @($Group,@($GUID),$SessionEventType,'')
    }
    else {
        $Body = ConvertTo-Json @($Group,$GUID,$SessionEventType,'')
    }
    Write-Verbose $Body


    # Issue command
    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}