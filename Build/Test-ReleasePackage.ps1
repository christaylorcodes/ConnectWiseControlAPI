<#
.SYNOPSIS
    Builds the package the PowerShell Gallery will receive and checks that it installs.

.DESCRIPTION
    Used by .github/workflows/release.yml after the build and the tests, and safe to run locally. It:
      1. packs the built module (output/<Name>/<version>/) into a .nupkg in a temporary folder repository
      2. checks the package's version and that it has the tags the Gallery lists and finds commands by
      3. pushes that .nupkg to a second temporary repository with Publish-PSResource -NupkgPath, the same call
         the workflow uses for the real publish
      4. saves the package from the second repository, as Install-Module would
      5. imports the saved copy in PowerShell 7 and in Windows PowerShell 5.1 and checks the version, the number
         of exported functions and that the import shows no warnings

    With -PackagePath the checked .nupkg is copied there, so the workflow can publish that exact file.
    Nothing leaves the machine. Needs PowerShell 7 with Microsoft.PowerShell.PSResourceGet 1.1.0 or newer.

.PARAMETER Version
    The version that must have been built. Defaults to the newest build under output/.

.PARAMETER PackagePath
    Folder to copy the checked .nupkg to. Created when missing.

.EXAMPLE
    ./Tests/test-local.ps1 -Stage Build; ./Build/Test-ReleasePackage.ps1
#>
[CmdletBinding()]
param(
    [string]$Version,

    [string]$PackagePath
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command Publish-PSResource -ErrorAction SilentlyContinue).Parameters.ContainsKey('NupkgPath')) {
    throw 'Publish-PSResource -NupkgPath is not available. Update Microsoft.PowerShell.PSResourceGet to 1.1.0 or newer.'
}

$SourceManifest = @(Get-ChildItem -Path (Join-Path $RepoRoot 'source') -Filter '*.psd1' -File)
if ($SourceManifest.Count -ne 1) { throw "Expected one module manifest in source/, found $($SourceManifest.Count)." }
$ModuleName = $SourceManifest[0].BaseName

$Built = Get-ChildItem -Path (Join-Path $RepoRoot "output/$ModuleName") -Filter "$ModuleName.psd1" -Recurse -File `
    -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Directory.Name } -Descending
if ($Version) { $Built = $Built | Where-Object { $_.Directory.Name -eq $Version } }
$Built = $Built | Select-Object -First 1
if (-not $Built) {
    throw "No built module found under output/$ModuleName. Run ./Tests/test-local.ps1 -Stage Build first."
}

$Manifest = Import-PowerShellDataFile -Path $Built.FullName
$Version = [string]$Manifest.ModuleVersion
$FunctionCount = @($Manifest.FunctionsToExport).Count
if ($Built.Directory.Name -ne $Version) {
    throw "Built folder '$($Built.Directory.Name)' does not match ModuleVersion '$Version' in its manifest."
}

$Work = Join-Path ([IO.Path]::GetTempPath()) ('release-check-' + [guid]::NewGuid().ToString('N'))
$PackFeed = Join-Path $Work 'pack'
$PushFeed = Join-Path $Work 'push'
$Saved = Join-Path $Work 'saved'
New-Item -ItemType Directory -Path $PackFeed, $PushFeed, $Saved | Out-Null
$Suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$PackRepository = "ReleasePack$Suffix"
$PushRepository = "ReleasePush$Suffix"

Register-PSResourceRepository -Name $PackRepository -Uri $PackFeed -Trusted
Register-PSResourceRepository -Name $PushRepository -Uri $PushFeed -Trusted
try {
    Publish-PSResource -Path $Built.Directory.FullName -Repository $PackRepository
    $Package = Get-ChildItem -Path $PackFeed -Filter '*.nupkg' -File | Select-Object -First 1
    if (-not $Package) { throw 'Publish-PSResource produced no .nupkg in the temporary repository.' }
    if ($Package.Name -ne "$ModuleName.$Version.nupkg") { throw "Unexpected package name '$($Package.Name)'." }
    $PackageHash = (Get-FileHash -Path $Package.FullName -Algorithm SHA256).Hash

    # The Gallery lists and finds commands by these package tags (the build adds them to the manifest)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip = [IO.Compression.ZipFile]::OpenRead($Package.FullName)
    try {
        $Entry = $Zip.Entries | Where-Object { $_.FullName -eq "$ModuleName.nuspec" }
        if (-not $Entry) { throw "The package has no $ModuleName.nuspec." }
        $Reader = New-Object System.IO.StreamReader($Entry.Open())
        try { $Nuspec = [xml]$Reader.ReadToEnd() } finally { $Reader.Dispose() }
    } finally {
        $Zip.Dispose()
    }
    $PackageTags = @("$($Nuspec.package.metadata.tags)" -split '\s+')
    $ExpectedTags = @('PSModule', 'PSIncludes_Function') +
        @($Manifest.FunctionsToExport | ForEach-Object { "PSFunction_$_"; "PSCommand_$_" })
    $MissingTags = @($ExpectedTags | Where-Object { $PackageTags -notcontains $_ })
    if ($MissingTags) { throw "The package is missing Gallery tags: $($MissingTags -join ', ')" }
    if ("$($Nuspec.package.metadata.version)" -ne $Version) {
        throw "The package version '$($Nuspec.package.metadata.version)' is not '$Version'."
    }

    Publish-PSResource -NupkgPath $Package.FullName -Repository $PushRepository
    Save-PSResource -Name $ModuleName -Version $Version -Repository $PushRepository -Path $Saved -TrustRepository
    $SavedManifest = Join-Path $Saved "$ModuleName/$Version/$ModuleName.psd1"
    if (-not (Test-Path $SavedManifest)) { throw "The saved package has no manifest at $SavedManifest." }

    # Runs in a fresh process of each edition; prints one line that is compared below
    $Check = @'
$ErrorActionPreference = 'Stop'
$Warnings = @()
$Module = Import-Module '{0}' -PassThru -WarningVariable Warnings -WarningAction SilentlyContinue
'RESULT version={{0}} functions={{1}} aliases={{2}} warnings={{3}}' -f $Module.Version, $Module.ExportedFunctions.Count,
    $Module.ExportedAliases.Count, $Warnings.Count
'@ -f $SavedManifest.Replace("'", "''")
    $Expected = "RESULT version=$Version functions=$FunctionCount aliases=0 warnings=0"

    $Shells = @((Get-Process -Id $PID).Path)
    $Desktop = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($Desktop) {
        $Shells += $Desktop.Source
    } else {
        Write-Warning 'powershell.exe not found; Windows PowerShell 5.1 not checked.'
    }
    foreach ($Shell in $Shells) {
        $Output = @(& $Shell -NoProfile -NonInteractive -Command $Check 2>&1 | ForEach-Object { "$_" })
        $Result = $Output | Where-Object { $_ -like 'RESULT *' } | Select-Object -Last 1
        if ($LASTEXITCODE -ne 0 -or $Result -ne $Expected) {
            throw "Package check failed in $Shell.`nExpected: $Expected`nGot: $($Output -join "`n")"
        }
        Write-Host "$([IO.Path]::GetFileNameWithoutExtension($Shell)): $Result"
    }

    $CopiedPackage = $null
    if ($PackagePath) {
        if (-not (Test-Path $PackagePath)) { New-Item -ItemType Directory -Path $PackagePath | Out-Null }
        $CopiedPackage = (Copy-Item -Path $Package.FullName -Destination $PackagePath -PassThru).FullName
        if ((Get-FileHash -Path $CopiedPackage -Algorithm SHA256).Hash -ne $PackageHash) {
            throw "The copy of the package at $CopiedPackage does not match the checked package."
        }
    }

    [pscustomobject]@{
        ModuleName    = $ModuleName
        Version       = $Version
        Functions     = $FunctionCount
        PackageName   = $Package.Name
        PackageSha256 = $PackageHash
        PackageFile   = $CopiedPackage
    }
} finally {
    Unregister-PSResourceRepository -Name $PackRepository, $PushRepository -ErrorAction SilentlyContinue
    Remove-Item -Path $Work -Recurse -Force -ErrorAction SilentlyContinue
}
