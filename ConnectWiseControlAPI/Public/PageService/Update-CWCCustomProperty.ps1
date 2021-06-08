function Update-CWCCustomProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [int]$Property,
        [string]$Value,
        [string[]]$Group = 'All Machines'
    )

    $Endpoint = 'Services/PageService.ashx/UpdateSessionCustomPropertyValue'

    $Body = ConvertTo-Json @($Group,$GUID,$Property,$Value)

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Update-CWCCustomProperty")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}