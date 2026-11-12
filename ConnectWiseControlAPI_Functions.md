---
Module Name: ConnectWiseControlAPI
Module Guid: f94fa996-0f01-4c5c-9cd9-3227728ebacb
Download Help Link: https://github.com/christaylorcodes/ConnectWiseControlAPI/blob/master/ConnectWiseControlAPI_Functions.md
Help Version: 0.5.0
Locale: en-US
---

# ConnectWiseControlAPI Module
## Description
PowerShell commands for the ConnectWise ScreenConnect (formerly ConnectWise Control) web API. Connect-CWC signs in; `Get-Help about_ConnectWiseControlAPI` gives an overview.

## ConnectWiseControlAPI Cmdlets
### [Add-CWCRemoteWorkforceRequiredRole](Docs/Add-CWCRemoteWorkforceRequiredRole.md)
Creates the security role required by the Remote Workforce extension.

### [Add-CWCSessionNote](Docs/Add-CWCSessionNote.md)
Adds a note to a session.

### [Connect-CWC](Docs/Connect-CWC.md)
Connects to a ConnectWise ScreenConnect server.

### [Enter-CWCSession](Docs/Enter-CWCSession.md)
Opens the ConnectWise ScreenConnect Host client joined to a session, like Join in the web UI.

### [Find-CWCSession](Docs/Find-CWCSession.md)
Finds sessions by session filter expression, name or ID (API secret connections).

### [Get-CWCAuditInfo](Docs/Get-CWCAuditInfo.md)
Shows the current audit settings.

### [Get-CWCAuditLog](Docs/Get-CWCAuditLog.md)
Returns audit log entries for a time range.

### [Get-CWCLastContact](Docs/Get-CWCLastContact.md)
Returns when a machine was last connected, or whether it connected recently.

### [Get-CWCLauncURL](Docs/Get-CWCLauncURL.md)
DEPRECATED.
Use Get-CWCRemoteWorkforceLaunchURL.

### [Get-CWCRemoteWorkforceLaunchURL](Docs/Get-CWCRemoteWorkforceLaunchURL.md)
Gets a Remote Workforce host launch URL for an assigned machine.

### [Get-CWCRemoteWorkforceSession](Docs/Get-CWCRemoteWorkforceSession.md)
Lists the Remote Workforce machines assigned to the calling user.

### [Get-CWCSecurityConfigurationInfo](Docs/Get-CWCSecurityConfigurationInfo.md)
Returns the server's security configuration (user sources, roles, users).

### [Get-CWCSession](Docs/Get-CWCSession.md)
Lists sessions of one type in a session group.

### [Get-CWCSessionDetail](Docs/Get-CWCSessionDetail.md)
Returns the details of a session: session info, events, connections and guest screenshot.

### [Get-CWCSessionGroup](Docs/Get-CWCSessionGroup.md)
Returns all session groups.

### [Initialize-CWCRemoteWorkforceSessionGroup](Docs/Initialize-CWCRemoteWorkforceSessionGroup.md)
Creates or repairs the session group used by the Remote Workforce extension.

### [Invoke-CWCCommand](Docs/Invoke-CWCCommand.md)
Runs a command on a session's machine and returns its output.

### [Invoke-CWCWake](Docs/Invoke-CWCWake.md)
Sends a wake (Wake-on-LAN) request to sessions.

### [New-CWCAccessToken](Docs/New-CWCAccessToken.md)
Gets an access token for joining a session.

### [New-CWCMFA](Docs/New-CWCMFA.md)
Creates a new authenticator-app (TOTP) secret for a ScreenConnect user.

### [New-CWCRemoteWorkforceAssignment](Docs/New-CWCRemoteWorkforceAssignment.md)
Assigns machines to a Remote Workforce user.

### [New-CWCSession](Docs/New-CWCSession.md)
Creates a session.

### [New-CWCUser](Docs/New-CWCUser.md)
Creates an internal user.

### [Remove-CWCHostFromSession](Docs/Remove-CWCHostFromSession.md)
Disconnects one connection (for example a host) from a session.

### [Remove-CWCSession](Docs/Remove-CWCSession.md)
Deletes sessions, optionally uninstalling the Access client first.

### [Remove-CWCSessionNote](Docs/Remove-CWCSessionNote.md)
Removes notes from a session.

### [Remove-CWCUser](Docs/Remove-CWCUser.md)
Deletes an internal user.

### [Send-CWCSessionMessage](Docs/Send-CWCSessionMessage.md)
Sends a chat message to a session's guest.

### [Send-CWCToolboxItem](Docs/Send-CWCToolboxItem.md)
Queues a Toolbox item to run on a session.

### [Update-CWCCustomProperty](Docs/Update-CWCCustomProperty.md)
Sets one custom property of a session.

### [Update-CWCSessionName](Docs/Update-CWCSessionName.md)
Renames a session.

### [Update-CWCUser](Docs/Update-CWCUser.md)
Updates an internal user.

