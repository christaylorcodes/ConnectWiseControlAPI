function New-CWCAccessToken {
	[CmdletBinding()]
	param (
		[string]$Group = 'All Machines',
		[Parameter(Mandatory = $True)]
		[guid]$GUID
	)

	Invoke-CWCServiceMethod -Service PageService -Method GetAccessToken -Arguments @(@($Group), "$GUID") -Idempotent
}
