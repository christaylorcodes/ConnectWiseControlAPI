function New-CWCMFA {
    <#
    .SYNOPSIS
        Creates a new authenticator-app (TOTP) secret for a ScreenConnect user.

    .DESCRIPTION
        Generates a random 16-character Base32 secret. Returns it in the form ScreenConnect stores ("ms:<secret>")
        together with a QR code URL to scan with an authenticator app. Nothing is sent to the ScreenConnect
        server: pass the OTP value to New-CWCUser or Update-CWCUser to set it on an account.

        The QR code URL is on quickchart.io and contains the secret. Open it only if you accept sending the
        secret to that service.

    .PARAMETER DisplayName
        Label the authenticator app shows for the entry. Defaults to 'ScreenConnect'.

    .PARAMETER UserAccount
        Account name the authenticator app shows for the entry.

    .EXAMPLE
        $Mfa = New-CWCMFA -UserAccount 'jdoe'
        $Mfa.OTP

        Creates a secret for jdoe and shows the value to store on the account.

    .OUTPUTS
        PSCustomObject with QR (URL of the QR code image) and OTP ("ms:" followed by the secret).

    .NOTES
        Works without a connection.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
    param(
        $DisplayName = 'ScreenConnect',
        $UserAccount
    )
    $Possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    $Key = (1..16 | ForEach-Object { $Possible.ToCharArray() | Get-Random }) -join ''

    $otpauth = "otpauth://totp/$($DisplayName):$($UserAccount)?secret=$($Key)"
    Add-Type -AssemblyName System.Web
    $otpauthEncoded = [System.Web.HTTPUtility]::UrlEncode($otpauth)
    $qrUrl = "https://quickchart.io/chart?cht=qr&chs=400x400&chl=$($otpauthEncoded)&chld=L"
    if ($PSCmdlet.ShouldProcess('New-CWCMFA')) {
        [pscustomobject]@{
            'QR'  = $qrUrl
            'OTP' = "ms:$Key"
        }
    }
}