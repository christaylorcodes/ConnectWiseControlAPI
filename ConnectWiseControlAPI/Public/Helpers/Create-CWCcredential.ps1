Function Create-CWCcredential {
    $ConnectSplat = @{
        Server = (Read-Host "Enter Control server domain without HTTPS (ie control.domain.com)")
        Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList (Read-Host "Enter Username"), (Read-Host "Enter Password" -AsSecureString)
        secret = (Read-Host "Enter your MFA secret (ie S7KDXWV7WSSEGALX). Hit enter for none" -AsSecureString)
    }
    Return $ConnectSplat
}