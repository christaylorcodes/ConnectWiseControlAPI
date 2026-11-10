function Remove-CWCSessionNote {
    <#
    .SYNOPSIS
        Removes notes from a session.

    .DESCRIPTION
        Deletes notes (AddedNote events) by adding a DeletedEvent correlated to each note, the same way
        the Control web UI removes a note. The user needs the RemoveNote permission in -Group.

        -NoteEventID removes specific notes; -All removes every note still on the session. Notes that
        are already deleted are skipped.

    .PARAMETER GUID
        Session ID.

    .PARAMETER NoteEventID
        Event ID of each note to remove (the EventID of an AddedNote event in Get-CWCSessionDetail).

    .PARAMETER All
        Remove every note on the session.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group.
        Defaults to 'All Machines'.

    .EXAMPLE
        Remove-CWCSessionNote -GUID $SessionID -All

        Removes every note on the session, prompting for each one.

    .EXAMPLE
        $Notes = (Get-CWCSessionDetail -GUID $SessionID -Include Events).Events | Where-Object EventType -eq 32
        $Notes | Where-Object Data -like 'Rebooted*' | ForEach-Object {
            Remove-CWCSessionNote -GUID $SessionID -NoteEventID $_.EventID -Confirm:$false
        }

    .NOTES
        Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot delete notes).
        Based on the design in #27 by CitybookServicesLTD.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory = $True)]
        [Alias('SessionID')]
        [guid]$GUID,

        [Parameter(Mandatory = $True, ParameterSetName = 'ById')]
        [Alias('EventID')]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid[]]$NoteEventID,

        [Parameter(Mandatory = $True, ParameterSetName = 'All')]
        [switch]$All,

        [string[]]$Group = 'All Machines'
    )

    if (Test-CWCApiSecretConnection) {
        return Write-Error "Remove-CWCSessionNote is not available when connected with -ApiSecret (RESTful API Manager). Connect with 'Connect-CWC -Credentials' to use it."
    }

    $NoteType = $script:CWCSessionEventType.AddedNote
    $DeletedType = $script:CWCSessionEventType.DeletedEvent

    $NotesToRemove = @($NoteEventID)
    if ($All) {
        try { $Events = @((Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events' -ErrorAction Stop).Events) }
        catch {
            Write-Error $_
            return
        }
        # A deleted note stays in the event list; its DeletedEvent points back at it
        $AlreadyDeleted = @($Events | Where-Object { $_.EventType -eq $DeletedType } | ForEach-Object { "$($_.CorrelationEventID)" })
        $NotesToRemove = @($Events | Where-Object { $_.EventType -eq $NoteType -and "$($_.EventID)" -notin $AlreadyDeleted } |
            ForEach-Object { [guid]$_.EventID })
        if ($NotesToRemove.Count -eq 0) {
            Write-Verbose "No notes on session $GUID."
            return
        }
    }

    $EventEntries = @(
        foreach ($NoteID in $NotesToRemove) {
            if ($PSCmdlet.ShouldProcess("Note $NoteID on session $GUID", 'Remove note')) {
                @{
                    SessionID          = $GUID
                    EventType          = $DeletedType
                    CorrelationEventID = $NoteID
                }
            }
        }
    )
    if ($EventEntries.Count -eq 0) { return }

    # Not idempotent: never retried
    $null = Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), $EventEntries)
}
