function Get-CWCSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateSet('Support','Access','Meeting')]
        $Type,
        [string]$Group = $script:defaultGroup,
        [string]$Search,
        [int]$Limit
    )

    $Endpoint = 'Services/PageService.ashx/GetLiveData'

    switch($Type){
        'Support' { $Number = 0 }
        'Meeting' { $Number = 1 }
        'Access' { $Number = 2 }
        default { return Write-Error "Unknown Type, $Type" }
    }

    #$Body = ConvertTo-Json @($Number,@($Group),$Search,$null,$Limit)

    Write-Debug $Group

    $Body = @"
[
    {
        `"HostSessionInfo`": {
            `"sessionType`": 2,
            `"sessionGroupPathParts`": [
                `"$Group`"
            ],
            `"filter`": `"$Search`",
            `"findSessionID`": null,
            `"sessionLimit`": 1000
        },
        `"ActionCenterInfo`": {}
    },
    0
]
"@

    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }

    $Data =  Invoke-CWCWebRequest -Arguments $WebRequestArguments
    $Data.ResponseInfoMap.HostSessionInfo.sessions
    #$Data.sessions
}