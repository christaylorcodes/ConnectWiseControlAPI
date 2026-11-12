function Resolve-CWCToolboxPath {
    <#
    .SYNOPSIS
        Normalizes a path inside the Toolbox, or writes a CWC.InvalidToolboxPath error and returns nothing.

    .DESCRIPTION
        Backslashes become forward slashes (the separator Get-CWCToolbox returns) and leading slashes are
        removed. A path is refused here rather than sent when it could name something other than an item
        inside the Toolbox, such as the Toolbox root, its parent or another drive: an empty path, or a
        part that is empty, ends in a dot or whitespace (Windows drops those, so '.', '..', '...' and
        '. ' all resolve to a folder above the item), or holds a character Windows does not allow in a
        file name (which covers 'C:'). A file path ending in a slash is refused too, and so is a part that
        is a Windows device name (CON, NUL, COM1, with or without an extension) or longer than 255
        characters.

    .PARAMETER Path
        Path of the item inside the Toolbox.

    .PARAMETER Folder
        The path names a folder, or may name one: a trailing slash is allowed and removed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [AllowEmptyString()]
        [string]$Path,

        [switch]$Folder
    )

    $Clean = ($Path -replace '\\', '/').TrimStart('/')
    if ($Folder) { $Clean = $Clean.TrimEnd('/') }

    $BadParts = @($Clean -split '/' | Where-Object {
            [string]::IsNullOrWhiteSpace($_) -or $_ -match '[.\s]$' -or $_ -match '[:*?"<>|\x00-\x1f]' -or
            $_ -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)' -or $_.Length -gt 255
        })
    if ($BadParts.Count -gt 0) {
        $Message = "'$Path' is not a valid Toolbox path."
        return Write-Error $Message -ErrorId 'CWC.InvalidToolboxPath' -Category InvalidArgument
    }
    $Clean
}
