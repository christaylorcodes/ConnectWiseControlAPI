function Invoke-CWCWake {
    <#
    .SYNOPSIS
        Sends a wake (Wake-on-LAN) request to sessions.

    .DESCRIPTION
        Queues a QueuedWake event (43) for each session, in the built-in group for -Type.

    .PARAMETER GUID
        One or more session IDs.

    .PARAMETER Type
        Session type: Support or Access.

    .EXAMPLE
        Invoke-CWCWake -GUID $SessionID -Type Access

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
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
