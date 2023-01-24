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
  $Body = ConvertTo-Json @(
    @(
      $Group
    ),
    @(
      @{
        SessionID = $GUID
        EventType = $SessionEventType
      }
    )
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