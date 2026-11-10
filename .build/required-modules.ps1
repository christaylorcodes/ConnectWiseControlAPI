# Custom build task: verifies resolved build dependencies (loaded automatically by
# build.ps1 from the .build/ folder).
#
# Resolve-Dependency.ps1 only WARNS when Save-PSResource fails, and GitHub runners ship
# their own Pester/PSScriptAnalyzer. Without this check a bad or unavailable pin leaves
# the build silently running on whatever version the machine happens to have.

function Test-VersionInRange {
    <#
    .SYNOPSIS
        Tests a version against a NuGet-style range ('[1.0,2.0)'), an exact version, or 'latest'.
    #>
    param(
        [Parameter(Mandatory)][version]$Version,
        [Parameter(Mandatory)][string]$Range
    )

    if ($Range -eq 'latest') { return $true }

    if ($Range -match '^\s*([\[\(])\s*([^,]*?)\s*,\s*([^\]\)]*?)\s*([\]\)])\s*$') {
        $minInclusive = $Matches[1] -eq '['
        $maxInclusive = $Matches[4] -eq ']'
        $min = if ($Matches[2]) { [version]$Matches[2] } else { $null }
        $max = if ($Matches[3]) { [version]$Matches[3] } else { $null }

        if ($min -and ($(if ($minInclusive) { $Version -lt $min } else { $Version -le $min }))) { return $false }
        if ($max -and ($(if ($maxInclusive) { $Version -gt $max } else { $Version -ge $max }))) { return $false }
        return $true
    }

    # Exact version ('5.6.1' or '[5.6.1]')
    return $Version -eq [version]($Range.Trim('[', ']', ' '))
}

# Synopsis: Fails if a required module is missing, has more than one version, or is outside its pinned range.
task Assert_RequiredModule_Versions {
    $requiredModulesFile = Join-Path -Path $BuildRoot -ChildPath 'RequiredModules.psd1'
    $requiredModulesDir = if ($RequiredModulesDirectory) { $RequiredModulesDirectory } else { Join-Path 'output' 'RequiredModules' }
    $requiredModulesPath = Get-SamplerAbsolutePath -Path $requiredModulesDir -RelativeTo $BuildRoot

    if (-not (Test-Path -Path $requiredModulesPath)) {
        throw "Required modules folder '$requiredModulesPath' not found. Run './build.ps1 -ResolveDependency -Tasks noop'."
    }

    $requirements = Import-PowerShellDataFile -Path $requiredModulesFile
    $problems = [System.Collections.Generic.List[string]]::new()

    foreach ($name in ($requirements.Keys | Where-Object { $_ -ne 'PSDependOptions' } | Sort-Object)) {
        $spec = $requirements[$name]
        $range = if ($spec -is [hashtable]) { "$($spec.Version)" } else { "$spec" }
        if (-not $range) { $range = 'latest' }

        $moduleFolder = Get-ChildItem -Path $requiredModulesPath -Directory |
            Where-Object Name -EQ $name |
            Select-Object -First 1
        if (-not $moduleFolder) {
            $problems.Add("${name}: not found in $requiredModulesPath")
            continue
        }

        $versions = @(Get-ChildItem -Path $moduleFolder.FullName -Directory |
                Where-Object { $_.Name -as [version] } |
                ForEach-Object { [version]$_.Name })

        if ($versions.Count -ne 1) {
            $problems.Add("${name}: expected exactly one version, found $($versions.Count) ($($versions -join ', '))")
            continue
        }

        if (-not (Test-VersionInRange -Version $versions[0] -Range $range)) {
            $problems.Add("${name}: version $($versions[0]) is outside the required range '$range'")
            continue
        }

        Write-Build Green ("  {0,-22} {1,-12} (required: {2})" -f $name, $versions[0], $range)
    }

    if ($problems.Count -gt 0) {
        $problems | ForEach-Object { Write-Build Red "  $_" }
        throw ('Required module check failed. Delete output/RequiredModules and run ' +
            "'./build.ps1 -ResolveDependency -Tasks noop' from a NEW PowerShell session.")
    }
    # (The template's Pester pre-load is omitted: this repo runs Pester through Tests/test-local.ps1, not Sampler.)
}
