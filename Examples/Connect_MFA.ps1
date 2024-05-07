# Load module
Import-Module 'ConnectWiseControlAPI'


$ConnectSplat = @{
    Server = (Read-Host "Enter Control server domain without HTTPS (ie control.domain.com)")
    Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList (Read-Host "Enter Username"), (Read-Host "Enter Password" -AsSecureString)
    secret = (Read-Host "Enter your MFA secret (ie S7KDXWV7WSSEGALX)" -AsSecureString)
}
Connect-CWC @ConnectSplat

<#
    Non Interactive

    $ConnectSplat = @{
        Server = 'control.domain.com'
        Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, (ConvertTo-SecureString -String $password -AsPlainText -Force)
        secret = 'S7KDXWV7WSSEGALX' | ConvertTo-SecureString -AsPlainText
    }
    Connect-CWC @ConnectSplat
#>
