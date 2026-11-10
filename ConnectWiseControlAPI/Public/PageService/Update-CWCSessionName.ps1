function Update-CWCSessionName {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True)]
        [guid]$GUID,
        [Parameter(Mandatory=$True)]
        [string]$NewName,
        # Session group name, or the path parts of a nested group
        [string[]]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Rename to '$NewName'")) {
        # Sets a value, so it is safe to retry
        if (Test-CWCApiSecretConnection) {
            # RESTful API Manager: UpdateSessionName(Guid sessionID, string newName). -Group is ignored.
            Invoke-CWCServiceMethod -RestApi -Method UpdateSessionName -Arguments @($GUID.ToString(), $NewName) -Idempotent
        }
        else {
            Invoke-CWCServiceMethod -Service PageService -Method UpdateSessionName -Arguments @(@($Group), $GUID, $NewName) -Idempotent
        }
    }
}