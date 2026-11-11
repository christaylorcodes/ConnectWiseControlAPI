<#
.SYNOPSIS
    Checks that the repository is ready to release a version and returns the version and its release notes.

.DESCRIPTION
    Used by .github/workflows/release.yml before anything is built. It fails (throws) unless:
      - the tag is v<major>.<minor>.<patch> and equals the ModuleVersion in the source manifest
      - CHANGELOG.md has a dated section for that version: ## [0.5.0] - 2026-01-31
      - the section has text
      - that version is not already on the PowerShell Gallery (a published version can never be replaced)

    Without -Tag it is a dry run for the version in the manifest. A dry run only warns when the version is
    already on the Gallery, and with -AllowUnreleased it takes the notes from the [Unreleased] section when the
    version has no section yet.

    The Gallery check fails when the Gallery cannot be reached: no answer is not treated as "not published".

.PARAMETER Tag
    The git tag being released, for example v0.5.0. Leave empty for a dry run.

.PARAMETER AllowUnreleased
    Dry run only: use the [Unreleased] section when CHANGELOG.md has no section for the version.

.PARAMETER SkipGalleryCheck
    Do not ask the PowerShell Gallery whether the version already exists.

.PARAMETER NotesPath
    Write the release notes (the CHANGELOG section without its heading) to this file.

.PARAMETER ManifestPath
    The source manifest. Defaults to the only .psd1 in source/.

.PARAMETER ChangelogPath
    Defaults to CHANGELOG.md in the repository root.

.EXAMPLE
    ./Build/Get-ReleaseInfo.ps1 -Tag v0.5.0 -NotesPath output/release-notes.md

.EXAMPLE
    ./Build/Get-ReleaseInfo.ps1 -AllowUnreleased -SkipGalleryCheck
#>
[CmdletBinding()]
param(
    [string]$Tag,

    [switch]$AllowUnreleased,

    [switch]$SkipGalleryCheck,

    [string]$NotesPath,

    [string]$ManifestPath,

    [string]$ChangelogPath
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not $ManifestPath) {
    $Found = @(Get-ChildItem -Path (Join-Path $RepoRoot 'source') -Filter '*.psd1' -File)
    if ($Found.Count -ne 1) { throw "Expected one module manifest in source/, found $($Found.Count)." }
    $ManifestPath = $Found[0].FullName
}
if (-not $ChangelogPath) { $ChangelogPath = Join-Path $RepoRoot 'CHANGELOG.md' }

$ModuleName = [IO.Path]::GetFileNameWithoutExtension($ManifestPath)
$Version = [string](Import-PowerShellDataFile -Path $ManifestPath).ModuleVersion
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "ModuleVersion '$Version' in the manifest must have three parts (major.minor.patch)."
}

if ($Tag) {
    if ($AllowUnreleased) { throw '-AllowUnreleased is for dry runs only; do not combine it with -Tag.' }
    if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw "Tag '$Tag' must look like v1.2.3." }
    if ($Tag -ne "v$Version") {
        throw "Tag '$Tag' does not match ModuleVersion '$Version' in the manifest. Fix the manifest or the tag."
    }
}

# Split the changelog into sections by their '## [name]' headings
$Lines = @(Get-Content -Path $ChangelogPath)
$Sections = [ordered]@{}
$Current = $null
foreach ($Line in $Lines) {
    if ($Line -match '^## \[(?<Name>[^\]]+)\](?<Rest>.*)$') {
        $Current = $Matches.Name
        $Sections[$Current] = @{
            Heading = $Line
            Rest    = $Matches.Rest
            Body    = New-Object System.Collections.Generic.List[string]
        }
    } elseif ($Line -match '^\[[^\]]+\]:\s') {
        $Current = $null   # link definitions at the end of the file
    } elseif ($Current) {
        $Sections[$Current].Body.Add($Line)
    }
}

$NotesSource = $Version
if ($Sections.Contains($Version)) {
    if ($Sections[$Version].Rest -notmatch '^ - \d{4}-\d{2}-\d{2}\s*$') {
        throw "CHANGELOG heading '$($Sections[$Version].Heading)' needs a date: ## [$Version] - yyyy-MM-dd"
    }
} elseif (-not $Tag -and $AllowUnreleased -and $Sections.Contains('Unreleased')) {
    $NotesSource = 'Unreleased'
} else {
    throw "CHANGELOG.md has no '## [$Version] - yyyy-MM-dd' section. Move the [Unreleased] notes under it first."
}

$Notes = ($Sections[$NotesSource].Body -join "`n").Trim()
if (-not $Notes) { throw "CHANGELOG section [$NotesSource] is empty." }

$AlreadyPublished = $null
if (-not $SkipGalleryCheck) {
    # Ask the Gallery for this exact package version: 200 = it exists (unlisted versions too), 404 = it does not.
    # Any other answer, or none, fails the check instead of counting as "not published".
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    $Uri = "https://www.powershellgallery.com/api/v2/Packages(Id='$ModuleName',Version='$Version')"
    try {
        Invoke-WebRequest -Uri $Uri -UseBasicParsing | Out-Null
        $AlreadyPublished = $true
    } catch {
        $Status = 0
        if ($_.Exception.Response) { $Status = [int]$_.Exception.Response.StatusCode }
        if ($Status -ne 404) {
            throw ("Could not check the PowerShell Gallery for $ModuleName $Version (HTTP $Status): " +
                $_.Exception.Message)
        }
        $AlreadyPublished = $false
    }
    if ($AlreadyPublished) {
        $Message = "$ModuleName $Version is already on the PowerShell Gallery. A version cannot be replaced; " +
            'raise ModuleVersion for the next release.'
        if ($Tag) { throw $Message }
        Write-Warning $Message
    }
}

if ($NotesPath) {
    $NotesFolder = Split-Path -Parent $NotesPath
    if ($NotesFolder -and -not (Test-Path $NotesFolder)) { New-Item -ItemType Directory -Path $NotesFolder | Out-Null }
    [IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NotesPath),
        $Notes + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

[pscustomobject]@{
    ModuleName       = $ModuleName
    Version          = $Version
    Tag              = "v$Version"
    DryRun           = -not $Tag
    NotesSource      = $NotesSource
    AlreadyPublished = $AlreadyPublished
    Notes            = $Notes
}
