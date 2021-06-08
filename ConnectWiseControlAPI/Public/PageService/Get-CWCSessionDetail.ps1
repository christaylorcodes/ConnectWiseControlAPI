function Get-CWCSessionDetail {
    [CmdletBinding()]
    param (
        [string]$Group = 'All Machines',
        [Parameter(Mandatory=$True)]
        [guid]$GUID
    )

    $Endpoint = 'Services/PageService.ashx/GetSessionDetails'

    $Body = ConvertTo-Json @($Group,$GUID)
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}