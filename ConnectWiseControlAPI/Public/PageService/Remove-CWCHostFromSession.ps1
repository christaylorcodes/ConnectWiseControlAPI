function Remove-CWCHostFromSession
{
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $True)]
    [guid[]]$SessionID,
    [Parameter(Mandatory = $True)]
    [guid[]]$ConnectionID,
    [Parameter(Mandatory = $True)]
    [string]$Group
  )

  $Endpoint = 'Services/PageService.ashx/AddSessionEvents'

  $SessionEventType = 48
  $Body = ConvertTo-Json @(
    @(
      $Group
    ),
    @(
      @{
        SessionID = $SessionID
        EventType = $SessionEventType
        ConnectionID = $ConnectionID
      }
    )
  )

  $WebRequestArguments = @{
    Endpoint = $Endpoint
    Body     = $Body
    Method   = 'Post'
  }
  if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, 'Remove-CWCHostFromSession'))
  {
    Invoke-CWCWebRequest -Arguments $WebRequestArguments
  }
}