<#
.SYNOPSIS
    Packages the built module the way the PowerShell Gallery would receive it and checks the package installs.

.DESCRIPTION
    Used by .github/workflows/release.yml after the build and the tests, and safe to run locally. It:
      1. publishes the built module (output/<Name>/<version>/) to a temporary folder repository
      2. saves the package from that repository, as Install-Module would
      3. imports the saved copy in PowerShell 7 and in Windows PowerShell 5.1 and checks the version, the number
         of exported functions and that the import shows no warnings

    Nothing leaves the machine. Needs PowerShell 7 with Microsoft.PowerShell.PSResourceGet.

.PARAMETER Version
    The version that must have been built. Defaults to the newest build under output/.

.EXAMPLE
    ./Tests/test-local.ps1 -Stage Build; ./Build/Test-ReleasePackage.ps1
#>
[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

$SourceManifest = @(Get-ChildItem -Path (Join-Path $RepoRoot 'source') -Filter '*.psd1' -File)
if ($SourceManifest.Count -ne 1) { throw "Expected one module manifest in source/, found $($SourceManifest.Count)." }
$ModuleName = $SourceManifest[0].BaseName

$Built = Get-ChildItem -Path (Join-Path $RepoRoot "output/$ModuleName") -Filter "$ModuleName.psd1" -Recurse -File `
    -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Directory.Name } -Descending
if ($Version) { $Built = $Built | Where-Object { $_.Directory.Name -eq $Version } }
$Built = $Built | Select-Object -First 1
if (-not $Built) { throw "No built module found under output/$ModuleName. Run ./Tests/test-local.ps1 -Stage Build first." }

$Manifest = Import-PowerShellDataFile -Path $Built.FullName
$Version = [string]$Manifest.ModuleVersion
$FunctionCount = @($Manifest.FunctionsToExport).Count
if ($Built.Directory.Name -ne $Version) {
    throw "Built folder '$($Built.Directory.Name)' does not match ModuleVersion '$Version' in its manifest."
}

$Work = Join-Path ([IO.Path]::GetTempPath()) ('release-check-' + [guid]::NewGuid().ToString('N'))
$Feed = Join-Path $Work 'feed'
$Saved = Join-Path $Work 'saved'
New-Item -ItemType Directory -Path $Feed, $Saved | Out-Null
$Repository = 'ReleaseCheck' + [guid]::NewGuid().ToString('N').Substring(0, 8)

Register-PSResourceRepository -Name $Repository -Uri $Feed -Trusted
try {
    Publish-PSResource -Path $Built.Directory.FullName -Repository $Repository
    $Package = Get-ChildItem -Path $Feed -Filter '*.nupkg' -File | Select-Object -First 1
    if (-not $Package) { throw 'Publish-PSResource produced no .nupkg in the temporary repository.' }
    if ($Package.Name -ne "$ModuleName.$Version.nupkg") { throw "Unexpected package name '$($Package.Name)'." }

    Save-PSResource -Name $ModuleName -Version $Version -Repository $Repository -Path $Saved -TrustRepository
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
    if ($Desktop) { $Shells += $Desktop.Source } else { Write-Warning 'powershell.exe not found; Windows PowerShell 5.1 not checked.' }
    foreach ($Shell in $Shells) {
        $Output = @(& $Shell -NoProfile -NonInteractive -Command $Check 2>&1 | ForEach-Object { "$_" })
        $Result = $Output | Where-Object { $_ -like 'RESULT *' } | Select-Object -Last 1
        if ($LASTEXITCODE -ne 0 -or $Result -ne $Expected) {
            throw "Package check failed in $Shell.`nExpected: $Expected`nGot: $($Output -join "`n")"
        }
        Write-Host "$([IO.Path]::GetFileNameWithoutExtension($Shell)): $Result"
    }

    [pscustomobject]@{
        ModuleName    = $ModuleName
        Version       = $Version
        Functions     = $FunctionCount
        PackageName   = $Package.Name
        PackageSha256 = (Get-FileHash -Path $Package.FullName -Algorithm SHA256).Hash
        ModulePath    = $Built.Directory.FullName
    }
} finally {
    Unregister-PSResourceRepository -Name $Repository -ErrorAction SilentlyContinue
    Remove-Item -Path $Work -Recurse -Force -ErrorAction SilentlyContinue
}
