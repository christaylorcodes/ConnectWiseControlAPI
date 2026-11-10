function Invoke-CWCCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [guid]$GUID,
        [string]$Command,
        [int]$TimeOut = 10000,
        [int]$MaxLength = 10000,
        [switch]$PowerShell,
        [string]$Group = 'All Machines',
        [switch]$NoWait
    )

    $QueuedCommandEventType = $script:CWCSessionEventType.QueuedCommand
    $RanCommandEventType = $script:CWCSessionEventType.RanCommand

    # Format command: directives, then the command; the server expects LF line endings
    $CommandLines = @()
    if ($PowerShell) { $CommandLines += '#!ps' }
    $CommandLines += "#timeout=$TimeOut"
    $CommandLines += "#maxlength=$MaxLength"
    $CommandLines += $Command
    $FormattedCommand = ($CommandLines | Out-String) -replace "`r`n", "`n"

    # Queueing a command is not idempotent, so it is never retried
    if (Test-CWCApiSecretConnection) {
        # RESTful API Manager: SendCommandToSession(Guid sessionID, string command) queues the same
        # QueuedCommand event. Not scoped by group, so -Group is ignored.
        $null = Invoke-CWCServiceMethod -RestApi -Method SendCommandToSession -Arguments @($GUID.ToString(), $FormattedCommand)
    }
    else {
        $CommandEvent = @{
            SessionID = $GUID
            EventType = $QueuedCommandEventType
            Data      = $FormattedCommand
        }
        $null = Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), @($CommandEvent))
    }
    if ($NoWait) { return }

    # The extension's GetSessionDetailsBySessionID returns raw SessionDetails (event Time is a DateTime),
    # not PageService's elapsed-milliseconds shape the output polling below depends on.
    if (Test-CWCApiSecretConnection) {
        Write-Warning 'Command queued. Output is not retrieved when connected with -ApiSecret; use -NoWait to suppress this warning.'
        return
    }

    # Poll for the command's output: the first RanCommand event newer than the queued command.
    $TimeOutDateTime = (Get-Date).AddMilliseconds($TimeOut).AddSeconds(1)
    $QueuedAtUtc = $null
    do {
        # Events only: this polls every second against a rate-limited endpoint.
        try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events' -ErrorAction Stop }
        catch {
            Write-Error $_
            return
        }

        if (-not $QueuedAtUtc) {
            # The most recent queued command (smallest elapsed time) is the one just sent
            $QueuedEvent = $SessionDetails.Events | Where-Object { $_.EventType -eq $QueuedCommandEventType } |
                Sort-Object { [double]$_.Time } | Select-Object -First 1
            if ($QueuedEvent) { $QueuedAtUtc = ConvertFrom-CWCEventTime -SessionEvent $QueuedEvent }
        }

        if ($QueuedAtUtc) {
            $OutputEvent = $SessionDetails.Events | Where-Object {
                $_.EventType -eq $RanCommandEventType -and $_.Time -and
                (ConvertFrom-CWCEventTime -SessionEvent $_) -gt $QueuedAtUtc
            } | Select-Object -First 1
            if ($OutputEvent) {
                Write-Verbose $OutputEvent.Data
                return $OutputEvent.Data -split '[\r\n]' | Where-Object { $_ -and $_ -ne "C:\WINDOWS\system32>$Command" }
            }
        }

        Start-Sleep -Seconds 1
    } while ((Get-Date) -le $TimeOutDateTime)

    Write-Warning 'Command timed out.'
}