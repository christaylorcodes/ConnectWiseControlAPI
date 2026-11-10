---
Module Name: ConnectWiseControlAPI
Module Guid: f94fa996-0f01-4c5c-9cd9-3227728ebacb
Download Help Link: https://github.com/christaylorcodes/ConnectWiseControlAPI/blob/master/ConnectWiseControlAPI_Functions.md
Help Version: 0.1.2.0
Locale: en-US
---

# ConnectWiseControlAPI Module
## Description
This module wraps the web API into PowerShell functions.

## ConnectWiseControlAPI Cmdlets
### [Add-CWCRemoteWorkforceRequiredRole](Docs/Add-CWCRemoteWorkforceRequiredRole.md)
Create a new Remote Workforce security role

### [Add-CWCSessionNote](Docs/Add-CWCSessionNote.md)
Adds a note to a session.

### [Connect-CWC](Docs/Connect-CWC.md)
Connects to a ConnectWise Control server.

### [Enter-CWCSession](Docs/Enter-CWCSession.md)
Opens the ConnectWise Control Host client joined to a session, like Join in the web UI.

### [Find-CWCSession](Docs/Find-CWCSession.md)
Finds sessions by session filter expression, name or ID (API secret connections).

### [Get-CWCAuditInfo](Docs/Get-CWCAuditInfo.md)
Shows current audit settings

### [Get-CWCAuditLog](Docs/Get-CWCAuditLog.md)
Pull audit log information

### [Get-CWCLastContact](Docs/Get-CWCLastContact.md)
Returns the date the machine last connected to the control server.

### [Get-CWCLauncURL](Docs/Get-CWCLauncURL.md)
DEPRECATED.
Use Get-CWCRemoteWorkforceLaunchURL.

### [Get-CWCRemoteWorkforceLaunchURL](Docs/Get-CWCRemoteWorkforceLaunchURL.md)
Gets a Remote Workforce host launch URL for an assigned machine.

### [Get-CWCRemoteWorkforceSession](Docs/Get-CWCRemoteWorkforceSession.md)
Lists the Remote Workforce machines assigned to the calling user.

### [Get-CWCSecurityConfigurationInfo](Docs/Get-CWCSecurityConfigurationInfo.md)
Will return security configuration information.

### [Get-CWCSession](Docs/Get-CWCSession.md)
Will return a list of sessions.

### [Get-CWCSessionDetail](Docs/Get-CWCSessionDetail.md)
Will return information about a session.

### [Get-CWCSessionGroup](Docs/Get-CWCSessionGroup.md)
Returns details of all session groups.

### [Initialize-CWCRemoteWorkforceSessionGroup](Docs/Initialize-CWCRemoteWorkforceSessionGroup.md)
Creates or repairs the session group used by the Remote Workforce extension.

### [Invoke-CWCCommand](Docs/Invoke-CWCCommand.md)
Will issue a command against a given machine and return the results.

### [Invoke-CWCWake](Docs/Invoke-CWCWake.md)
Will issue a wake command to a given session.

### [New-CWCAccessToken](Docs/New-CWCAccessToken.md)
Gets an access token for joining a session.

### [New-CWCMFA](Docs/New-CWCMFA.md)
Will generate an MFA code to use with user creation.

### [New-CWCRemoteWorkforceAssignment](Docs/New-CWCRemoteWorkforceAssignment.md)
Assign a user to machines.

### [New-CWCSession](Docs/New-CWCSession.md)
Creates a session.

### [New-CWCUser](Docs/New-CWCUser.md)
Creates a user.

### [Remove-CWCHostFromSession](Docs/Remove-CWCHostFromSession.md)
Disconnects one connection (for example a host) from a session.

### [Remove-CWCSession](Docs/Remove-CWCSession.md)
Will end a given session.

### [Remove-CWCSessionNote](Docs/Remove-CWCSessionNote.md)
Removes notes from a session.

### [Remove-CWCUser](Docs/Remove-CWCUser.md)
Removes an internal user.

### [Send-CWCSessionMessage](Docs/Send-CWCSessionMessage.md)
Sends a chat message to a session's guest.

### [Send-CWCToolboxItem](Docs/Send-CWCToolboxItem.md)
Queues a Toolbox item to run on a session.

### [Update-CWCCustomProperty](Docs/Update-CWCCustomProperty.md)
Will update a custom property for a session.

### [Update-CWCSessionName](Docs/Update-CWCSessionName.md)
Updates the name of a session.

### [Update-CWCUser](Docs/Update-CWCUser.md)
Update properties of an internal user.

