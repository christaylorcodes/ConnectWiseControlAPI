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

    # GetLiveData(requestInfoMap, version)
    $RequestInfoMap = @{
        HostSessionInfo  = @{
            'sessionType'           = $script:CWCSessionType[$Type]
            'sessionGroupPathParts' = @($Group)
            'filter'                = $Search
            'findSessionID'         = $FindSessionID
            'sessionLimit'          = $Limit
        }
        ActionCenterInfo = @{}
    }

    $Data = Invoke-CWCServiceMethod -Service PageService -Method GetLiveData -Arguments @($RequestInfoMap, 0) -Idempotent
    $Data.ResponseInfoMap.HostSessionInfo.Sessions
}
