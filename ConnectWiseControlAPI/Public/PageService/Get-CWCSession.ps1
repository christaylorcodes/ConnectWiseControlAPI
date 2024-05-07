function Get-CWCSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateSet('Support', 'Access', 'Meeting')]
        $Type,
        [string]$Group = 'All Machines',
        [string]$Search,
        [string]$FindSessionID,
        [int]$Limit
    )

    $Endpoint = 'Services/PageService.ashx/GetLiveData'

    switch ($Type) {
        'Support' { $Number = 0 }
        'Meeting' { $Number = 1 }
        'Access' { $Number = 2 }
        default { return Write-Error "Unknown Type, $Type" }
    }

    $Body = ConvertTo-Json @(
        @{
            HostSessionInfo  = @{
                'sessionType'           = $Number
                'sessionGroupPathParts' = @($Group)
                'filter'                = $Search
                'findSessionID'         = $FindSessionID
                'sessionLimit'          = $Limit
            }            
            ActionCenterInfo = @{}
        }
        0
    ) -Depth 5
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body     = $Body
        Method   = 'Post'
    }

    $Data = Invoke-CWCWebRequest -Arguments $WebRequestArguments
    $Data.ResponseInfoMap.HostSessionInfo.Sessions
}
