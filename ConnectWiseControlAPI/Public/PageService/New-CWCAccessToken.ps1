function New-CWCAccessToken {
	[CmdletBinding()]
	param (
		[String[]]$Group = 'All Machines',
		[Parameter(Mandatory = $True)]
		[guid]$GUID
	)

	$Endpoint = 'Services/PageService.ashx/GetAccessToken'

	$Body = @"
[["$($Group -join '","')"],"$GUID"]
"@
	Write-Verbose $Body

	$WebRequestArguments = @{
		Endpoint = $Endpoint
		Method   = 'Post'
		Body     = $Body
	}
	Invoke-CWCWebRequest -Arguments $WebRequestArguments
}