function Get-CWCTotpKey {
    <#
    .SYNOPSIS
        Decodes a TOTP secret to its key bytes. The caller zeroes the returned array.

    .DESCRIPTION
        Accepts the forms people have the secret in:
        - Base32, optionally with spaces, dashes or '=' padding, in any case;
        - with a "<name>:" prefix, as Control stores it (e.g. "ms:<Base32>" from New-CWCMFA);
        - an otpauth:// link (the QR code's content), using its secret= value.
        Errors never include the secret.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $True)]
        [securestring]$Secret
    )

    $Text = (ConvertFrom-CWCSecureString $Secret).Trim()
    if ($Text -match '^otpauth://') {
        $Match = [regex]::Match($Text, '[?&]secret=([^&#]+)', 'IgnoreCase')
        if (-not $Match.Success) { throw 'The TOTP secret is an otpauth:// link without a secret= value.' }
        $Text = [uri]::UnescapeDataString($Match.Groups[1].Value)
    }
    # Base32 has no ':', so any leading "name:" is a type prefix
    $Text = $Text -replace '^[A-Za-z]+:', ''
    , (ConvertFrom-CWCBase32 -Text $Text)
}
