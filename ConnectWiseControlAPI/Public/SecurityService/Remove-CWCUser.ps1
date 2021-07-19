function Remove-CWCUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [string]$User
    )

    $Endpoint = 'Services/SecurityService.ashx/DeleteUser'

    $Body = ConvertTo-Json @(
        $script:InternalUserSource,
        $User
    )

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "Remove-CWCUser")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}