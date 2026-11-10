function ConvertFrom-CWCBase32 {
    <#
    .SYNOPSIS
        Decodes RFC 4648 Base32 text to bytes. Ignores case, whitespace, dashes and '=' padding.
        Errors never echo the input (it is a secret).
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $True)]
        [AllowEmptyString()]
        [string]$Text
    )

    $Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    $Clean = ($Text -replace '[\s=-]', '').ToUpperInvariant()
    $Length = [int][math]::Floor($Clean.Length * 5 / 8)
    if ($Length -eq 0) { throw 'The TOTP secret is empty or too short.' }

    $Bytes = New-Object byte[] $Length
    $Index = 0
    $Buffer = 0
    $Bits = 0
    foreach ($Char in $Clean.ToCharArray()) {
        $Value = $Alphabet.IndexOf($Char)
        if ($Value -lt 0) {
            [array]::Clear($Bytes, 0, $Bytes.Length)
            throw 'The TOTP secret is not valid Base32 (letters A-Z and digits 2-7, optionally prefixed with "ms:").'
        }
        $Buffer = ($Buffer -shl 5) -bor $Value
        $Bits += 5
        if ($Bits -ge 8) {
            $Bits -= 8
            if ($Index -lt $Length) { $Bytes[$Index] = [byte](($Buffer -shr $Bits) -band 0xFF) }
            $Index++
            # Keep only the bits not yet written
            $Buffer = $Buffer -band ((1 -shl $Bits) - 1)
        }
    }
    , $Bytes
}
