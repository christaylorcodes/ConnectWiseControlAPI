@{
    PSDependOptions       = @{
        AddToPath  = $true
        Target     = 'output/RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    # Every version is exact. These modules build, test and document the package that is published, and a
    # Gallery version can never be replaced, so an exact version is also a pin on the content. Raise a pin on
    # purpose, in a pull request, and delete output/RequiredModules to resolve again.
    # .build/required-modules.ps1 (task Assert_RequiredModule_Versions) fails the build if a resolved version
    # is not the pinned one. This file is the only place the versions are written: CI, the release workflow
    # and Tests/test-local.ps1 all read it.
    # Not pinned here: the modules these depend on (Configuration, Metadata, Plaster, PSDepend).

    # Build
    Sampler               = '0.120.1'
    ModuleBuilder         = '3.2.18'  # writes the built .psm1 and .psd1
    InvokeBuild           = '5.14.23'
    'powershell-yaml'     = '0.4.12'

    # Test and docs. Pester 5 and platyPS 0.14 (not the template's Pester 6 / PlatyPS 1.x): the suite runs on
    # Windows PowerShell 5.1 and Build/Update-Help.ps1 produces MAML. See AGENTS.md.
    Pester                = '5.7.1'
    PSScriptAnalyzer      = '1.24.0'
    platyPS               = '0.14.2'
}
