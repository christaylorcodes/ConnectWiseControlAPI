#Requires -Module Pester

<#
.SYNOPSIS
    Module structure, quality, and function validation tests.

.DESCRIPTION
    Tests module manifest, import, exports, function structure,
    parameter validation, and ShouldProcess declarations.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseControlAPI.Module.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    # One public function per Public/**/*.ps1 file; the tests below check the manifest and the loaded
    # module against this list, so a new function needs no test edit.
    $ExpectedFunctions = @(Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'source\Public') -Filter '*.ps1' -Recurse |
        ForEach-Object BaseName | Sort-Object)
}

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = & (Join-Path $PSScriptRoot 'TestHelpers\Resolve-TestModuleManifest.ps1')
    Import-Module $ManifestPath -Force
}

AfterAll {
    Get-Module 'ConnectWiseControlAPI' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Module Quality Tests
# =============================================================================
Describe 'Module: ConnectWiseControlAPI' {

    Context 'Module Manifest' {
        BeforeAll {
            $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        }

        It 'has a valid module manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'has a valid root module' {
            $Manifest.RootModule | Should -Be 'ConnectWiseControlAPI.psm1'
        }

        It 'has a valid GUID' {
            $Manifest.GUID.ToString() | Should -Be 'f94fa996-0f01-4c5c-9cd9-3227728ebacb'
        }

        It 'requires PowerShell 3.0 or higher' {
            $Manifest.PowerShellVersion | Should -Be '3.0'
        }

        It 'has a project URI' {
            $Manifest.PrivateData.PSData.ProjectUri | Should -Not -BeNullOrEmpty
        }

        It 'exports no cmdlets' {
            $Manifest.ExportedCmdlets.Keys | Should -HaveCount 0
        }

        It 'lists every public function in FunctionsToExport exactly once' -ForEach @(@{ Expected = $ExpectedFunctions }) {
            $Listed = @((Import-PowerShellDataFile -Path $ManifestPath).FunctionsToExport)
            if ($Listed.Count -eq 1 -and $Listed[0] -eq '*') {
                # source/ manifest: the build writes the explicit list; the .psm1 exports Public/ via Export-ModuleMember
                Set-ItResult -Skipped -Because "the source manifest uses '*'; the built manifest is checked instead"
                return
            }
            @($Listed | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name) | Should -BeNullOrEmpty
            @($Listed | Sort-Object) | Should -Be $Expected
        }
    }

    Context 'Module Import' {
        It 'is loaded in the session' {
            $module = Get-Module 'ConnectWiseControlAPI'
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be 'ConnectWiseControlAPI'
        }
    }

    Context 'Exported Functions' {
        BeforeAll {
            $ExportedFunctions = (Get-Module 'ConnectWiseControlAPI').ExportedFunctions.Keys
        }

        It 'exports the expected number of functions' -ForEach @(@{ Expected = $ExpectedFunctions }) {
            $ExportedFunctions | Should -HaveCount $Expected.Count
        }

        It 'exports <_>' -ForEach $ExpectedFunctions {
            $_ | Should -BeIn $ExportedFunctions
        }
    }

    Context 'Function-to-File Mapping' {
        BeforeAll {
            $PublicPath = Join-Path $ModuleRoot 'source\Public'
            $PublicFiles = Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse |
                Select-Object -ExpandProperty BaseName
            $ExportedFunctions = (Get-Module 'ConnectWiseControlAPI').ExportedFunctions.Keys
        }

        It 'has a .ps1 file for each exported function' {
            foreach ($function in $ExportedFunctions) {
                $function | Should -BeIn $PublicFiles -Because "$function should have a matching .ps1 file"
            }
        }

        It 'every public .ps1 file corresponds to an exported function' {
            foreach ($file in $PublicFiles) {
                $file | Should -BeIn $ExportedFunctions -Because "$file.ps1 should be exported"
            }
        }
    }

    Context 'Script-Scope Variables' {
        It 'has InternalUserSource set to InternalMembershipProvider' {
            $module = Get-Module 'ConnectWiseControlAPI'
            $value = & $module { $script:InternalUserSource }
            $value | Should -Be 'InternalMembershipProvider'
        }
    }
}

# =============================================================================
# Function Structure Tests
# =============================================================================
Describe 'Function Structure' {

    Context '<_> has proper structure' -ForEach $ExpectedFunctions {
        BeforeAll {
            $cmd = Get-Command $_ -Module 'ConnectWiseControlAPI'
        }

        It 'is a recognized command' {
            $cmd | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding attribute' {
            $cmd.CmdletBinding | Should -BeTrue
        }
    }

    Context 'ShouldProcess on destructive functions' {
        It '<_> supports ShouldProcess' -ForEach @(
            'Remove-CWCSession'
            'Remove-CWCHostFromSession'
            'Remove-CWCSessionNote'
            'Update-CWCCustomProperty'
            'Update-CWCSessionName'
            'New-CWCUser'
            'Remove-CWCUser'
            'Update-CWCUser'
            'Get-CWCLauncURL'
            'Add-CWCRemoteWorkforceRequiredRole'
            'New-CWCRemoteWorkforceAssignment'
            'Initialize-CWCRemoteWorkforceSessionGroup'
            'New-CWCSession'
            'Add-CWCSessionNote'
            'Send-CWCSessionMessage'
            'Send-CWCToolboxItem'
            'New-CWCMFA'
        ) {
            $cmd = Get-Command $_ -Module 'ConnectWiseControlAPI'
            $cmd.Parameters.Keys | Should -Contain 'WhatIf' -Because "$_ should support -WhatIf"
        }
    }
}

# =============================================================================
# Parameter Validation Tests
# =============================================================================
Describe 'Parameter Validation' {

    Context 'Connect-CWC parameters' {
        BeforeAll {
            $cmd = Get-Command Connect-CWC -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory Server parameter' {
            $cmd.Parameters['Server'].Attributes.Mandatory | Should -Contain $True
        }

        It 'has mandatory Credentials parameter' {
            $cmd.Parameters['Credentials'].Attributes.Mandatory | Should -Contain $True
        }

        It 'Credentials is type PSCredential' {
            $cmd.Parameters['Credentials'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'has optional Force switch' {
            $cmd.Parameters.Keys | Should -Contain 'Force'
            $cmd.Parameters['Force'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Get-CWCSession parameters' {
        BeforeAll {
            $cmd = Get-Command Get-CWCSession -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory Type parameter' {
            $cmd.Parameters['Type'].Attributes.Mandatory | Should -Contain $True
        }

        It 'Type validates to Support, Access, Meeting' {
            $validateSet = $cmd.Parameters['Type'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Support'
            $validateSet.ValidValues | Should -Contain 'Access'
            $validateSet.ValidValues | Should -Contain 'Meeting'
            $validateSet.ValidValues | Should -HaveCount 3
        }

        It 'has optional Group parameter' {
            $cmd.Parameters.Keys | Should -Contain 'Group'
        }
    }

    Context 'Invoke-CWCCommand parameters' {
        BeforeAll {
            $cmd = Get-Command Invoke-CWCCommand -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory GUID parameter' {
            $cmd.Parameters['GUID'].Attributes.Mandatory | Should -Contain $True
        }

        It 'GUID is type guid' {
            $cmd.Parameters['GUID'].ParameterType.Name | Should -Be 'Guid'
        }

        It 'has optional TimeOut parameter' {
            $cmd.Parameters.Keys | Should -Contain 'TimeOut'
            $cmd.Parameters['TimeOut'].ParameterType.Name | Should -Be 'Int32'
        }

        It 'has optional MaxLength parameter' {
            $cmd.Parameters.Keys | Should -Contain 'MaxLength'
            $cmd.Parameters['MaxLength'].ParameterType.Name | Should -Be 'Int32'
        }

        It 'has PowerShell switch' {
            $cmd.Parameters['PowerShell'].SwitchParameter | Should -BeTrue
        }

        It 'has NoWait switch' {
            $cmd.Parameters['NoWait'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Invoke-CWCWake parameters' {
        BeforeAll {
            $cmd = Get-Command Invoke-CWCWake -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory Type parameter' {
            $cmd.Parameters['Type'].Attributes.Mandatory | Should -Contain $True
        }

        It 'Type validates to Support, Access only' {
            $validateSet = $cmd.Parameters['Type'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Support'
            $validateSet.ValidValues | Should -Contain 'Access'
            $validateSet.ValidValues | Should -HaveCount 2
        }

        It 'GUID accepts array' {
            $cmd.Parameters['GUID'].ParameterType.Name | Should -Be 'Guid[]'
        }
    }

    Context 'New-CWCUser parameters' {
        BeforeAll {
            $cmd = Get-Command New-CWCUser -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory Credentials parameter' {
            $cmd.Parameters['Credentials'].Attributes.Mandatory | Should -Contain $True
        }

        It 'has mandatory Email parameter' {
            $cmd.Parameters['Email'].Attributes.Mandatory | Should -Contain $True
        }

        It 'has optional ForcePassChange parameter' {
            $cmd.Parameters.Keys | Should -Contain 'ForcePassChange'
            $cmd.Parameters['ForcePassChange'].ParameterType.Name | Should -Be 'Boolean'
        }
    }

    Context 'Remove-CWCSession parameters' {
        BeforeAll {
            $cmd = Get-Command Remove-CWCSession -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory GUID parameter' {
            $cmd.Parameters['GUID'].Attributes.Mandatory | Should -Contain $True
        }

        It 'GUID accepts array' {
            $cmd.Parameters['GUID'].ParameterType.Name | Should -Be 'Guid[]'
        }

        It 'has mandatory Group parameter' {
            $cmd.Parameters['Group'].Attributes.Mandatory | Should -Contain $True
        }
    }

    Context 'Get-CWCLastContact parameters' {
        BeforeAll {
            $cmd = Get-Command Get-CWCLastContact -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory GUID parameter' {
            $cmd.Parameters['GUID'].Attributes.Mandatory | Should -Contain $True
        }

        It 'has Quiet switch' {
            $cmd.Parameters['Quiet'].SwitchParameter | Should -BeTrue
        }

        It 'Quiet is in parameter set Quiet' {
            $cmd.Parameters['Quiet'].ParameterSets.Keys | Should -Contain 'Quiet'
        }
    }

    Context 'Update-CWCUser parameters' {
        BeforeAll {
            $cmd = Get-Command Update-CWCUser -Module 'ConnectWiseControlAPI'
        }

        It 'has mandatory UserToUpdate parameter' {
            $cmd.Parameters['UserToUpdate'].Attributes.Mandatory | Should -Contain $True
        }

        It 'Password is type SecureString' {
            $cmd.Parameters['Password'].ParameterType.Name | Should -Be 'SecureString'
        }
    }
}

Describe 'Repository' {
    # A .gitignore pattern once hid Private/Test-CWCApiSecretConnection.ps1 (matched *secret*), so the
    # module only worked on machines that already had the file.
    It 'does not git-ignore any source, test, docs, build or example file' {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
        if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $RepoRoot '.git'))) {
            Set-ItResult -Skipped -Because 'git or the repository is not available'
            return
        }
        $SourceFolders = 'source', 'Tests', 'Docs', 'Build', '.build', 'Examples' |
            ForEach-Object { Join-Path $RepoRoot $_ } | Where-Object { Test-Path $_ }
        $SourceFiles = Get-ChildItem $SourceFolders -Recurse -File |
            ForEach-Object { $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/') }
        # Paths as arguments, not --stdin: piped lines carry a trailing CR on Windows, which defeats the patterns
        $Ignored = @(git -C $RepoRoot check-ignore --no-index -- $SourceFiles | Where-Object { $_ })
        $Ignored | Should -BeNullOrEmpty
    }
}

Describe 'Generated help' {
    BeforeAll {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
        $DocsPath = Join-Path $RepoRoot 'Docs'
    }

    It 'has a Docs page for <_>' -ForEach $ExpectedFunctions {
        Join-Path $DocsPath "$_.md" | Should -Exist -Because 'run ./Build/Update-Help.ps1 after adding a function'
    }

    # platyPS on PowerShell 7.4+ adds -ProgressAction to every page; Build/Update-Help.ps1 strips it.
    It 'does not document the -ProgressAction common parameter' {
        $Files = @(Get-ChildItem $DocsPath -Filter '*.md' | ForEach-Object FullName) +
            (Join-Path $RepoRoot 'source\en-US\ConnectWiseControlAPI-help.xml')
        @(Select-String -Path $Files -Pattern 'ProgressAction' | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) |
            Should -BeNullOrEmpty -Because 'run ./Build/Update-Help.ps1 to regenerate the help'
    }
}
