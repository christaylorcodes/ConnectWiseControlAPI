function Remove-CWCSessionNote {
    <#
    .SYNOPSIS
        Removes notes from a session.

    .DESCRIPTION
        Deletes notes (AddedNote events) by adding a DeletedEvent correlated to each note, the same way
        the ScreenConnect web UI removes a note. The user needs the RemoveNote permission in -Group.

        -NoteEventID removes the given notes (without checking them first). -All reads the session and
        removes every note still on it, skipping notes that are already deleted.

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
    # ConfirmImpact High: removed notes can't be restored, and -All can remove many at once
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
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

    # Checked up front: with -All, the read below would otherwise succeed through the extension first.
    if (Test-CWCApiSecretConnection) {
        return Write-Error (Get-CWCAuthModeMessage -Command $MyInvocation.MyCommand.Name -Required Credentials) -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
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
                @{ SessionID = $GUID; EventType = $DeletedType; CorrelationEventID = $NoteID }
            }
        }
    )
    Add-CWCSessionEvent -Group $Group -Entry $EventEntries
}
