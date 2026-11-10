function Send-CWCSessionMessage {
    <#
    .SYNOPSIS
        Sends a chat message to a session's guest.

    .DESCRIPTION
        Queues a QueuedMessage session event.

        Credentials connections: PageService.AddSessionEvents. The guest sees the connected user's
        display name as the sender (-From is not supported) and the user needs the matching permission
        in -Group.

        API secret connections: the RESTful API Manager extension's SendMessageToSession. The guest sees
        -From as the sender; -Group is ignored.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Message
        Message text.

    .PARAMETER From
        Sender name shown to the guest (API secret connections only).

    .PARAMETER Group
        Session group containing the session (credentials connections only). Defaults to 'All Machines'.

    .EXAMPLE
        Send-CWCSessionMessage -GUID $SessionID -Message 'Your computer will restart in 5 minutes.'

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
        [string]$Message,

        [ValidateNotNullOrEmpty()]
        [string]$From = 'RESTful API',

        [ValidateNotNullOrEmpty()]
        [string]$Group = 'All Machines'
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$GUID", 'Send message')) { return }

        # Adding an event is not idempotent: never retried
        if (Test-CWCApiSecretConnection) {
            # SendMessageToSession(Guid sessionID, string byHost, string message)
            Invoke-CWCServiceMethod -RestApi -Method SendMessageToSession -Arguments @($GUID.ToString(), $From, $Message)
        }
        else {
            # The server sets the sender to the connected user's display name.
            if ($PSBoundParameters.ContainsKey('From')) {
                Write-Warning '-From is only used with -ApiSecret connections; the guest sees the connected user as the sender.'
            }
            $MessageEvent = @{
                SessionID = $GUID
                EventType = $script:CWCSessionEventType.QueuedMessage
                Data      = $Message
            }
            Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), @($MessageEvent))
        }
    }
}
