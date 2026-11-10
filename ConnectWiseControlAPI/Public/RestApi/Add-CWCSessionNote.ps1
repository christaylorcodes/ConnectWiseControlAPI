function Add-CWCSessionNote {
    <#
    .SYNOPSIS
        Adds a note to a session.

    .DESCRIPTION
        Queues an AddedNote session event.

        Credentials connections: PageService.AddSessionEvents. The note is attributed to the connected
        user and needs the AddNote permission in -Group.

        API secret connections: the RESTful API Manager extension's AddNoteToSession. The note is
        attributed to the extension's RESTfulUserName setting ("RESTful API" by default); -Group is ignored.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Note
        Note text.

    .PARAMETER Group
        Session group containing the session (credentials connections only). Defaults to 'All Machines'.

    .EXAMPLE
        Add-CWCSessionNote -GUID $SessionID -Note 'Rebooted for patching'

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('SessionID')]
        [guid]$GUID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Note,

        [ValidateNotNullOrEmpty()]
        [string]$Group = 'All Machines'
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$GUID", 'Add note')) { return }

        # Adding an event is not idempotent: never retried
        if (Test-CWCApiSecretConnection) {
            # AddNoteToSession(Guid sessionID, string noteBody)
            Invoke-CWCServiceMethod -RestApi -Method AddNoteToSession -Arguments @($GUID.ToString(), $Note)
        }
        else {
            $NoteEvent = @{
                SessionID = $GUID
                EventType = $script:CWCSessionEventType.AddedNote
                Data      = $Note
            }
            Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), @($NoteEvent))
        }
    }
}
