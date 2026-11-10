function Add-CWCRemoteWorkforceRequiredRole {
    <#
    .SYNOPSIS
        Creates the security role required by the Remote Workforce extension.

    .DESCRIPTION
        Calls the Remote Workforce extension's EnsureRemoteWorkforceSecurityRoleExists endpoint.
        The extension creates its role (name from the extension's RoleName setting, "Remote Workforce"
        by default) with View Session Group, Join Session and Host Session Without Consent scoped to the
        extension's session group, then marks the role as created in the extension settings.

        Idempotent: if the role already exists nothing is changed. Requires the Administer permission.

    .EXAMPLE
        Add-CWCRemoteWorkforceRequiredRole

    .NOTES
        Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), Control 23.6+.
        Pair with Initialize-CWCRemoteWorkforceSessionGroup.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Remote Workforce security role', 'Add-CWCRemoteWorkforceRequiredRole')) {
        Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method EnsureRemoteWorkforceSecurityRoleExists -Arguments @() -Idempotent
    }
}
