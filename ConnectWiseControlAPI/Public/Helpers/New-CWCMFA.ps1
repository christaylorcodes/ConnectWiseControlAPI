function New-CWCMFA {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
    param(
        $DisplayName = 'CW Control',
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