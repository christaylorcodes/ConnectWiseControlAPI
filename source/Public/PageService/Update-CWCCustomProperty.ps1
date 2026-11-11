function Update-CWCCustomProperty {
    <#
    .SYNOPSIS
        Sets one custom property of a session.

    .DESCRIPTION
        Calls PageService.UpdateSessionCustomPropertyValue.

    .PARAMETER GUID
        Session ID.

    .PARAMETER Property
        The property number of the property to change.

    .PARAMETER Value
        New value.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .EXAMPLE
        Update-CWCCustomProperty -GUID $SessionID -Property 1 -Value 'Acme'

    .NOTES
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [int]$Property,
        [string]$Value,
        # Session group name, or the path parts of a nested group (e.g. 'Clients','Acme')
        [string[]]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Set custom property $Property to '$Value'")) {
        # Sets a value, so it is safe to retry
        Invoke-CWCServiceMethod -Service PageService -Method UpdateSessionCustomPropertyValue -Arguments @(@($Group), $GUID, $Property, $Value) -Idempotent
    }
}
