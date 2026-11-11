<#
.SYNOPSIS
    Regenerates Docs/*.md, the module page and the MAML help from the functions' comment-based help.

.DESCRIPTION
    Run after adding or changing a public function. Requires platyPS (Install-Module platyPS).
    Creates pages for new functions, updates existing ones (keeping hand-written text), then fixes what
    platyPS gets wrong for this repo:
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

Import-Module platyPS
$Module = Import-Module (Join-Path $RepoRoot 'source\ConnectWiseControlAPI.psd1') -Force -PassThru

$Missing = @($Module.ExportedFunctions.Keys | Where-Object { -not (Test-Path (Join-Path $DocsPath "$_.md")) })
if ($Missing) { $null = New-MarkdownHelp -Command $Missing -OutputFolder $DocsPath }
$null = Update-MarkdownHelpModule -Path $DocsPath -ModulePagePath $ModulePagePath -RefreshModulePage -Force

foreach ($Page in Get-ChildItem $DocsPath -Filter '*.md') {
    $Text = [IO.File]::ReadAllText($Page.FullName)
    $Fixed = [regex]::Replace($Text, '(?s)### -ProgressAction\r?\n.*?(?=\r?\n### |\r?\n## )', '')
    $Fixed = [regex]::Replace($Fixed, '\s*\[-ProgressAction <ActionPreference>\]', '')
    if ($Fixed -ne $Text) { [IO.File]::WriteAllText($Page.FullName, $Fixed) }
}

$Text = [IO.File]::ReadAllText($ModulePagePath)
[IO.File]::WriteAllText($ModulePagePath, [regex]::Replace($Text, '\]\((?!Docs/)([A-Za-z-]+\.md)\)', '](Docs/$1)'))

$null = New-ExternalHelp -Path $DocsPath -OutputPath (Join-Path $RepoRoot 'source\en-US') -Force

$Placeholders = Select-String -Path (Join-Path $DocsPath '*.md'), $ModulePagePath -Pattern '\{\{'
foreach ($Hit in $Placeholders) { Write-Warning "Placeholder left to fill: $($Hit.Filename):$($Hit.LineNumber)" }
