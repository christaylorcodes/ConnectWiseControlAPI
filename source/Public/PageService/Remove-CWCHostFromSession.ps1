function Remove-CWCHostFromSession {
    <#
    .SYNOPSIS
        Disconnects one connection (for example a host) from a session.

    .DESCRIPTION
        Queues a QueuedForceDisconnect session event (type 48) for the given connection, the same
        action as disconnecting a participant in the ScreenConnect web UI. Connection IDs are listed in
        (Get-CWCSessionDetail -GUID <session> -Include Connections).Connections.

    .PARAMETER SessionID
        Session ID.

    .PARAMETER ConnectionID
        ID of the connection to disconnect.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group.

    .EXAMPLE
        $Connections = (Get-CWCSessionDetail -GUID $SessionID -Include Connections).Connections
        $HostConnection = $Connections | Where-Object { $_.ProcessType -eq 1 } | Select-Object -First 1
        Remove-CWCHostFromSession -SessionID $SessionID -ConnectionID $HostConnection.ConnectionID -Group 'All Machines'

        Disconnects the first host connected to the session (ProcessType 1 = Host).

    .NOTES
        Contributed by turbo-donkey (#28).
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$SessionID,

        [Parameter(Mandatory = $True)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$ConnectionID,

        [Parameter(Mandatory = $True)]
        [string[]]$Group
    )

    if (-not $PSCmdlet.ShouldProcess("Connection $ConnectionID in session $SessionID", 'Force disconnect')) { return }

    Add-CWCSessionEvent -Group $Group -Entry @{
        SessionID    = $SessionID
        EventType    = $script:CWCSessionEventType.QueuedForceDisconnect
        ConnectionID = $ConnectionID
    }
}
