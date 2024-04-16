function Remove-CWCAllSessionNotes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$SessionId,
        [string[]]$Group = 'All Machines'
    )

    $sesstionDetails = Get-CWCSessionDetail -GUID $SessionId
    $notes = $sesstionDetails.Events | Where-Object {$_.EventType -eq 32}
    $notes.ForEach({
        Remove-CWCSessionNote -SessionId $SessionId -NoteEventId $_.EventID -Group $Group
    })
}