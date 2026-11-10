function Update-CWCCustomProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [int]$Property,
        [string]$Value,
        [string]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Set custom property $Property to '$Value'")) {
        # Sets a value, so it is safe to retry
        Invoke-CWCServiceMethod -Service PageService -Method UpdateSessionCustomPropertyValue -Arguments @($Group, $GUID, $Property, $Value) -Idempotent
    }
}
