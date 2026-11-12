function Get-CWCToolbox {
    <#
    .SYNOPSIS
        Lists the contents of the ScreenConnect Toolbox.

    .DESCRIPTION
        Calls PageService.GetToolbox, the same call the host client makes to list Toolbox items. Any
        signed-in user can call it.

        The server returns a tree: a root folder whose Items hold folders and files, each with a Name,
        Attributes (1 for a folder, 0 for a file), a base64 icon (Image) and its own Items. By default the tree is
        flattened to one object per folder and file, with its Path inside the Toolbox and without the icon.

        Use it to find an item for Send-CWCToolboxItem, or to check an upload made with Add-CWCToolboxItem.

    .PARAMETER Raw
        Return the tree as the server sends it, including the icons.

    .EXAMPLE
        Get-CWCToolbox

        Lists every folder and file in the Toolbox.

    .EXAMPLE
        Get-CWCToolbox | Where-Object { -not $_.IsFolder -and $_.Path -like 'Scripts/*' }

    .NOTES
        Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot list the Toolbox).
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    param (
        [switch]$Raw
    )

    # On an error there is no response, and the walk below returns nothing
    $Toolbox = Invoke-CWCServiceMethod -Service PageService -Method GetToolbox -Idempotent
    if ($Raw) { return $Toolbox }

    # Depth-first, in the server's order. The root folder itself is not part of an item's path.
    $Walk = {
        param($Items, $Parent)
        foreach ($Item in $Items) {
            if (-not $Item) { continue }
            $ItemPath = "$Parent$($Item.Name)"
            # Attributes is 1 for a folder and 0 for a file (seen live, 2026-11-11). Files also carry an
            # Items list, but an empty one; anything with items in it is a folder whatever its Attributes.
            $IsFolder = [bool](($Item.Attributes -as [int]) -band 1) -or [bool]$Item.Items
            [PSCustomObject]@{
                Path       = $ItemPath
                Name       = $Item.Name
                IsFolder   = $IsFolder
                Attributes = $Item.Attributes
            }
            if ($IsFolder) { & $Walk $Item.Items "$ItemPath/" }
        }
    }
    & $Walk $Toolbox.Items ''
}
