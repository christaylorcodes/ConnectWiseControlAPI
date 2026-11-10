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

    # Relies on PageService's elapsed-milliseconds event times; the RESTful API Manager returns raw DateTimes.
    if (Test-CWCApiSecretConnection) {
        return Write-Error "Get-CWCLastContact is not available when connected with -ApiSecret (RESTful API Manager). Connect with 'Connect-CWC -Credentials' to use it."
    }

    try { $SessionDetails = Get-CWCSessionDetail -Group $Group -GUID $GUID -Include 'Events', 'Connections' -ErrorAction Stop }
    catch {
        Write-Error $_
        return
    }

    if ($SessionDetails -eq 'null' -or !$SessionDetails) {
        Write-Warning 'Machine not found.'
        return $null
    }

    $GuestSessionEvents = $SessionDetails.Events
    $GuestSessionConnections = $SessionDetails.Connections | Where-Object { $_.ParticipantName }

    if ($GuestSessionEvents) {

        # Get connection events
        $LatestEvent = $GuestSessionEvents | Where-Object {
            $_.EventType -in ($script:CWCSessionEventType.Connected, $script:CWCSessionEventType.Disconnected) -and
            $_.ConnectionID -NotIn $GuestSessionConnections.ConnectionID
        } | Sort-Object { [double]$_.Time } | Select-Object -First 1
        if (-not $LatestEvent) { return Write-Error 'Unable to determine last contact.' }
        if ($LatestEvent.EventType -eq $script:CWCSessionEventType.Connected) {
            # Currently connected
            if ($Quiet) { return $True }
            else { return Get-Date }
        }
        else {
            $LastContactUtc = ConvertFrom-CWCEventTime -SessionEvent $LatestEvent
            $SecondsSinceContact = ([DateTime]::UtcNow - $LastContactUtc).TotalSeconds
            $OfflineTime = $LastContactUtc.ToLocalTime()
            if ($Quiet -and $SecondsSinceContact -lt $Seconds) { return $True }
            elseif ($Quiet) { return $False }
            else { return $OfflineTime }
        }
    }
    else { return Write-Error 'Unable to determine last contact.' }
}