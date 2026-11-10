function Get-CWCTotpLoginCode {
    <#
    .SYNOPSIS
        The TOTP code to send for one login, waiting for a fresh time step when needed.

    .DESCRIPTION
        Waits for the next 30-second step when:
        - fewer than 3 seconds are left in this one, so the code doesn't expire in flight;
        - this step was already used for the same server and user, because the server may reject a
          code it has already accepted.
        Only the step number is remembered (not secret); the code and the seed are never stored.

    .PARAMETER Key
        Identifies the server and user, e.g. "server|user".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [securestring]$Secret,

        [Parameter(Mandatory = $True)]
        [string]$Key
    )

    if (-not $script:CWCLastTotpStep) { $script:CWCLastTotpStep = @{} }
    $Key = $Key.ToLowerInvariant()

    $Now = Get-CWCUnixTime
    $Remaining = 30 - ($Now % 30)
    $Step = [int64][math]::Floor($Now / 30)
    if ($Remaining -lt 3 -or $script:CWCLastTotpStep[$Key] -eq $Step) {
        Write-Verbose "Waiting $Remaining s for a new one-time code."
        Start-Sleep -Seconds $Remaining
        # Computed rather than read again, so the result doesn't depend on how long the sleep took
        $Now += $Remaining
        $Step++
    }

    $script:CWCLastTotpStep[$Key] = $Step
    Get-CWCTotpCode -Secret $Secret -UnixTime $Now
}
