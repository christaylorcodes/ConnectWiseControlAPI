# Development entry point: imports the module straight from source/.
# The published module is built by ./build.ps1 (ModuleBuilder), which merges prefix.ps1, Private/ and Public/ into
# one .psm1 and does NOT use this file. Keep module-level code in prefix.ps1, not here.

. (Join-Path $PSScriptRoot 'prefix.ps1')

$Public = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue )

foreach ($Import in @($Public + $Private)) {
    try {
        . $Import.FullName
    } catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

# Export only the Public/ functions
Export-ModuleMember -Function $Public.BaseName