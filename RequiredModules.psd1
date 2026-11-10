@{
    PSDependOptions       = @{
        AddToPath  = $true
        Target     = 'output/RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    # Versions use NuGet range syntax (passed to Save-PSResource -Version):
    #   '[5.7.1,6.0.0)' = 5.7.1 or newer, below 6.0.0 (newest match wins)
    # .build/required-modules.ps1 (task Assert_RequiredModule_Versions) fails the build if a resolved
    # version falls outside its range.

    # Bounded: breaking changes have landed (or would land) in these
    Sampler               = '[0.120.1,0.121.0)'  # 0.x: minor versions may break tasks
    ModuleBuilder         = '[3.2.18,4.0.0)'
    # Exact: same versions as the env: block in .github/workflows/ci.yml, so a local run matches CI.
    # Pester 5 and platyPS 0.14 (not the template's Pester 6 / PlatyPS 1.x): the suite runs on Windows
    # PowerShell 5.1 and Build/Update-Help.ps1 produces MAML for Get-Help on 5.1. See AGENTS.md.
    Pester                = '5.7.1'
    PSScriptAnalyzer      = '1.24.0'
    platyPS               = '0.14.2'

    # Floating: low risk (build tooling only)
    InvokeBuild           = 'latest'
    'powershell-yaml'     = 'latest'
}
