<#
.SYNOPSIS
    Regenerates Docs/*.md, the module page and the MAML help from the functions' comment-based help.

.DESCRIPTION
    Run after adding or changing a public function or its help. The comment-based help is the only source:
    every page in Docs/ is written again from it, so text edited in a page by hand is lost. Pages of functions
    that no longer exist are deleted. Only the header and description of the module page are kept; its
    Help Version is set to the module version.

    Uses platyPS at the version pinned in RequiredModules.psd1. The build resolves it into
    output/RequiredModules (./Tests/test-local.ps1 -Stage Build); a platyPS of that version installed on the
    machine works too.

    Then fixes what platyPS gets wrong for this repo:
      - PowerShell 7.4+ adds the -ProgressAction common parameter to every page; it is removed.
      - The module page lives at the repo root, so its links need the Docs/ prefix.
    Finally rebuilds source/en-US/ConnectWiseControlAPI-help.xml.

.EXAMPLE
    ./Build/Update-Help.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DocsPath = Join-Path $RepoRoot 'Docs'
$ModulePagePath = Join-Path $RepoRoot 'ConnectWiseControlAPI_Functions.md'

# platyPS at the pinned version, from the build's modules when they are there
$PlatyPSVersion = (Import-PowerShellDataFile -Path (Join-Path $RepoRoot 'RequiredModules.psd1')).platyPS
$RequiredModulesPath = Join-Path $RepoRoot 'output\RequiredModules'
$SavedModulePath = $env:PSModulePath
if ((Test-Path $RequiredModulesPath) -and ($env:PSModulePath -notlike "*$RequiredModulesPath*")) {
    $env:PSModulePath = $RequiredModulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
}
try {
    Import-Module platyPS -RequiredVersion $PlatyPSVersion
} catch {
    throw ("platyPS $PlatyPSVersion is not available: $($_.Exception.Message) Run " +
        "'./Tests/test-local.ps1 -Stage Build' once, or Install-Module platyPS -RequiredVersion $PlatyPSVersion.")
} finally {
    $env:PSModulePath = $SavedModulePath
}
$SourceManifest = Join-Path $RepoRoot 'source\ConnectWiseControlAPI.psd1'
# New-MarkdownHelp finds commands by module name, so another loaded copy (an installed Gallery version, the
# built module) would be documented too. Only the source module may be loaded while the pages are written.
$LoadedBefore = @(Get-Module ConnectWiseControlAPI)
$SourceWasLoaded = [bool]($LoadedBefore | Where-Object { $_.Path -like (Join-Path $RepoRoot 'source\*') })
foreach ($Other in $LoadedBefore) {
    if ($Other.Path -notlike (Join-Path $RepoRoot 'source\*')) {
        Write-Warning "Removing ConnectWiseControlAPI $($Other.Version) loaded from $($Other.ModuleBase)."
    }
    Remove-Module $Other -Force
}
$Module = Import-Module $SourceManifest -Force -PassThru
$Commands = @($Module.ExportedFunctions.Keys | Sort-Object)

# Update-MarkdownHelp keeps the synopsis, description, examples and parameter text of an existing page, so
# changed comment-based help never reached the pages. New-MarkdownHelp -Force writes them from the help.
# Pages of functions that no longer exist are deleted: only platyPS command pages, never other markdown.
foreach ($Stale in Get-ChildItem $DocsPath -Filter '*.md' | Where-Object { $Commands -notcontains $_.BaseName }) {
    if ((Get-Content $Stale.FullName -TotalCount 5) -match '^external help file:') {
        Write-Warning "Deleting $($Stale.Name): the module has no command of that name."
        Remove-Item $Stale.FullName
    }
}
$null = New-MarkdownHelp -Module $Module.Name -OutputFolder $DocsPath -Force
$null = Update-MarkdownHelpModule -Path $DocsPath -ModulePagePath $ModulePagePath -RefreshModulePage -Force

foreach ($Page in Get-ChildItem $DocsPath -Filter '*.md') {
    $Text = [IO.File]::ReadAllText($Page.FullName)
    $Fixed = [regex]::Replace($Text, '(?s)### -ProgressAction\r?\n.*?(?=\r?\n### |\r?\n## )', '')
    $Fixed = [regex]::Replace($Fixed, '\s*\[-ProgressAction <ActionPreference>\]', '')
    if ($Fixed -ne $Text) { [IO.File]::WriteAllText($Page.FullName, $Fixed) }
}

$Text = [IO.File]::ReadAllText($ModulePagePath)
$Text = [regex]::Replace($Text, '\]\((?!Docs/)([A-Za-z-]+\.md)\)', '](Docs/$1)')
# The page header keeps whatever version it had; write the module's
$Text = [regex]::Replace($Text, '(?m)^Help Version: [^\r\n]*', "Help Version: $($Module.Version)")
[IO.File]::WriteAllText($ModulePagePath, $Text)

$null = New-ExternalHelp -Path $DocsPath -OutputPath (Join-Path $RepoRoot 'source\en-US') -Force

# Don't leave the source module loaded when this script loaded it: tests run later in this session would find
# two copies of the module. A source module the caller had loaded stays (reloaded, so its connection is gone).
if (-not $SourceWasLoaded) { Remove-Module $Module -Force }

$Placeholders = Select-String -Path (Join-Path $DocsPath '*.md'), $ModulePagePath -Pattern '\{\{'
foreach ($Hit in $Placeholders) { Write-Warning "Placeholder left to fill: $($Hit.Filename):$($Hit.LineNumber)" }
