function Invoke-CWCCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [guid]$GUID,
        [string]$Command,
        [int]$TimeOut = 10000,
        [int]$MaxLength = 10000,
        [switch]$PowerShell,
        # Session group name, or the path parts of a nested group
        [string[]]$Group = 'All Machines',
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
        Add-CWCSessionEvent -Group $Group -Entry @{ SessionID = $GUID; EventType = $QueuedCommandEventType; Data = $FormattedCommand }
    }
    if ($NoWait) { return }

    # The extension's GetSessionDetailsBySessionID returns raw SessionDetails (event Time is a DateTime),
    # not PageService's elapsed-milliseconds shape the output polling below depends on.
    if (Test-CWCApiSecretConnection) {
        Write-Warning 'Command queued. Output is not retrieved when connected with -ApiSecret; use -NoWait to suppress this warning.'
        return
    }

    # Poll for the command's output: the first RanCommand event newer than the queued command.
    # Event times are compared on the server's clock (response BaseTime minus elapsed ms), so the
    # round-trip time of each poll doesn't shift them.
    $TimeOutDateTime = (Get-Date).AddMilliseconds($TimeOut).AddSeconds(1)
    $QueuedAtServerMs = $null
    $PollDelaySeconds = 1
    do {
        # Events only, with a growing delay (1, 2, 3 ... 5 s): GetSessionDetails is rate limited.
        try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events' -ErrorAction Stop }
        catch {
            Write-Error $_
            return
        }

        $BaseTime = [double]$SessionDetails.BaseTime

        if ($null -eq $QueuedAtServerMs) {
            # The most recent queued command (smallest elapsed time) is the one just sent
            $QueuedEvent = $SessionDetails.Events | Where-Object { $_.EventType -eq $QueuedCommandEventType } |
                Sort-Object { [double]$_.Time } | Select-Object -First 1
            if ($QueuedEvent) { $QueuedAtServerMs = $BaseTime - [double]$QueuedEvent.Time }
        }

        if ($null -ne $QueuedAtServerMs) {
            $OutputEvent = $SessionDetails.Events | Where-Object {
                $_.EventType -eq $RanCommandEventType -and $null -ne $_.Time -and
                ($BaseTime - [double]$_.Time) -gt $QueuedAtServerMs
            } | Sort-Object { [double]$_.Time } -Descending | Select-Object -First 1
            if ($OutputEvent) {
                Write-Verbose $OutputEvent.Data
                return $OutputEvent.Data -split '[\r\n]' | Where-Object { $_ -and $_ -ne "C:\WINDOWS\system32>$Command" }
            }
        }

        $SecondsLeft = [math]::Ceiling(($TimeOutDateTime - (Get-Date)).TotalSeconds)
        Start-Sleep -Seconds ([math]::Max(0, [math]::Min($PollDelaySeconds, $SecondsLeft)))
        $PollDelaySeconds = [math]::Min($PollDelaySeconds + 1, 5)
    } while ((Get-Date) -le $TimeOutDateTime)

    Write-Warning 'Command timed out.'
}