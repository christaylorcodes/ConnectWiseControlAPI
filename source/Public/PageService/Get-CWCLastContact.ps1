function Get-CWCLastContact {
    <#
    .SYNOPSIS
        Returns when a machine was last connected, or whether it connected recently.

    .DESCRIPTION
        Reads the session's connect/disconnect events. Returns the current time if the guest is connected
        now, otherwise the time of its last disconnect. With -Quiet, returns $True when the guest is
        connected or was connected within -Seconds, else $False.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Quiet
        Return $True or $False instead of a date.

    .PARAMETER Seconds
        Used with -Quiet: how recent the last contact must be to count.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .EXAMPLE
        Get-CWCLastContact -GUID $SessionID -Quiet -Seconds 300

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    [OutputType([boolean], ParameterSetName = ('Quiet'))]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $True)]
        [guid]$GUID,
        [parameter(ParameterSetName = 'Quiet')]
        [switch]$Quiet,
        [int]$Seconds,
        # Session group name, or the path parts of a nested group
        [string[]]$Group = 'All Machines'
    )

    # Relies on PageService's elapsed-milliseconds event times; the RESTful API Manager returns raw DateTimes.
    if (Test-CWCApiSecretConnection) {
        return Write-Error (Get-CWCAuthModeMessage -Command $MyInvocation.MyCommand.Name -Required Credentials) -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
    }

    try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events' -ErrorAction Stop }
    catch {
        # WriteError keeps the ErrorId (CWC.*) on Windows PowerShell 5.1; Write-Error $_ replaces it there
        $PSCmdlet.WriteError($_)
        return
    }

    if (-not $SessionDetails) {
        Write-Warning 'Machine not found.'
        return $null
    }

    # The guest's latest connect/disconnect event. Guest events have no Host; a technician's carry their
    # name, so a technician joining or leaving doesn't count as the machine's last contact.
    $LatestEvent = $SessionDetails.Events | Where-Object {
        $_.EventType -in ($script:CWCSessionEventType.Connected, $script:CWCSessionEventType.Disconnected) -and -not $_.Host
    } | Sort-Object { [double]$_.Time } | Select-Object -First 1
    if (-not $LatestEvent) { return Write-Error 'Unable to determine last contact.' }

    if ($LatestEvent.EventType -eq $script:CWCSessionEventType.Connected) {
        # Currently connected
        if ($Quiet) { return $True }
        return Get-Date
    }

    # Event Time is milliseconds elapsed since the event
    $ElapsedMs = [double]$LatestEvent.Time
    if ($Quiet) { return ($ElapsedMs / 1000) -lt $Seconds }
    (Get-Date).AddMilliseconds(-$ElapsedMs)
}
