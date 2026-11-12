function Send-CWCToolboxItem {
    <#
    .SYNOPSIS
        Queues a Toolbox item to run on a session.

    .DESCRIPTION
        Queues a QueuedTool session event naming the Toolbox item. -Elevated queues a QueuedElevatedTool
        event instead, which runs the item with administrative privileges; -Silent queues a
        QueuedSilentElevatedTool event, which runs it elevated and silently.

        -Elevated and -Silent ask for confirmation, like the Remove-* commands: the item runs with
        administrative rights, and with -Silent nobody at the machine sees it. Pass -Confirm:$false in
        unattended scripts.

        For an unattended run use -Silent. With -Elevated the server queued the event, but the item did not
        start on a machine that had no host connected (seen live, 2026-11-12).

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

        Asks for confirmation, then runs the item with administrative privileges.

    .EXAMPLE
        Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.cmd' -Silent -Confirm:$false

        Runs the item elevated and silently, without asking.

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
        # An elevated run is treated as high impact, a standard run is not. The command's impact is Medium,
        # so lowering the default preference (High) to Medium makes ShouldProcess ask. -Confirm:$false and a
        # session-wide (global) $ConfirmPreference arrive here as other values and are left alone. As with
        # every module command, a preference set only in the caller's script scope is not seen: use -Confirm.
        if (($Silent -or $Elevated) -and $ConfirmPreference -eq 'High') { $ConfirmPreference = 'Medium' }
        # A prompt that cannot be shown throws: the assignment then never happens and nothing is sent
        $Proceed = $False
        $Proceed = $PSCmdlet.ShouldProcess("$GUID", $Action)
        if (-not $Proceed) { return }

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
