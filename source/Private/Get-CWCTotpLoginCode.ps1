function Get-CWCTotpLoginCode {
    <#
    .SYNOPSIS
        The TOTP code to send for one login, waiting for a fresh time step when needed.

    .DESCRIPTION
        Waits for the next 30-second step when:
        - fewer than 3 seconds are left in this one, so the code doesn't expire in flight;
        - this step was already sent for the same server and user ($script:CWCLastTotpStep, set by the
          caller once the server has seen the code), because the server may reject a reused code.
        Returns the code and its step number. Only step numbers are remembered (not secret); the code
        and the seed are never stored.

    .PARAMETER Key
        Identifies the server and user, lowercase, e.g. "server|user".
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $True)]
        [securestring]$Secret,

        [Parameter(Mandatory = $True)]
        [string]$Key
    )

    if (-not $script:CWCLastTotpStep) { $script:CWCLastTotpStep = @{} }

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

    [pscustomobject]@{
        Code = Get-CWCTotpCode -Secret $Secret -UnixTime $Now
        Step = $Step
    }
}
