function New-CWCRemoteWorkforceAssignment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID,
        [Parameter(Mandatory = $True)]
        [string]$Username,
        [string]$DisplayName,
        [string]$Group = 'All Machines'
    )

    $Endpoint = 'App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/AddAssignmentNoteToSession'

    $Body = ConvertTo-Json @(
        @($Group),
        $GUID,
        "UserName:$($Username),UserDisplayName:$($DisplayName)"
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
