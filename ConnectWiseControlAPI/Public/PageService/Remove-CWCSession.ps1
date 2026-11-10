function Remove-CWCSession
{
    <#
    .SYNOPSIS
        Deletes sessions, optionally uninstalling the Access client first.

    .DESCRIPTION
        Queues a DeletedSession event (21) per session, or QueuedUninstallAndDelete (100) with -Uninstall.
        Prompts for each session by default (ConfirmImpact High); use -Confirm:$false in unattended scripts.

    .PARAMETER GUID
        One or more session IDs.

    .PARAMETER Group
        Session group containing the sessions: a name, or the path parts of a nested group.

    .PARAMETER Uninstall
        Uninstall the Access client from the machine and delete the session, instead of only deleting the
        session record.

    .EXAMPLE
        Remove-CWCSession -GUID $SessionID -Group 'All Machines' -Uninstall -Confirm:$false

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
  # ConfirmImpact High: deleting (or uninstalling) sessions is irreversible, and -GUID accepts
  # many IDs at once, so prompt by default.
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param (
    [Parameter(Mandatory = $True)]
    [ValidateScript({ $_ -ne [guid]::Empty })]
    [guid[]]$GUID,
    # Session group name, or the path parts of a nested group
    [Parameter(Mandatory = $True)]
    [string[]]$Group,
    # Queue an uninstall of the Access client and delete the session (QueuedUninstallAndDelete),
    # instead of only deleting the session record (DeletedSession).
    [switch]$Uninstall
  )

  if ($Uninstall) {
    $SessionEventType = $script:CWCSessionEventType.QueuedUninstallAndDelete
    $Action = 'Uninstall client and delete session'
  }
  else {
    $SessionEventType = $script:CWCSessionEventType.DeletedSession
    $Action = 'Delete session'
  }

  # Confirm each session individually (readable -WhatIf/-Confirm target), then send one
  # SessionEventEntry per approved session in a single request.
  $EventEntries = @(
    foreach ($SessionID in $GUID) {
      if ($PSCmdlet.ShouldProcess("Session $SessionID (group '$($Group -join '/')')", $Action)) {
        @{ SessionID = $SessionID; EventType = $SessionEventType }
      }
    }
  )
  Add-CWCSessionEvent -Group $Group -Entry $EventEntries
}
