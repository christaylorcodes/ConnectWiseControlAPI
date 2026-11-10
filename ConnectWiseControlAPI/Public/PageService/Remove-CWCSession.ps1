function Remove-CWCSession
{
  # ConfirmImpact High: deleting (or uninstalling) sessions is irreversible, and -GUID accepts
  # many IDs at once, so prompt by default.
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param (
    [Parameter(Mandatory = $True)]
    [ValidateScript({ $_ -ne [guid]::Empty })]
    [guid[]]$GUID,
    [Parameter(Mandatory = $True)]
    [string]$Group,
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
      if ($PSCmdlet.ShouldProcess("Session $SessionID (group '$Group')", $Action)) {
        @{
          SessionID = $SessionID
          EventType = $SessionEventType
        }
      }
    }
  )

  if ($EventEntries.Count -eq 0) { return }

  # Not idempotent: never retried
  Invoke-CWCServiceMethod -Service PageService -Method AddSessionEvents -Arguments @(@($Group), $EventEntries)
}
