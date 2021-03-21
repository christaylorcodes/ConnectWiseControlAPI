function New-CWCMFA {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
    param(
        $DisplayName = 'CW Control',
        $UserAccount
    )
    $Possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    $Key = ''
    while ($Key.Length -lt 16) {
        $Key += $Possible.ToCharArray() | Get-Random
    }

    $otpauth = "otpauth://totp/$($DisplayName):$($UserAccount)?secret=$Key"
    Add-Type -AssemblyName System.Web
    $otpauthEncoded = [System.Web.HTTPUtility]::UrlEncode($otpauth)
    $qrUrl = "https://chart.googleapis.com/chart?cht=qr&chs=300x300&chl=$($otpauthEncoded)&chld=H|0"
    if ($PSCmdlet.ShouldProcess("New-CWCMFA")) {
        [pscustomobject]@{
            'QR' = $qrUrl
            'OTP' = "ms:$Key"
        }
    }
}