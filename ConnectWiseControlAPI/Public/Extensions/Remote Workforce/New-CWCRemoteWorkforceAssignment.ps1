function New-CWCRemoteWorkforceAssignment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID,
        [Parameter(Mandatory = $True)]
        [string]$Username,
        [string]$DisplayName,
        [string]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Assign to $Username")) {
        # Adds an assignment note: not idempotent, so not retried
        Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method AddAssignmentNoteToSession -Arguments @(
            @($Group),
            $GUID,
            "UserName:$($Username),UserDisplayName:$($DisplayName)"
        )
    }
}
