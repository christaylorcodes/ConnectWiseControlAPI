function Invoke-CWCWake {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [guid[]]$GUID,
        [Parameter(Mandatory=$True)]
        [ValidateSet('Support','Access')]
        [string]$Type
    )

    # PageService.AddEventToSessions no longer exists on the server; wake is queued as a session event.
    $EventEntries = @(
        foreach ($SessionID in $GUID) {
            @{ SessionID = $SessionID; EventType = $script:CWCSessionEventType.QueuedWake }
        }
    )
    Add-CWCSessionEvent -Group $script:CWCDefaultSessionGroup[$Type] -Entry $EventEntries
}
