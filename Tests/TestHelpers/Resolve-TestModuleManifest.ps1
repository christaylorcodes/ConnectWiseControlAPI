<#
.SYNOPSIS
    Returns the path of the module manifest the tests should import.

.DESCRIPTION
    Uses $env:MODULE_TEST_PATH when it is set: Tests/test-local.ps1 (and so CI) sets it to the built manifest under
    output/, so the suite tests what gets published. Otherwise returns the source manifest (source/<Name>.psd1), so
    a plain Invoke-Pester during development always tests the code as edited, never a stale build.
    No module name is hard-coded here.
#>
[CmdletBinding()]
param()

if ($env:MODULE_TEST_PATH) {
    if (-not (Test-Path -LiteralPath $env:MODULE_TEST_PATH)) {
        throw "MODULE_TEST_PATH points to '$env:MODULE_TEST_PATH', which does not exist."
    }
    return (Resolve-Path -LiteralPath $env:MODULE_TEST_PATH).Path
}

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Manifests = @(Get-ChildItem -Path (Join-Path $RepoRoot 'source') -Filter '*.psd1' -File)
if ($Manifests.Count -ne 1) {
    throw "Expected exactly one module manifest in source/; found $($Manifests.Count)."
}
$Manifests[0].FullName