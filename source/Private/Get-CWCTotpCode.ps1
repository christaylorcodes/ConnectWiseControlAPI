function Get-CWCTotpCode {
    <#
    .SYNOPSIS
        Computes an RFC 6238 TOTP code (HMAC-SHA1, 30-second step) from a Base32 seed.

    .DESCRIPTION
        Pure function: the time is passed in, so callers and tests control it. Accepts the seed as
        ScreenConnect stores it for authenticator apps ("ms:<Base32>", e.g. from New-CWCMFA) or as bare Base32;
        case, spaces, dashes and '=' padding are ignored.

        The decoded key bytes are zeroed afterwards. The plain-text seed string taken from the
        SecureString can't be wiped (.NET strings are immutable); it is left for garbage collection.

    .PARAMETER Secret
        The TOTP seed.

    .PARAMETER UnixTime
        Seconds since 1970-01-01 UTC.

    .PARAMETER Digits
        Code length. ScreenConnect uses 6.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [securestring]$Secret,

        [Parameter(Mandatory = $True)]
        [int64]$UnixTime,

        [ValidateRange(6, 8)]
        [int]$Digits = 6
    )

    $Key = $null
    $Hash = $null
    $Hmac = $null
    try {
        $Key = Get-CWCTotpKey -Secret $Secret

        # The counter is the 30-second step number as a big-endian 64-bit integer
        $Counter = [BitConverter]::GetBytes([int64][math]::Floor($UnixTime / 30))
        if ([BitConverter]::IsLittleEndian) { [array]::Reverse($Counter) }

        # (,$Key) passes the byte array as one argument instead of one argument per byte
        $Hmac = New-Object System.Security.Cryptography.HMACSHA1 (, $Key)
        $Hash = $Hmac.ComputeHash($Counter)

        # Dynamic truncation (RFC 4226 section 5.3)
        $Offset = $Hash[$Hash.Length - 1] -band 0x0F
        $Binary = (([int64]($Hash[$Offset] -band 0x7F)) -shl 24) -bor
            (([int64]$Hash[$Offset + 1]) -shl 16) -bor
            (([int64]$Hash[$Offset + 2]) -shl 8) -bor
            ([int64]$Hash[$Offset + 3])
        $Modulus = [int64][math]::Pow(10, $Digits)
        ($Binary % $Modulus).ToString().PadLeft($Digits, '0')
    }
    finally {
        if ($Key) { [array]::Clear($Key, 0, $Key.Length) }
        if ($Hash) { [array]::Clear($Hash, 0, $Hash.Length) }
        if ($Hmac) { $Hmac.Dispose() }
    }
}
