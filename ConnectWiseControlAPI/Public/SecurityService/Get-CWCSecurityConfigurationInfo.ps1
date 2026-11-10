function Get-CWCSecurityConfigurationInfo {
    [CmdletBinding()]
    param ()

    Invoke-CWCServiceMethod -Service SecurityService -Method GetSecurityConfigurationInfo -Idempotent
}
