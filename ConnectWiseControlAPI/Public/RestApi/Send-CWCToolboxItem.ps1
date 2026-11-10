function Send-CWCToolboxItem {
    <#
    .SYNOPSIS
        Queues a Toolbox item to run on a session.

    .DESCRIPTION
        Queues a QueuedTool session event naming the Toolbox item.

        Credentials connections: PageService.AddSessionEvents; the user needs the RunSharedTool
        permission in -Group.

        API secret connections: the RESTful API Manager extension's SendToolboxItemToSession. The event
        is attributed to the extension's RESTfulUserName setting ("RESTful API" unless renamed); -Group
        is ignored.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Name
        Toolbox item name as shown in the Control Toolbox.

    .PARAMETER Group
        Session group containing the session (credentials connections only). Defaults to 'All Machines'.

    .EXAMPLE
        Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.ps1'

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
        [string]$Name,

        [ValidateNotNullOrEmpty()]
        [string[]]$Group = 'All Machines'
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$GUID", "Run toolbox item '$Name'")) { return }

        # Adding an event is not idempotent: never retried
        if (Test-CWCApiSecretConnection) {
            # SendToolboxItemToSession(Guid sessionID, string toolboxItemName)
            $null = Invoke-CWCServiceMethod -RestApi -Method SendToolboxItemToSession -Arguments @($GUID.ToString(), $Name)
        }
        else {
            Add-CWCSessionEvent -Group $Group -Entry @{ SessionID = $GUID; EventType = $script:CWCSessionEventType.QueuedTool; Data = $Name }
        }
    }
}
