function Update-CWCSessionName {
    <#
    .SYNOPSIS
        Renames a session.

    .DESCRIPTION
        Credentials connections: PageService.UpdateSessionName. API secret connections: the RESTful API
        Manager extension's UpdateSessionName (-Group is ignored).

    .PARAMETER GUID
        Session ID.

    .PARAMETER NewName
        New session name.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .EXAMPLE
        Update-CWCSessionName -GUID $SessionID -NewName 'ACME-FrontDesk'

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [string]$NewName,
        # Session group name, or the path parts of a nested group
        [string[]]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Rename to '$NewName'")) {
        # Sets a value, so it is safe to retry
        if (Test-CWCApiSecretConnection) {
            # RESTful API Manager: UpdateSessionName(Guid sessionID, string newName). -Group is ignored.
            Invoke-CWCServiceMethod -RestApi -Method UpdateSessionName -Arguments @($GUID.ToString(), $NewName) -Idempotent
        }
        else {
            Invoke-CWCServiceMethod -Service PageService -Method UpdateSessionName -Arguments @(@($Group), $GUID, $NewName) -Idempotent
        }
    }
}
