function New-CWCAccessToken {
	<#
	.SYNOPSIS
		Gets an access token for joining a session.

	.DESCRIPTION
		Calls PageService.GetAccessToken. The token lets a Host client join the session with the
		connected user's permissions for that session group; the user needs the JoinSession
		permission in -Group. Treat the token as a secret.

	.PARAMETER Group
		Session group containing the session: a name, or the path parts of a nested group
		(e.g. 'Clients','Acme'). Defaults to 'All Machines'.

	.PARAMETER GUID
		Session ID.

	.EXAMPLE
		$Token = New-CWCAccessToken -GUID $SessionID

	.NOTES
		Requires Connect-CWC -Credentials.
		Author: Chris Taylor

	.LINK
		https://github.com/christaylorcodes/ConnectWiseControlAPI
	#>
	[CmdletBinding()]
	param (
		[string[]]$Group = 'All Machines',
		[Parameter(Mandatory = $True)]
		[guid]$GUID
	)

	Invoke-CWCServiceMethod -Service PageService -Method GetAccessToken -Arguments @(@($Group), "$GUID") -Idempotent
}
