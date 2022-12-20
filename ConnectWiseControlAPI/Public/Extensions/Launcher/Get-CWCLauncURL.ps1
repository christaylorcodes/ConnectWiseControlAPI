function Get-CWCLauncURL {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID
    )

    $Endpoint = 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/GetLaunchUrlForSessionId'

    $Body = ConvertTo-Json @(
        @($GUID)
        $onSuccess
        $onFailure
        $userContext
        $userNameOverride
        $passwordOverride
    )
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body     = $Body
        Method   = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, 'New-CWCRemoteWorkforceAssignment')) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}