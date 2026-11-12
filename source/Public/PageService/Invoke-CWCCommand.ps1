function Invoke-CWCCommand {
    <#
    .SYNOPSIS
        Runs a command on a session's machine and returns its output.

    .DESCRIPTION
        Queues a QueuedCommand event (44) and polls the session's events until the matching RanCommand
        output (70) arrives or -TimeOut passes.

        API secret connections queue the command through the RESTful API Manager extension; the output is
        not retrieved (a warning says so unless -NoWait is used).

    .PARAMETER GUID
        Session ID.

    .PARAMETER Command
        Command line to run (cmd.exe unless -PowerShell is used).

    .PARAMETER TimeOut
        Milliseconds the command may run, and how long to wait for its output. Defaults to 10000.

    .PARAMETER MaxLength
        Maximum number of characters of output to return. Defaults to 10000.

    .PARAMETER PowerShell
        Run the command in PowerShell.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .PARAMETER NoWait
        Queue the command and return without waiting for output.

    .EXAMPLE
        Invoke-CWCCommand -GUID $SessionID -Command 'hostname'

        Runs hostname in cmd.exe on the machine and returns its output.

    .EXAMPLE
        Invoke-CWCCommand -GUID $SessionID -Command 'Get-Service Spooler' -PowerShell -TimeOut 30000

        Runs a PowerShell command and waits up to 30 seconds for its output.

    .OUTPUTS
        The output of the command, as text. Nothing with -NoWait or on an API secret connection.

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
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
    try {
        if (Test-CWCApiSecretConnection) {
            # RESTful API Manager: SendCommandToSession(Guid sessionID, string command) queues the same
            # QueuedCommand event. Not scoped by group, so -Group is ignored.
            $null = Invoke-CWCServiceMethod -RestApi -Method SendCommandToSession -Arguments @($GUID.ToString(), $FormattedCommand) -ErrorAction Stop
        }
        else {
            Add-CWCSessionEvent -Group $Group -Entry @{ SessionID = $GUID; EventType = $QueuedCommandEventType; Data = $FormattedCommand } -ErrorAction Stop
        }
    }
    catch {
        # Not queued: don't report success or poll for output that will never come.
        # WriteError keeps the ErrorId (CWC.*) on Windows PowerShell 5.1; Write-Error $_ replaces it there.
        $PSCmdlet.WriteError($_)
        return
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
    $QueuedEventID = $null
    $PollDelaySeconds = 1
    do {
        # Events only, with a growing delay (1, 2, 3 ... 5 s): GetSessionDetails is rate limited.
        try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events' -ErrorAction Stop }
        catch {
            $PSCmdlet.WriteError($_)
            return
        }

        $BaseTime = [double]$SessionDetails.BaseTime

        if ($null -eq $QueuedAtServerMs) {
            # Our queued command: the most recent (smallest elapsed time) whose text is exactly what we
            # sent, so a command queued by someone else at the same time isn't taken for ours.
            $QueuedEvent = $SessionDetails.Events | Where-Object {
                $_.EventType -eq $QueuedCommandEventType -and "$($_.Data)" -eq $FormattedCommand
            } | Sort-Object { [double]$_.Time } | Select-Object -First 1
            if ($QueuedEvent) {
                $QueuedAtServerMs = $BaseTime - [double]$QueuedEvent.Time
                $QueuedEventID = "$($QueuedEvent.EventID)"
            }
        }

        if ($null -ne $QueuedAtServerMs) {
            $RanEvents = @($SessionDetails.Events | Where-Object { $_.EventType -eq $RanCommandEventType -and $null -ne $_.Time })
            # Output that names our command (CorrelationEventID) wins; otherwise the first output after it.
            $OutputEvent = $RanEvents | Where-Object { $QueuedEventID -and "$($_.CorrelationEventID)" -eq $QueuedEventID } |
                Select-Object -First 1
            if (-not $OutputEvent) {
                $OutputEvent = $RanEvents | Where-Object { ($BaseTime - [double]$_.Time) -gt $QueuedAtServerMs } |
                    Sort-Object { [double]$_.Time } -Descending | Select-Object -First 1
            }
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
