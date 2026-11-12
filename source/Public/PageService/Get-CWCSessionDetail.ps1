function Get-CWCSessionDetail {
    <#
    .SYNOPSIS
        Returns the details of a session: session info, events, connections and guest screenshot.

    .DESCRIPTION
        Credentials connections: PageService.GetSessionDetails. Event Time values are milliseconds elapsed
        since the event, relative to the response's BaseTime. The call is rate limited by the server.

        API secret connections: the RESTful API Manager extension's GetSessionDetailsBySessionID, which
        returns the server's raw session details; -Group and -Include are ignored.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Include
        Parts to return: SessionInfo, GuestScreenshotContent, Events, Connections. Omit for everything,
        including the guest screenshot. Request only what you need when polling. Ignored on API secret
        connections.

    .EXAMPLE
        (Get-CWCSessionDetail -GUID $SessionID -Include Events).Events | Where-Object EventType -eq 32

        Returns the note events of the session (event type 32 is AddedNote), without downloading the
        screenshot. A deleted note stays in the list; a later event whose CorrelationEventID is the note's
        EventID marks it as deleted.

    .OUTPUTS
        The session details object the server returns.

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param (
        # Session group name, or the path parts of a nested group (e.g. 'Clients','Acme')
        [string[]]$Group = 'All Machines',
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        # Parts of the session details to return (server SessionDetailsItems flags). Omit for everything.
        # Polling callers should request only what they need: GetSessionDetails is rate limited and
        # 'All' includes the guest screenshot.
        [ValidateSet('SessionInfo', 'GuestScreenshotContent', 'Events', 'Connections')]
        [string[]]$Include
    )

    # SessionDetailsItems flag values, read from SC.types.SessionDetailsItems in the web client.
    $SessionDetailsItemFlags = @{
        SessionInfo            = 1
        GuestScreenshotContent = 4
        Events                 = 8
        Connections            = 16
    }

    if (Test-CWCApiSecretConnection) {
        # RESTful API Manager: GetSessionDetailsBySessionID(Guid). Not scoped by group, so -Group and
        # -Include are ignored.
        return Invoke-CWCServiceMethod -RestApi -Method GetSessionDetailsBySessionID -Arguments $GUID.ToString() -Idempotent
    }

    # GetSessionDetails(group, sessionID[, items]). Without items the server returns All.
    $DetailArguments = @(@($Group), $GUID)
    if ($Include) {
        $Items = 0
        foreach ($Item in ($Include | Select-Object -Unique)) { $Items = $Items -bor $SessionDetailsItemFlags[$Item] }
        $DetailArguments += $Items
    }

    Invoke-CWCServiceMethod -Service PageService -Method GetSessionDetails -Arguments $DetailArguments -Idempotent
}
