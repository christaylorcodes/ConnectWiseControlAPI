function Get-CWCSessionGroup {
  [CmdletBinding()]
  param ()

  # Requires the ManageSessionGroups permission on the server.
  Invoke-CWCServiceMethod -Service SessionGroupService -Method GetSessionGroups -Idempotent
}
