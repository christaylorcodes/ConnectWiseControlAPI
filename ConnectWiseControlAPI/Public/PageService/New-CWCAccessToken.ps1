function New-CWCAccessToken {
	[CmdletBinding()]
	param (
		[String[]]$Group = $script:defaultGroup,
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