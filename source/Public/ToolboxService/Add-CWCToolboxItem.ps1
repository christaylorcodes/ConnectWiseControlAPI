function Add-CWCToolboxItem {
    <#
    .SYNOPSIS
        Uploads a file to the shared ScreenConnect Toolbox, or creates a Toolbox folder.

    .DESCRIPTION
        Calls ToolboxService.WriteToolboxFileContent. The file is sent in chunks: the first chunk creates
        the item, replacing an item of the same name, and the rest are appended. The user needs the
        ManageSharedToolbox permission.

        When -Name contains a folder, that folder is created first. If a chunk fails, a partial file is
        left in the Toolbox; run the command again to replace it.

        Several files can be piped in; each keeps its own file name.

        Run the uploaded item on a session with Send-CWCToolboxItem.

    .PARAMETER Path
        Local file to upload. Accepts paths and Get-Item / Get-ChildItem output from the pipeline.

    .PARAMETER Name
        Path of the item inside the Toolbox, e.g. 'Cleanup.cmd' or 'Scripts/Cleanup.cmd'. Defaults to the
        file name of -Path. It names one item, so it cannot be used when several files are piped in.

    .PARAMETER Directory
        Create the Toolbox folder -Name instead of uploading a file.

    .PARAMETER ChunkSize
        Bytes of the file sent per request. Defaults to 524288 (512 KB). Lower it if the server rejects
        the request as too large.

    .EXAMPLE
        Add-CWCToolboxItem -Path .\Cleanup.cmd

        Uploads Cleanup.cmd to the top level of the Toolbox.

    .EXAMPLE
        Add-CWCToolboxItem -Path .\Cleanup.cmd -Name 'Scripts/Cleanup.cmd'

        Creates the Scripts folder if needed and uploads the file into it.

    .EXAMPLE
        Get-ChildItem .\Tools\*.exe | Add-CWCToolboxItem

    .EXAMPLE
        Add-CWCToolboxItem -Directory -Name 'Scripts'

    .NOTES
        Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot write to the Toolbox).
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'File')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = 'File', ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(Mandatory = $True, ParameterSetName = 'Directory')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $True, ParameterSetName = 'Directory')]
        [switch]$Directory,

        [Parameter(ParameterSetName = 'File')]
        [ValidateRange(1, 2147483647)]
        [int]$ChunkSize = 524288
    )

    begin {
        $FileCount = 0
    }

    process {
        # Checked up front: the transport would only refuse after the confirmation prompt and the file check
        if (Test-CWCApiSecretConnection) {
            $Message = Get-CWCAuthModeMessage -Command $MyInvocation.MyCommand.Name -Required Credentials
            return Write-Error $Message -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
        }

        # WriteToolboxFileContent(string path, bool isDirectory, bool appendOrReplace, string base64Content)
        # appendOrReplace: true appends to the file, false creates or replaces it.
        # Never retried: repeating an append would duplicate the chunk.
        $Write = @{ Service = 'ToolboxService'; Method = 'WriteToolboxFileContent' }

        if ($PSCmdlet.ParameterSetName -eq 'Directory') {
            $Folder = Resolve-CWCToolboxPath -Path $Name -Folder
            if ($Folder -and $PSCmdlet.ShouldProcess($Folder, 'Create Toolbox folder')) {
                $null = Invoke-CWCServiceMethod @Write -Arguments @($Folder, $True, $False, '')
            }
            return
        }

        $LocalPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
        if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
            return Write-Error "File not found: $LocalPath" -ErrorId 'CWC.FileNotFound' -Category ObjectNotFound
        }

        $FileCount++
        if ($Name -and $FileCount -gt 1) {
            # Each file would replace the one before it
            $Message = "-Name names one Toolbox item, so it cannot be used with several files. Not uploaded: $LocalPath"
            return Write-Error $Message -ErrorId 'CWC.NameWithSeveralFiles' -Category InvalidArgument
        }

        $ItemName = $Name
        if (-not $ItemName) { $ItemName = Split-Path -Path $LocalPath -Leaf }
        $ItemName = Resolve-CWCToolboxPath -Path $ItemName
        if (-not $ItemName) { return }

        if (-not $PSCmdlet.ShouldProcess($ItemName, "Upload '$LocalPath' to the Toolbox")) { return }

        $Append = $False
        try {
            $Stream = [System.IO.File]::OpenRead($LocalPath)
            try {
                # The server writes the file with File.Open, which fails when the folder doesn't exist.
                # Created once the local file is open, so a file that can't be read leaves no empty folder.
                $SeparatorIndex = $ItemName.LastIndexOf('/')
                if ($SeparatorIndex -gt 0) {
                    $Folder = $ItemName.Substring(0, $SeparatorIndex)
                    $null = Invoke-CWCServiceMethod @Write -Arguments @($Folder, $True, $False, '') -ErrorAction Stop
                }

                $Buffer = New-Object byte[] $ChunkSize
                # -not $Append: an empty file still needs one call to create the item
                while (($BytesRead = $Stream.Read($Buffer, 0, $Buffer.Length)) -gt 0 -or -not $Append) {
                    $Chunk = @($ItemName, $False, $Append, [Convert]::ToBase64String($Buffer, 0, $BytesRead))
                    # -Sensitive keeps the file content out of verbose and debug output
                    $null = Invoke-CWCServiceMethod @Write -Arguments $Chunk -Sensitive -ErrorAction Stop
                    $Append = $True
                }
            } finally {
                $Stream.Dispose()
            }
        } catch {
            if ($Append) { Write-Warning "Upload of '$ItemName' stopped part way; a partial file is in the Toolbox." }
            # WriteError keeps the transport's ErrorId (CWC.Http401, ...); Write-Error $_ loses it on PS 5.1
            $PSCmdlet.WriteError($_)
        }
    }
}
