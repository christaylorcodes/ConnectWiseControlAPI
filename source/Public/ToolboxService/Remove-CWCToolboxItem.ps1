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

        After the delete the command lists the Toolbox and returns CWC.ToolboxItemNotRemoved when the item,
        or something inside a deleted folder, is still there: the server can answer success and leave a file
        it has open, for example one that is queued to run.

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
        # A prompt that cannot be shown throws: the assignment then never happens and nothing is sent
        $Proceed = $False
        $Proceed = $PSCmdlet.ShouldProcess($ItemPath, 'Delete Toolbox item')
        if (-not $Proceed) { return }

        # ProcessToolboxOperation(ToolboxOperation operation, string path, string originalPath);
        # originalPath is only used by Move. Never retried.
        $Delete = @($script:CWCToolboxOperation.Delete, $ItemPath, $null)
        $DeleteError = $null
        $null = Invoke-CWCServiceMethod -Service ToolboxService -Method ProcessToolboxOperation `
            -Arguments $Delete -ErrorVariable DeleteError
        if ($DeleteError) { return }

        # The server can answer success and delete nothing or only part of a folder (seen live, 2026-11-12:
        # a folder kept a file the server had open after it was queued to run), so the result is checked
        $Left = @(Get-CWCToolbox | Where-Object {
                $_.Path -eq $ItemPath -or
                "$($_.Path)".StartsWith("$ItemPath/", [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($Left.Count -gt 0) {
            $Message = @(
                "The server reported success, but '$ItemPath' is still in the Toolbox"
                "($($Left.Count) item(s) left, for example '$($Left[-1].Path)')."
                'The server cannot delete a file it has open, for example one queued to run. Try again later.'
            ) -join ' '
            Write-Error $Message -ErrorId 'CWC.ToolboxItemNotRemoved' -Category ResourceBusy -TargetObject $ItemPath
        }
    }
}
