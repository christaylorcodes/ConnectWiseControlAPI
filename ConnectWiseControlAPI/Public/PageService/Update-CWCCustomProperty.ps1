function Update-CWCCustomProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [string]$NewName,
        [string]$Group = 'All Machines'
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/UpdateSessionName"

    $Body = ConvertTo-Json @($Group,$GUID,$NewName)
    Write-Verbose $Body

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Update-CWCCustomProperty")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}