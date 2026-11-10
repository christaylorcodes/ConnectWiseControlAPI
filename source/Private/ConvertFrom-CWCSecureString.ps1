function ConvertFrom-CWCSecureString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [securestring]$SecureString
    )

    # Convert to plain text for API request bodies, zeroing the unmanaged copy afterwards
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}
