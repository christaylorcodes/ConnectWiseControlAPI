function New-CWCRemoteWorkforceAssignment {
    <#
    .SYNOPSIS
        Assigns machines to a Remote Workforce user.

    .DESCRIPTION
        Calls the Remote Workforce extension's AddAssignmentNoteToSession, which adds an assignment note
        (AddedNote) to each session. The user can then launch the machine from the Remote Workforce page.

    .PARAMETER GUID
        One or more session IDs.

    .PARAMETER Username
        Control user name of the assignee.

    .PARAMETER DisplayName
        Display name of the assignee.

    .PARAMETER Group
        Session group containing the sessions: a name, or the path parts of a nested group. Defaults to
        'All Machines'.

    .EXAMPLE
        New-CWCRemoteWorkforceAssignment -GUID $SessionID -Username 'jdoe' -DisplayName 'Jane Doe'

    .NOTES
        Requires Connect-CWC -Credentials and the Remote Workforce extension.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True)]
        [guid[]]$GUID,
        [Parameter(Mandatory = $True)]
        [string]$Username,
        [string]$DisplayName,
        [string[]]$Group = 'All Machines'
    )

    if ($PSCmdlet.ShouldProcess("$GUID", "Assign to $Username")) {
        # AddAssignmentNoteToSession(string[] sessionGroupPath, Guid[] sessionIDs, string hostName).
        # Adds notes: not idempotent, so not retried.
        Invoke-CWCServiceMethod -ExtensionID $script:CWCRemoteWorkforceExtensionID -Method AddAssignmentNoteToSession -Arguments @(
            @($Group),
            $GUID,
            "UserName:$($Username),UserDisplayName:$($DisplayName)"
        )
    }
}
