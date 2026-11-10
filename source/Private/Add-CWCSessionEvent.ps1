function Add-CWCSessionEvent {
    <#
    .SYNOPSIS
        Adds session events through PageService.AddSessionEvents. Every event-queuing function uses this.

    .DESCRIPTION
        Server signature: AddSessionEvents(object sessionGroupPathPartsOrName, SessionEventEntry[] eventEntries),
        SessionEventEntry = SessionID, EventType, Data, CorrelationEventID, ConnectionID. Each entry is
        sent as given (only the keys it has). Nothing is sent when no entries are passed (e.g. every
        ShouldProcess prompt was declined). Adding an event is not idempotent (a second command, note,
        wake or delete), so the call is never retried.

    .PARAMETER Group
        Session group name, or the path parts of a nested group.

    .PARAMETER Entry
        One hashtable per event.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Callers confirm each event with ShouldProcess.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string[]]$Group,

        [AllowEmptyCollection()]
        [hashtable[]]$Entry
    )

    if (@($Entry).Count -eq 0) { return }
    $null = Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), @($Entry))
}
