function Get-CWCLastContact {
    [CmdletBinding()]
    [OutputType([boolean], ParameterSetName = ('Quiet'))]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $True)]
        [guid]$GUID,
        [parameter(ParameterSetName = 'Quiet')]
        [switch]$Quiet,
        [int]$Seconds,
        [string]$Group = 'All Machines'
    )

    # Time conversion
    $origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
    $epoch = $((New-TimeSpan -Start $(Get-Date -Date '01/01/1970') -End $(Get-Date)).TotalSeconds)

    try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID }
    catch { return $_ }

    if ($SessionDetails -eq 'null' -or !$SessionDetails) {
        Write-Warning 'Machine not found.'
        return $null
    }

    $GuestSessionEvents = $SessionDetails.Events
    $GuestSessionConnections = $SessionDetails.Connections | Where-Object { $_.ParticipantName }

    if ($GuestSessionEvents) {

        # Get connection events
        $LatestEvent = $GuestSessionEvents | Where-Object {
            $_.EventType -in (10, 11) -and
            $_.ConnectionID -NotIn $GuestSessionConnections.ConnectionID
        } | Sort-Object time | Select-Object -First 1
        if ($LatestEvent.EventType -eq 10) {
            # Currently connected
            if ($Quiet) { return $True }
            else { return Get-Date }
        }
        else {
            # Time conversion hell :(
            $TimeDiff = $epoch - ($LatestEvent.Time / 1000)
            $OfflineTime = $origin.AddSeconds($TimeDiff)
            $Difference = New-TimeSpan -Start $OfflineTime -End $(Get-Date)
            if ($Quiet -and $Difference.TotalSeconds -lt $Seconds) { return $True }
            elseif ($Quiet) { return $False }
            else { return $OfflineTime }
        }
    }
    else { return Write-Error 'Unable to determine last contact.' }
}