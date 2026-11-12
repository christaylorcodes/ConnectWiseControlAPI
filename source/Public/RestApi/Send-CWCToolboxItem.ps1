function Send-CWCToolboxItem {
    <#
    .SYNOPSIS
        Queues a Toolbox item to run on a session.

    .DESCRIPTION
        Queues a QueuedTool session event naming the Toolbox item. -Elevated queues a QueuedElevatedTool
        event instead, which runs the item with administrative privileges; -Silent queues a
        QueuedSilentElevatedTool event, which runs it elevated and silently.

        The machine opens the item the way Windows opens a file, so use a file type that runs when opened
        (.exe, .msi, .cmd, .bat): a .ps1 opens in its default program instead of running.

        Credentials connections: PageService.AddSessionEvents; the user needs the RunSharedTool
        permission in -Group.

        API secret connections: the RESTful API Manager extension's SendToolboxItemToSession. The event
        is attributed to the extension's RESTfulUserName setting ("RESTful API" unless renamed); -Group
        is ignored. -Elevated and -Silent are not available: the extension only queues the standard event.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Name
        Toolbox item name as shown in the ScreenConnect Toolbox. For an item in a folder, the Path that
        Get-CWCToolbox returns.

    .PARAMETER Elevated
        Run the item with administrative privileges (QueuedElevatedTool). Credentials connections only.

    .PARAMETER Silent
        Run the item elevated and silently (QueuedSilentElevatedTool): it runs as NT AUTHORITY\SYSTEM
        (seen live, 2026-11-11). Implies -Elevated. Credentials connections only.

    .PARAMETER Group
        Session group containing the session (credentials connections only). Defaults to 'All Machines'.

    .EXAMPLE
        Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.cmd'

    .EXAMPLE
        Send-CWCToolboxItem -GUID $SessionID -Name 'Installers/Setup.exe' -Elevated

    .EXAMPLE
        Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.cmd' -Silent

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
        [string[]]$Group = 'All Machines',

        [switch]$Elevated,

        [switch]$Silent
    )

    process {
        if (($Elevated -or $Silent) -and (Test-CWCApiSecretConnection)) {
            $Message = @(
                "$($MyInvocation.MyCommand.Name) -Elevated and -Silent are not available when connected with"
                '-ApiSecret (the RESTful API Manager only queues the standard event).'
                "Connect with 'Connect-CWC -Credentials'."
            ) -join ' '
            return Write-Error $Message -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
        }

        $EventType = $script:CWCSessionEventType.QueuedTool
        $Action = "Run toolbox item '$Name'"
        if ($Silent) {
            $EventType = $script:CWCSessionEventType.QueuedSilentElevatedTool
            $Action = "Run toolbox item '$Name' elevated and silent"
        } elseif ($Elevated) {
            $EventType = $script:CWCSessionEventType.QueuedElevatedTool
            $Action = "Run toolbox item '$Name' elevated"
        }
        if (-not $PSCmdlet.ShouldProcess("$GUID", $Action)) { return }

        # Adding an event is not idempotent: never retried
        if (Test-CWCApiSecretConnection) {
            # SendToolboxItemToSession(Guid sessionID, string toolboxItemName)
            $null = Invoke-CWCServiceMethod -RestApi -Method SendToolboxItemToSession -Arguments @($GUID.ToString(), $Name)
        }
        else {
            Add-CWCSessionEvent -Group $Group -Entry @{ SessionID = $GUID; EventType = $EventType; Data = $Name }
        }
    }
}
