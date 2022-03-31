function Get-CWCAuditLog {
    [CmdletBinding()]
    param (
        [datetime]$StartDate,
        [datetime]$EndDate,
        [string]$SessionName,
        [switch]$IncludeSessionCaptures,
        [int[]]$EventTypes,
        [int[]]$SecurityTypes
    )

    $Endpoint = 'Services/AuditService.ashx/QueryAuditLog'

    $Body = ConvertTo-Json @(
        $(Get-Date $StartDate -Format 'yyyy-MM-ddTHH:mm:ss.ffffZ'),
        $(Get-Date $EndDate -Format 'yyyy-MM-ddTHH:mm:ss.ffffZ'),
        $SessionName,
        $IncludeSessionCaptures.IsPresent
        $EventTypes,
        $SecurityTypes
    )
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body     = $Body
        Method   = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}
