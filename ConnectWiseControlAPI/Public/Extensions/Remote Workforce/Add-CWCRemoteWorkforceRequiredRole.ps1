function Add-CWCRemoteWorkforceRequiredRole {
    [CmdletBinding()]
    param()

    $URI = "https://$($script:CWCServerConnection.Server)/Services/SecurityService.ashx/SaveRole"

    $SessionGroups = @('My Assigned Machines')
    $RoleName = 'Remote Workforce'

    $Body = ConvertTo-Json -Depth 10 @(
        "",
        $RoleName,
        @(),
        @(
            @{
                "AccessControlType" = 0
                "Name" = "ViewSessionGroup"
                "SessionGroupFilter" = 7
                "SessionGroupPath" = $SessionGroups
                "OwnershipFilter" = 0
            },
            @{
                "AccessControlType" = 0
                "Name" = "JoinSession"
                "SessionGroupFilter" = 7
                "SessionGroupPath" = $SessionGroups
                "OwnershipFilter" = 0
            },
            @{
                "AccessControlType" = 0
                "Name" = "HostSessionWithoutConsent"
                "SessionGroupFilter" = 7
                "SessionGroupPath" = $SessionGroups
                "OwnershipFilter" = 0
            }
        )
    )
    Write-Verbose $Body

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }
    Invoke-CWCWebRequest -Arguments $WebRequestArguments
}