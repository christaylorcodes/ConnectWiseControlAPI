function Get-CWCLauncURL {
    <#
    .SYNOPSIS
        DEPRECATED. Use Get-CWCRemoteWorkforceLaunchURL.

    .DESCRIPTION
        Retained for backwards compatibility. Forwards -GUID to Get-CWCRemoteWorkforceLaunchURL.
        The Remote Workforce GetLaunchUrlForSessionId endpoint takes only a session ID, so the
        OnSuccess, OnFailure, UserContext, UserNameOverride and PasswordOverride parameters are
        ignored. This function will be removed in v1.0.

    .PARAMETER GUID
        One or more session IDs.

    .PARAMETER OnSuccess
        Ignored. Not accepted by the server.

    .PARAMETER OnFailure
        Ignored. Not accepted by the server.

    .PARAMETER UserContext
        Ignored. Not accepted by the server.

    .PARAMETER UserNameOverride
        Ignored. Not accepted by the server.

    .PARAMETER PasswordOverride
        Ignored. Not accepted by the server.

    .EXAMPLE
        Get-CWCRemoteWorkforceLaunchURL -GUID $SessionID

    .NOTES
        Deprecated in favor of Get-CWCRemoteWorkforceLaunchURL.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID,
        [string]$OnSuccess,
        [string]$OnFailure,
        [string]$UserContext,
        [string]$UserNameOverride,
        [securestring]$PasswordOverride
    )

    Write-Warning 'Get-CWCLauncURL is deprecated and will be removed in v1.0. Use Get-CWCRemoteWorkforceLaunchURL.'

    $IgnoredParameters = @('OnSuccess', 'OnFailure', 'UserContext', 'UserNameOverride', 'PasswordOverride') |
        Where-Object { $PSBoundParameters.ContainsKey($_) }
    if ($IgnoredParameters) {
        Write-Warning "Ignoring parameter(s) not accepted by the server: $($IgnoredParameters -join ', ')"
    }

    if ($PSCmdlet.ShouldProcess("$GUID", 'Get-CWCLauncURL')) {
        Get-CWCRemoteWorkforceLaunchURL -GUID $GUID
    }
}
