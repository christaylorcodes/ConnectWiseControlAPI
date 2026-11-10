function Get-CWCIdentityHash {
    <#
    .SYNOPSIS
        Salted SHA-256 of a username and password, so Connect-CWC can tell whether a cached MFA login
        belongs to the same credentials without keeping the password.

    .DESCRIPTION
        The salt is random per module load and never leaves memory, so the hash can't be compared
        against hashes from anywhere else.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [pscredential]$Credentials
    )

    if (-not $script:CWCIdentitySalt) {
        $Salt = New-Object byte[] 32
        $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try { $Rng.GetBytes($Salt) } finally { $Rng.Dispose() }
        $script:CWCIdentitySalt = [Convert]::ToBase64String($Salt)
    }

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        # Usernames are case-insensitive in Control; passwords are not
        $Text = "$($script:CWCIdentitySalt)`n$($Credentials.UserName.ToLowerInvariant())`n$($Credentials.GetNetworkCredential().Password)"
        [Convert]::ToBase64String($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))
    }
    finally {
        $Sha.Dispose()
    }
}
