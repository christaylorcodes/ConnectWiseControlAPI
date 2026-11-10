function Get-CWCSessionDetail {
    [CmdletBinding()]
    param (
        [string]$Group = 'All Machines',
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
    $DetailArguments = @($Group, $GUID)
    if ($Include) {
        $Items = 0
        foreach ($Item in ($Include | Select-Object -Unique)) { $Items = $Items -bor $SessionDetailsItemFlags[$Item] }
        $DetailArguments += $Items
    }

    Invoke-CWCServiceMethod -Service PageService -Method GetSessionDetails -Arguments $DetailArguments -Idempotent
}