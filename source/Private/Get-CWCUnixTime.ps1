function Get-CWCUnixTime {
    <#
    .SYNOPSIS
        Seconds since 1970-01-01 UTC. Its own function so tests can mock the clock.
        (DateTimeOffset.ToUnixTimeSeconds needs .NET 4.6.)
    #>
    [CmdletBinding()]
    [OutputType([int64])]
    param()

    $Epoch = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
    [int64][math]::Floor(([DateTime]::UtcNow - $Epoch).TotalSeconds)
}
