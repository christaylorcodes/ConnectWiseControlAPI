function Get-CWCRemoteWorkforceLaunchURL {
    <#
    .SYNOPSIS
        Gets a Remote Workforce host launch URL for an assigned machine.

    .DESCRIPTION
        Calls the Remote Workforce extension's GetLaunchUrlForSessionId (by session GUID) or
        GetLaunchUrl (by session name) endpoint and returns a ClickOnce launch URL.

        The extension only returns a URL when the CALLING user is the user the machine is assigned to
        (the session is in their Remote Workforce session group, "My Assigned Machines" by default)
        and has View and Join permissions on that group. Otherwise the server returns null and this
        function writes a warning. An administrator cannot get launch URLs for other users' machines.

    .PARAMETER GUID
        One or more session IDs. Each is requested separately.

    .PARAMETER SessionName
        The session name to look up within the caller's Remote Workforce sessions.

    .EXAMPLE
        Get-CWCRemoteWorkforceLaunchURL -GUID 'd2b6f0a1-1111-2222-3333-444455556666'

    .EXAMPLE
        Get-CWCRemoteWorkforceSession | Get-CWCRemoteWorkforceLaunchURL

    .EXAMPLE
        Get-CWCRemoteWorkforceLaunchURL -SessionName 'DESKTOP-01'

    .NOTES
        Requires Connect-CWC -Credentials.
        Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), ScreenConnect 23.6+.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(DefaultParameterSetName = 'GUID')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = 'GUID', ValueFromPipelineByPropertyName = $True)]
        [Alias('SessionID')]
        [guid[]]$GUID,

        [Parameter(Mandatory = $True, ParameterSetName = 'SessionName')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionName
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'SessionName') {
            $ServerMethod = 'GetLaunchUrl'
            $Values = @($SessionName)
        }
        else {
            $ServerMethod = 'GetLaunchUrlForSessionId'
            $Values = @($GUID | ForEach-Object { $_.ToString() })
        }

        foreach ($Value in $Values) {
            # The server method takes exactly one argument
            $Result = Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method $ServerMethod -Arguments $Value -Idempotent

            if ($null -eq $Result -or $Result -eq '') {
                Write-Warning "No launch URL returned for '$Value'. Remote Workforce only returns URLs for machines assigned to the calling user."
                continue
            }
            $Result
        }
    }
}
