function Remove-CWCToolboxItem {
    <#
    .SYNOPSIS
        Deletes a file or folder from the shared ScreenConnect Toolbox.

    .DESCRIPTION
        Calls ToolboxService.ProcessToolboxOperation with the Delete operation. The user needs the
        ManageSharedToolbox permission.

        Only items stored in the server's Toolbox folder can be deleted. Items that an extension adds
        (for example Command Toolbox commands) are refused by the server with "Cannot edit virtual toolbox
        item".

    .PARAMETER Path
        Path of the item inside the Toolbox, e.g. 'Cleanup.cmd' or 'Scripts/Cleanup.cmd': the Path that
        Get-CWCToolbox returns.

    .EXAMPLE
        Remove-CWCToolboxItem -Path 'Scripts/Cleanup.cmd'

    .EXAMPLE
        Get-CWCToolbox | Where-Object Path -like 'API Test/*.cmd' | Remove-CWCToolboxItem -Confirm:$false

    .NOTES
        Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot change the Toolbox).
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    process {
        # Checked up front: the transport would only refuse after the confirmation prompt
        if (Test-CWCApiSecretConnection) {
            $Message = Get-CWCAuthModeMessage -Command $MyInvocation.MyCommand.Name -Required Credentials
            return Write-Error $Message -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
        }

        # Refuses a path that could name the Toolbox root or something outside it ('/', '..', '...', 'C:')
        $ItemPath = Resolve-CWCToolboxPath -Path $Path -Folder
        if (-not $ItemPath) { return }

        # ConfirmImpact High: a deleted item can't be restored, and a folder takes its contents with it
        if (-not $PSCmdlet.ShouldProcess($ItemPath, 'Delete Toolbox item')) { return }

        # ProcessToolboxOperation(ToolboxOperation operation, string path, string originalPath);
        # originalPath is only used by Move. Never retried.
        $Delete = @($script:CWCToolboxOperation.Delete, $ItemPath, $null)
        $null = Invoke-CWCServiceMethod -Service ToolboxService -Method ProcessToolboxOperation -Arguments $Delete
    }
}
