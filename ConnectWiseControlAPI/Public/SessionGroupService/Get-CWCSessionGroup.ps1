function Get-CWCSessionGroup
{
  [CmdletBinding()]
  param (
  )

  $URI = "https://$($script:CWCServerConnection.Server)/Services/SessionGroupService.ashx/session-groups"

  $WebRequestArguments = @{
    Uri    = $URI
    Method = 'Get'
  }

  $Data = Invoke-CWCWebRequest -Arguments $WebRequestArguments
  $Data
}
