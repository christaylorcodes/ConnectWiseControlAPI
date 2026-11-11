@{
    Gallery              = 'PSGallery'
    AllowPrerelease      = $false
    WithYAML             = $true

    # Resolve dependencies with PSResourceGet (ships with PowerShell 7.4+) instead of
    # the legacy PowerShellGet v2. Version ranges in RequiredModules.psd1 require this.
    UsePSResourceGet     = $true
    PSResourceGetVersion = '1.2.0'
}
