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
    $SessionEventType = $script:CWCSessionEventType.QueuedWake

    if ($Type -eq 'Support') { $Group = 'All Sessions' }
    else { $Group = 'All Machines' }

    $EventEntries = @(
        foreach ($SessionID in $GUID) {
            @{
                SessionID = $SessionID
                EventType = $SessionEventType
            }
        }
    )

    Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), $EventEntries)
}
