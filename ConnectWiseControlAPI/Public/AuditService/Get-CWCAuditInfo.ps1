function Get-CWCAuditInfo {
    [CmdletBinding()]
    param (
        [datetime]$StartDate,
        [datetime]$EndDate,
        [string]$SessionName,
        [int[]]$EventTypes
    )

    $Endpoint = 'Services/AuditService.ashx/QueryAuditLog'

    $Body = ConvertTo-Json @(
        $(Get-Date $StartDate -Format "yyyy-MM-ddTHH:mm:ss.ffffZ"),
        $(Get-Date $EndDate -Format "yyyy-MM-ddTHH:mm:ss.ffffZ"),
        $SessionName,
        @($EventTypes)
    )
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}
