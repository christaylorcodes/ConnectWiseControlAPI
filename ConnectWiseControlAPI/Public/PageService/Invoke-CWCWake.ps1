function Invoke-CWCWake {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [guid[]]$GUID,
        [Parameter(Mandatory=$True)]
        [ValidateSet('Support','Access')]
        [string]$Type
    )

    $Endpoint = 'Services/PageService.ashx/AddEventToSessions'

    $SessionEventType = 43

    switch($Type){
        'Support' { $Group = 'All Sessions' }
        'Access' { $Group = 'All Machines' }
        default { return Write-Error "Unknown Type, $Type" }
    }

    $Body = ConvertTo-Json @($Group,@($GUID),$SessionEventType,'')
    Write-Verbose $Body

    # Issue command
    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}