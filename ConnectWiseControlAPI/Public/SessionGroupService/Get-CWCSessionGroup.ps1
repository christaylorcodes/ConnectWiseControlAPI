function Get-CWCSessionGroup {
  [CmdletBinding()]
  param ()

  $Endpoint = 'Services/SessionGroupService.ashx/session-groups'

  $WebRequestArguments = @{
    Endpoint = $Endpoint
    Method = 'Get'
  }

  Invoke-CWCWebRequest -Arguments $WebRequestArguments
}
