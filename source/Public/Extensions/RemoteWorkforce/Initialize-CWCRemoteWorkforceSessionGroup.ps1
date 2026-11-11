function Initialize-CWCRemoteWorkforceSessionGroup {
    <#
    .SYNOPSIS
        Creates or repairs the session group used by the Remote Workforce extension.

    .DESCRIPTION
        Calls the Remote Workforce extension's EnsureCorrectSessionGroupExists endpoint. The extension
        creates its Access session group (name from the SessionGroupName setting, "My Assigned Machines"
        by default) with the filter Notes LIKE '*|UserName:' + $USERLOGINNAME + ',*', or repairs an
        older group whose filter was missing the trailing comma. Without this group, assignments made
        with New-CWCRemoteWorkforceAssignment are not visible to users.

        Idempotent. Requires the Administer permission.

    .EXAMPLE
        Initialize-CWCRemoteWorkforceSessionGroup

    .NOTES
        Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), ScreenConnect 23.6+.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Remote Workforce session group', 'Initialize-CWCRemoteWorkforceSessionGroup')) {
        Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method EnsureCorrectSessionGroupExists -Arguments @() -Idempotent
    }
}
