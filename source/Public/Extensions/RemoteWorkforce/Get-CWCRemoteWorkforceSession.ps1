function Get-CWCRemoteWorkforceSession {
    <#
    .SYNOPSIS
        Lists the Remote Workforce machines assigned to the calling user.

    .DESCRIPTION
        Calls the Remote Workforce extension's GetRemoteWorkforceSessions endpoint, which returns the
        sessions in the extension's session group for the CALLING user that they can view and join.
        The server's name-to-ID map is returned as objects with Name and SessionID properties.

    .EXAMPLE
        Get-CWCRemoteWorkforceSession

    .EXAMPLE
        Get-CWCRemoteWorkforceSession | Get-CWCRemoteWorkforceLaunchURL

    .NOTES
        Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), ScreenConnect 23.6+.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param()

    $Result = Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method GetRemoteWorkforceSessions -Arguments @() -Idempotent
    if ($null -eq $Result) { return }

    foreach ($Property in $Result.PSObject.Properties) {
        [PSCustomObject]@{
            Name      = $Property.Name
            SessionID = [guid]$Property.Value
        }
    }
}
