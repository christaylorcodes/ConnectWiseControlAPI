function Remove-CWCSession
{
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $True)]
    [guid[]]$GUID,
    [Parameter(Mandatory = $True)]
    [string]$Group
  )

  $Endpoint = 'Services/PageService.ashx/AddSessionEvents'

  $SessionEventType = 21

  $GuidList = @()
  foreach ($SessionID in $GUID)
  {
    $GuidList += @{
      SessionID = $SessionID
      EventType = $SessionEventType
    }
  }

  $Body = ConvertTo-Json -Compress -InputObject @(
    @(
      $Group
    ),
    $GuidList
  )

  $WebRequestArguments = @{
    Endpoint = $Endpoint
    Body     = $Body
    Method   = 'Post'
  }
  if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, 'Remove-CWCSession'))
  {
    Invoke-CWCWebRequest -Arguments $WebRequestArguments
  }
}