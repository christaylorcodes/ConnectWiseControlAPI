function Get-CWCSessionDetail {
    [CmdletBinding()]
    param (
        [string]$Group = 'All Machines',
        [Parameter(Mandatory=$True)]
        [guid]$GUID
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/GetSessionDetails"

    $Body = ConvertTo-Json @($Group,$GUID)
    Write-Verbose $Body

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}