<#
.SYNOPSIS
    Runs the same checks as CI: build, PSScriptAnalyzer, manifest, Pester and docs drift.

.DESCRIPTION
    CI (.github/workflows/ci.yml) calls this script with one or two stages per job, and the release workflow
    with all of them, so a green local run means a green CI run. With no parameters it runs every stage.
    In PowerShell 7 on Windows the Test stage also re-runs the Pester suite under Windows PowerShell 5.1
    (powershell.exe), because the module must work on both.

    Stages:
      Build     ./build.ps1 -Tasks build (Sampler/ModuleBuilder) -> output/<Name>/<version>/. The first run adds
                -ResolveDependency to fetch the pinned tools into output/RequiredModules. Needs PowerShell 7.
      Analyze   PSScriptAnalyzer over source/ with .PSScriptAnalyzerSettings.psd1. Errors fail.
      Manifest  Test-ModuleManifest on the source manifest and, if built, the built one.
      Test      Pester over Tests/ against the BUILT module (what gets published). Live tests skip unless
                the CWC_* environment variables are set. Use -TestSource to test source/ instead.
      Docs      Runs Build/Update-Help.ps1 and fails if it changed any generated help file.

    Runs on Windows PowerShell 5.1 and PowerShell 7 (except Build). No module name is hard-coded.

.PARAMETER Stage
    One or more stages to run. Defaults to all of them.

.PARAMETER SkipWindowsPowerShell
    Do not re-run the Test stage under Windows PowerShell 5.1.

.PARAMETER TestSource
    Run the Test stage against source/ instead of the built module.

.PARAMETER TestResultPath
    Write Pester results as NUnit XML to this path.

.EXAMPLE
    ./Tests/test-local.ps1

.EXAMPLE
    ./Tests/test-local.ps1 -Stage Test -SkipWindowsPowerShell
#>
[CmdletBinding()]
param(
    [ValidateSet('Build', 'Analyze', 'Manifest', 'Test', 'Docs')]
    [string[]]$Stage = @('Build', 'Analyze', 'Manifest', 'Test', 'Docs'),

    [switch]$SkipWindowsPowerShell,

    [switch]$TestSource,

    [string]$TestResultPath
)

# Deliberately no $ErrorActionPreference = 'Stop' in this script: module functions read the *global* preference, so
# 'Stop' turns the module's non-terminating Write-Error calls into terminating errors and breaks the error-path tests.
# Use -ErrorAction Stop on individual calls instead.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceFolder = Join-Path $RepoRoot 'source'
$ResolveManifestScript = Join-Path $PSScriptRoot 'TestHelpers/Resolve-TestModuleManifest.ps1'
$SavedTestPath = $env:MODULE_TEST_PATH
$env:MODULE_TEST_PATH = $null
$ManifestPath = & $ResolveManifestScript   # the source manifest (one rule for test-local and the tests)
$env:MODULE_TEST_PATH = $SavedTestPath
$ModuleName = [IO.Path]::GetFileNameWithoutExtension($ManifestPath)
$Failures = New-Object System.Collections.Generic.List[string]

# Modules resolved by the build (pinned to the CI versions in RequiredModules.psd1) take precedence when present.
# Restored before the script exits.
$SavedModulePath = $env:PSModulePath
$RequiredModulesPath = Join-Path $RepoRoot 'output/RequiredModules'
function Add-RequiredModulesPath {
    if ((Test-Path $RequiredModulesPath) -and ($env:PSModulePath -notlike "*$RequiredModulesPath*")) {
        $env:PSModulePath = $RequiredModulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
    }
}
Add-RequiredModulesPath

# Tools are imported at the exact version pinned in RequiredModules.psd1, never "whatever is installed": a runner
# image or a developer machine can have another Pester or PSScriptAnalyzer earlier on the module path.
$PinnedModules = Import-PowerShellDataFile -Path (Join-Path $RepoRoot 'RequiredModules.psd1')
function Import-PinnedModule([string]$Name) {
    $Pin = "$($PinnedModules[$Name])"
    if ($Pin -notmatch '^\d+(\.\d+){1,3}$') { throw "RequiredModules.psd1 has no exact version for $Name ('$Pin')." }
    try {
        Import-Module $Name -RequiredVersion $Pin -ErrorAction Stop
    } catch {
        throw ("$Name $Pin is not available: $($_.Exception.Message) Run './Tests/test-local.ps1 -Stage Build' " +
            "once to resolve it into output/RequiredModules, or Install-Module $Name -RequiredVersion $Pin.")
    }
    Write-Host "Using $Name $((Get-Module $Name).Version)"
}

function Write-Stage([string]$Name) {
    Write-Host ''
    Write-Host "=== $Name ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)) ===" -ForegroundColor Cyan
}

function Get-DisplayPath([string]$Path) {
    if ($Path.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) { $Path.Substring($RepoRoot.Length + 1) } else { $Path }
}

function Get-BuiltManifest {
    Get-ChildItem -Path (Join-Path $RepoRoot "output/$ModuleName") -Filter "$ModuleName.psd1" -Recurse -File `
        -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Directory.Name } -Descending | Select-Object -First 1
}

if ($Stage -contains 'Build') {
    Write-Stage 'Build'
    if ($PSVersionTable.PSEdition -ne 'Core') {
        $Failures.Add('Build: needs PowerShell 7 (run ./build.ps1 from pwsh)')
    } else {
        $BuildArgs = @('-NoProfile', '-File', (Join-Path $RepoRoot 'build.ps1'), '-Tasks', 'build')
        # Resolve dependencies only once: resolving again after a pin changed leaves two versions side by side,
        # which the Assert_RequiredModule_Versions task rejects. Delete output/RequiredModules to refresh them.
        $Resolve = -not (Test-Path $RequiredModulesPath)
        if ($Resolve) { $BuildArgs += '-ResolveDependency' }
        # Pin the version to the manifest: Sampler would otherwise use GitVersion when it is installed.
        $SavedBuildVersion = $env:ModuleVersion
        $env:ModuleVersion = (Import-PowerShellDataFile -Path $ManifestPath).ModuleVersion
        # The PowerShell Gallery sometimes fails a download (HTTP 502). A half-filled RequiredModules folder cannot
        # be repaired, so a failed first-time resolve is repeated from an empty folder.
        # Only a resolve that left a pinned tool out is repeated: a build fault would fail the same way again.
        $Attempts = if ($Resolve) { 3 } else { 1 }
        $ExpectedManifest = Join-Path $RepoRoot "output/$ModuleName/$($env:ModuleVersion)/$ModuleName.psd1"
        for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
            $BuildStarted = [DateTime]::UtcNow
            & (Get-Process -Id $PID).Path @BuildArgs
            $BuildExit = $LASTEXITCODE
            # build.ps1 can exit 0 after an aborted build, so also require this version's manifest, written by
            # this attempt (an older version folder left under output/ does not count)
            $Built = Get-Item -Path $ExpectedManifest -ErrorAction SilentlyContinue
            $BuildWroteModule = [bool]($Built -and $Built.LastWriteTimeUtc -ge $BuildStarted.AddSeconds(-2))
            if ($BuildExit -eq 0 -and $BuildWroteModule) { break }
            $MissingTools = @($PinnedModules.Keys | Where-Object { $PinnedModules[$_] -is [string] } |
                    Where-Object { -not (Test-Path (Join-Path $RequiredModulesPath "$_/$($PinnedModules[$_])")) })
            if (-not $Resolve -or -not $MissingTools) { break }
            # A half-filled folder is removed even after the last attempt, so the next run resolves again
            Remove-Item -Path $RequiredModulesPath -Recurse -Force -ErrorAction SilentlyContinue
            if ($Attempt -eq $Attempts) { break }
            Write-Warning ("Build attempt $Attempt of $Attempts did not resolve $($MissingTools -join ', '); " +
                'resolving the build tools again in 20 seconds.')
            Start-Sleep -Seconds 20
        }
        if ($BuildExit -ne 0) {
            $Failures.Add("Build: build.ps1 exited with $BuildExit")
        } elseif (-not $BuildWroteModule) {
            $Failures.Add('Build: build.ps1 exited with 0 but wrote no built module (see the build output above)')
        }
        $env:ModuleVersion = $SavedBuildVersion
        # On a clean checkout the build has only just created output/RequiredModules; the later stages need it
        # (the release workflow runs every stage in one call on a runner that has no platyPS).
        Add-RequiredModulesPath
    }
}

if ($Stage -contains 'Analyze') {
    Write-Stage 'Analyze'
    Import-PinnedModule PSScriptAnalyzer
    $Results = @(Invoke-ScriptAnalyzer -Path $SourceFolder -Recurse -ErrorAction Stop `
            -Settings (Join-Path $RepoRoot '.PSScriptAnalyzerSettings.psd1'))
    # Errors fail the stage (a file that does not parse stops Invoke-ScriptAnalyzer through -ErrorAction Stop).
    # These rules also fail it, whatever severity they report:
    #   PSUseCompatibleSyntax is the only check behind the manifest's PowerShellVersion = '3.0' (the 5.1 test run
    #   cannot catch syntax that 5.1 accepts and 3.0 does not); the other two are warnings that keep secrets out
    #   of [string] parameters.
    $BlockingRules = 'PSUseCompatibleSyntax', 'PSAvoidUsingPlainTextForPassword', 'PSUsePSCredentialType'
    $Errors = @($Results | Where-Object {
            "$($_.Severity)" -in 'Error', 'ParseError' -or $_.RuleName -in $BlockingRules
        })
    if ($Errors) {
        $Errors | Format-Table RuleName, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Host
        $Failures.Add("PSScriptAnalyzer: $($Errors.Count) error(s)")
    }
    Write-Host "PSScriptAnalyzer: $($Errors.Count) error(s), $($Results.Count - $Errors.Count) other finding(s)"
    $Results | Where-Object { $Errors -notcontains $_ } | Group-Object RuleName | Sort-Object Count -Descending |
        ForEach-Object { Write-Host ('  {0,4} {1}' -f $_.Count, $_.Name) }
}

if ($Stage -contains 'Manifest') {
    Write-Stage 'Manifest'
    $Manifests = @($ManifestPath)
    $Built = Get-BuiltManifest
    if ($Built) { $Manifests += $Built.FullName }
    foreach ($Path in $Manifests) {
        try {
            $Manifest = Test-ModuleManifest -Path $Path -ErrorAction Stop
            $Exports = @($Manifest.ExportedFunctions.Keys) -join ', '
            if ($Exports.Length -gt 60) { $Exports = "$($Manifest.ExportedFunctions.Count) functions" }
            Write-Host "$(Get-DisplayPath $Path): $($Manifest.Name) $($Manifest.Version), exports $Exports"
        } catch {
            $Failures.Add("Test-ModuleManifest ${Path}: $($_.Exception.Message)")
        }
    }
}

if ($Stage -contains 'Test') {
    Write-Stage 'Test'
    $TestTarget = $null
    if ($TestSource) {
        $TestTarget = $ManifestPath
    } else {
        $Built = Get-BuiltManifest
        if (-not $Built) {
            $Failures.Add('Test: no built module under output/; run the Build stage first (or use -TestSource)')
        } else {
            # Refuse to test a build that is older than the source it came from
            $BuiltTime = (Get-ChildItem -Path $Built.Directory.FullName -Filter '*.psm1' -File).LastWriteTimeUtc
            $Newer = @(Get-ChildItem -Path $SourceFolder -Recurse -File | Where-Object { $_.LastWriteTimeUtc -gt $BuiltTime })
            if ($Newer) {
                $Failures.Add("Test: the build is older than source/ ($(Get-DisplayPath $Newer[0].FullName) changed); " +
                    'run the Build stage first (or use -TestSource)')
            } else {
                $TestTarget = $Built.FullName
            }
        }
    }
    if ($TestTarget) {
        Write-Host "Testing $(Get-DisplayPath $TestTarget)"
        $env:MODULE_TEST_PATH = $TestTarget
        try {
            Import-PinnedModule Pester
            $Config = New-PesterConfiguration
            $Config.Run.Path = Join-Path $RepoRoot 'Tests'
            $Config.Run.PassThru = $true
            $Config.Output.Verbosity = 'Normal'
            if ($TestResultPath) {
                $Config.TestResult.Enabled = $true
                $Config.TestResult.OutputFormat = 'NUnitXml'
                $Config.TestResult.OutputPath = $TestResultPath
            }
            # GitHub Actions sets $ErrorActionPreference = 'Stop' at global scope for pwsh and powershell steps.
            # Run Pester with the default preference so the tests see the same behaviour as a user's session.
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
            # Pester reports 'Passed' when it found nothing to run (a wrong path, renamed files)
            if ($Result.PassedCount -eq 0) {
                $Failures.Add("Pester ($($PSVersionTable.PSEdition)): no test passed ($($Result.TotalCount) found)")
            }

            $CanRunDesktop = $PSVersionTable.PSEdition -eq 'Core' -and $IsWindows -and
            (Get-Command powershell.exe -ErrorAction SilentlyContinue)
            if ($CanRunDesktop -and -not $SkipWindowsPowerShell) {
                # Pass -TestSource only when set: powershell.exe -File receives '-TestSource:$false' as the string
                # 'False', which does not bind to a switch.
                $ChildArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Stage', 'Test')
                if ($TestSource) { $ChildArgs += '-TestSource' }
                & powershell.exe @ChildArgs
                if ($LASTEXITCODE -ne 0) { $Failures.Add('Pester (Windows PowerShell 5.1) failed') }
            }
        } finally {
            # Never leave MODULE_TEST_PATH behind: a later plain Invoke-Pester would silently test this build
            $env:MODULE_TEST_PATH = $SavedTestPath
        }
    }
}

if ($Stage -contains 'Docs') {
    Write-Stage 'Docs'
    # Compare the generated files before and after regenerating them, so help that was already regenerated
    # (staged or not) passes, and only help that Update-Help.ps1 would still change fails.
    $GeneratedPaths = 'Docs', "$($ModuleName)_Functions.md", 'source/en-US'
    $GetSnapshot = {
        (git -C $RepoRoot diff HEAD -- $GeneratedPaths) -join "`n"
        (git -C $RepoRoot ls-files --others --exclude-standard -- $GeneratedPaths) -join "`n"
    }
    $Before = (& $GetSnapshot) -join "`n"
    # Loaded here at the pinned version; Update-Help.ps1's own Import-Module platyPS then finds it loaded
    Import-PinnedModule platyPS
    & (Join-Path $RepoRoot 'Build/Update-Help.ps1') -ErrorAction Stop
    $After = (& $GetSnapshot) -join "`n"
    if ($Before -cne $After) {
        git -C $RepoRoot status --porcelain -- $GeneratedPaths | Write-Host
        $Failures.Add('Docs drift: ./Build/Update-Help.ps1 changed generated help; review and commit the result')
    } else {
        Write-Host 'Generated help is up to date'
    }
}

$env:PSModulePath = $SavedModulePath
Write-Host ''
if ($Failures.Count) {
    $Failures | ForEach-Object { Write-Host "FAILED: $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All stages passed: $($Stage -join ', ')" -ForegroundColor Green
exit 0
