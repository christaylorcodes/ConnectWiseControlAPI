# Custom build task (loaded automatically by build.ps1 from the .build/ folder).
#
# The PowerShell Gallery lists a module's commands, and finds a module by command name
# (Find-Module -Command, Find-PSResource -CommandName), from package tags: PSIncludes_Function plus
# PSFunction_<name> and PSCommand_<name> for each exported function. PowerShellGet v2 (Publish-Module) added
# them while packing; Publish-PSResource does not. The release publishes with Publish-PSResource, so the
# build writes them into the built manifest. The source manifest keeps only the topic tags.

# Synopsis: Adds the Gallery's command tags (PSFunction_*, PSCommand_*) to the built module manifest.
task Add_Gallery_Command_Tags {
    $sourcePath = Join-Path -Path $BuildRoot -ChildPath 'source'
    $sourceManifest = @(Get-ChildItem -Path $sourcePath -Filter '*.psd1' -File)
    if ($sourceManifest.Count -ne 1) {
        throw "Expected one module manifest in source/, found $($sourceManifest.Count)."
    }
    $moduleName = $sourceManifest[0].BaseName

    $builtRoot = Join-Path -Path $BuildRoot -ChildPath (Join-Path -Path 'output' -ChildPath $moduleName)
    $builtManifest = @(Get-ChildItem -Path $builtRoot -Filter "$moduleName.psd1" -Recurse -File)
    if ($builtManifest.Count -ne 1) {
        throw "Expected one built manifest under $builtRoot, found $($builtManifest.Count)."
    }
    $manifestPath = $builtManifest[0].FullName

    $data = Import-PowerShellDataFile -Path $manifestPath
    $functions = @($data.FunctionsToExport | Where-Object { $_ -and $_ -ne '*' } | Sort-Object)
    if ($functions.Count -eq 0) { throw "The built manifest $manifestPath lists no functions to export." }

    $topicTags = @($data.PrivateData.PSData.Tags | Where-Object { $_ -notmatch '^PS(Includes|Function|Command)_' })
    $tags = @($topicTags) + 'PSIncludes_Function'
    $tags += $functions | ForEach-Object { "PSFunction_$_" }
    $tags += $functions | ForEach-Object { "PSCommand_$_" }

    # NuGet limits the tags field to 4000 characters; PSModule is added when the package is made
    $length = ($tags -join ' ').Length
    if ($length -gt 3900) { throw "The tag list is $length characters; the Gallery allows 4000." }

    Update-Metadata -Path $manifestPath -PropertyName 'PrivateData.PSData.Tags' -Value $tags

    $written = @((Import-PowerShellDataFile -Path $manifestPath).PrivateData.PSData.Tags)
    if (Compare-Object -ReferenceObject $tags -DifferenceObject $written) {
        throw "The tags in $manifestPath do not match the tags that were written."
    }
    Write-Build Green "  $($functions.Count) functions tagged ($($tags.Count) tags, $length characters)"
}
