function New-CWCRemoteWorkforceAssignment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid[]]$GUID,
        [Parameter(Mandatory=$True)]
        [string]$Username,
        [string]$DisplayName
    )

    $URI = "https://$($script:CWCServerConnection.Server)/App_Extensions/2c4f522f-b39a-413a-8807-dc52a2fce13e/Service.ashx/AddAssignmentNoteToSession"

    $Body = ConvertTo-Json @(
        $GUID,
        "UserName:$($Username),UserDisplayName:$($DisplayName)"
    )

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    if ($PSCmdlet.ShouldProcess($WebRequestArguments.Body, "New-CWCRemoteWorkforceAssignment")) {
        Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}
