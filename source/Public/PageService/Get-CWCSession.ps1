function Get-CWCSession {
    <#
    .SYNOPSIS
        Lists sessions of one type in a session group.

    .DESCRIPTION
        Calls PageService.GetLiveData, the same query the web UI's session list uses.

    .PARAMETER Type
        Session type: Support, Access or Meeting.

    .PARAMETER Group
        Session group: a name, or the path parts of a nested group (e.g. 'Clients','Acme'). Defaults to
        the built-in group for -Type: 'All Machines' (Access), 'All Sessions' (Support) or
        'All Meetings' (Meeting).

    .PARAMETER Search
        Filter text, as typed in the web UI's search box.

    .PARAMETER FindSessionID
        Session ID to locate, so it is included even when -Limit would cut it off.

    .PARAMETER Limit
        Maximum number of sessions to return.

    .EXAMPLE
        Get-CWCSession -Type Access -Search 'DESKTOP-01' -Limit 1

        Returns the first Access session that matches DESKTOP-01. Its SessionID is the -GUID the other
        session commands take.

    .NOTES
        Requires Connect-CWC -Credentials.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateSet('Support', 'Access', 'Meeting')]
        $Type,
        [string[]]$Group,
        [string]$Search,
        [string]$FindSessionID,
        [int]$Limit
    )

    if (-not $Group) { $Group = $script:CWCDefaultSessionGroup[$Type] }

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
