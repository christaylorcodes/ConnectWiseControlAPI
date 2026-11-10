<#
.SYNOPSIS
    Runs the same checks as CI: PSScriptAnalyzer, manifest, Pester and docs drift.

.DESCRIPTION
    CI (.github/workflows/ci.yml) calls this script one stage at a time, so a green local run means a
    green CI run. With no parameters it runs every stage. In PowerShell 7 on Windows the Test stage
    also re-runs the Pester suite under Windows PowerShell 5.1 (powershell.exe), because the module
    must work on both.

    Stages:
      Analyze   PSScriptAnalyzer over the module folder with .PSScriptAnalyzerSettings.psd1. Errors fail.
      Manifest  Test-ModuleManifest.
      Test      Pester over Tests/. Live tests skip unless the CWC_* environment variables are set.
      Docs      Runs Build/Update-Help.ps1 and fails if it changed any generated help file.

    Runs on Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Stage
    One or more stages to run. Defaults to all of them.

.PARAMETER SkipWindowsPowerShell
    Do not re-run the Test stage under Windows PowerShell 5.1.

.PARAMETER TestResultPath
    Write Pester results as NUnit XML to this path.

.EXAMPLE
    ./Tests/test-local.ps1

.EXAMPLE
    ./Tests/test-local.ps1 -Stage Test -SkipWindowsPowerShell
#>
[CmdletBinding()]
param(
    [ValidateSet('Analyze', 'Manifest', 'Test', 'Docs')]
    [string[]]$Stage = @('Analyze', 'Manifest', 'Test', 'Docs'),

    [switch]$SkipWindowsPowerShell,

    [string]$TestResultPath
)

# Deliberately no $ErrorActionPreference = 'Stop' in this script: module functions read the *global* preference, so
# 'Stop' turns the module's non-terminating Write-Error calls into terminating errors and breaks the error-path tests.
# Use -ErrorAction Stop on individual calls instead.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModuleFolder = Join-Path $RepoRoot 'ConnectWiseControlAPI'
$ManifestPath = Join-Path $ModuleFolder 'ConnectWiseControlAPI.psd1'
$Failures = New-Object System.Collections.Generic.List[string]

function Write-Stage([string]$Name) {
    Write-Host ''
    Write-Host "=== $Name ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)) ===" -ForegroundColor Cyan
}

if ($Stage -contains 'Analyze') {
    Write-Stage 'Analyze'
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $Results = @(Invoke-ScriptAnalyzer -Path $ModuleFolder -Recurse -ErrorAction Stop `
            -Settings (Join-Path $RepoRoot '.PSScriptAnalyzerSettings.psd1'))
    $Errors = @($Results | Where-Object Severity -EQ 'Error')
    if ($Errors) {
        $Errors | Format-Table RuleName, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Host
        $Failures.Add("PSScriptAnalyzer: $($Errors.Count) error(s)")
    }
    Write-Host "PSScriptAnalyzer: $($Errors.Count) error(s), $($Results.Count - $Errors.Count) other finding(s)"
}

if ($Stage -contains 'Manifest') {
    Write-Stage 'Manifest'
    try {
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        Write-Host "$($Manifest.Name) $($Manifest.Version): $($Manifest.ExportedFunctions.Count) exported functions"
    } catch {
        $Failures.Add("Test-ModuleManifest: $($_.Exception.Message)")
    }
}

if ($Stage -contains 'Test') {
    Write-Stage 'Test'
    Import-Module Pester -MinimumVersion 5.7.1 -ErrorAction Stop
    $Config = New-PesterConfiguration
    $Config.Run.Path = Join-Path $RepoRoot 'Tests'
    $Config.Run.PassThru = $true
    $Config.Output.Verbosity = 'Normal'
    if ($TestResultPath) {
        $Config.TestResult.Enabled = $true
        $Config.TestResult.OutputFormat = 'NUnitXml'
        $Config.TestResult.OutputPath = $TestResultPath
    }
    # GitHub Actions sets $ErrorActionPreference = 'Stop' at global scope for pwsh and powershell steps. Run Pester
    # with the default preference so the tests see the same behaviour as a user's session.
    $SavedPreference = $global:ErrorActionPreference
    $global:ErrorActionPreference = 'Continue'
    try {
        $Result = Invoke-Pester -Configuration $Config
    } finally {
        $global:ErrorActionPreference = $SavedPreference
    }
    if ($Result.FailedCount -gt 0 -or $Result.Result -ne 'Passed') {
        $Failures.Add("Pester ($($PSVersionTable.PSEdition)): $($Result.FailedCount) failed, result $($Result.Result)")
    }

    $CanRunDesktop = $PSVersionTable.PSEdition -eq 'Core' -and $IsWindows -and
    (Get-Command powershell.exe -ErrorAction SilentlyContinue)
    if ($CanRunDesktop -and -not $SkipWindowsPowerShell) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Stage Test
        if ($LASTEXITCODE -ne 0) { $Failures.Add('Pester (Windows PowerShell 5.1) failed') }
    }
}

if ($Stage -contains 'Docs') {
    Write-Stage 'Docs'
    # Compare the generated files before and after regenerating them, so help that was already regenerated
    # (staged or not) passes, and only help that Update-Help.ps1 would still change fails.
    $GeneratedPaths = 'Docs', 'ConnectWiseControlAPI_Functions.md', 'ConnectWiseControlAPI/en-US'
    $GetSnapshot = {
        (git -C $RepoRoot diff HEAD -- $GeneratedPaths) -join "`n"
        (git -C $RepoRoot ls-files --others --exclude-standard -- $GeneratedPaths) -join "`n"
    }
    $Before = (& $GetSnapshot) -join "`n"
    & (Join-Path $RepoRoot 'Build/Update-Help.ps1') -ErrorAction Stop
    $After = (& $GetSnapshot) -join "`n"
    if ($Before -ne $After) {
        git -C $RepoRoot status --porcelain -- $GeneratedPaths | Write-Host
        $Failures.Add('Docs drift: ./Build/Update-Help.ps1 changed generated help; review and commit the result')
    } else {
        Write-Host 'Generated help is up to date'
    }
}

Write-Host ''
if ($Failures.Count) {
    $Failures | ForEach-Object { Write-Host "FAILED: $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All stages passed: $($Stage -join ', ')" -ForegroundColor Green
exit 0
