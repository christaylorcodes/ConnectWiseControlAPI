function Get-CWCSessionGroup {
    <#
    .SYNOPSIS
        Returns all session groups.

    .DESCRIPTION
        Calls SessionGroupService.GetSessionGroups. Requires the ManageSessionGroups permission.

    .EXAMPLE
        Get-CWCSessionGroup | Select-Object Name, SessionType

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
  [CmdletBinding()]
  param ()

  # Requires the ManageSessionGroups permission on the server.
  Invoke-CWCServiceMethod -Service SessionGroupService -Method GetSessionGroups -Idempotent
}
