# Combining Get-CWCLastContact and Getting session details. Since we are calling GetSessilDetails anyways, may as well return some of its other useful information
function Get-CWCSessionDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)][guid]$GUID,
        [int]$Seconds,
        [string]$Group = $script:defaultGroup
    )

    $Endpoint = 'Services/PageService.ashx/GetSessionDetails'
    $Body = ConvertTo-Json @($Group,$GUID)
    Write-Verbose $Body

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Body = $Body
        Method = 'Post'
    }

    Try { $SessionDetails = Invoke-CWCWebRequest -Arguments $WebRequestArguments }
    Catch { Return $_ }
    if ($SessionDetails -eq 'null' -or !$SessionDetails) {
        Throw 'Machine not found - No Session details returned.'
    }
    $result = $SessionDetails.Session    
    
    # Time conversion
    $epoch = Get-EpochNow
    
    $GuestSessionEvents = $SessionDetails.Events
    $GuestSessionConnections = $SessionDetails.Connections | Where-Object { $_.ParticipantName }
    $online = $false
    if ($GuestSessionEvents) {
        # Get connection events
        $LatestEvent = $GuestSessionEvents | Where-Object {
            $_.EventType -in (10, 11) -and
            $_.ConnectionID -NotIn $GuestSessionConnections.ConnectionID
        } | Sort-Object time | Select-Object -First 1
        if ($LatestEvent.EventType -eq 10) {
            # Currently connected
            $lastContact = Get-Date
            $online = $true
        } else {
            # Currently Offline. why does CWC count event time in milliseconds...?
            $lastContact = ($epoch - ($LatestEvent.Time / 1000)) | Convert-FromEpoch
        }
    } else { 
        $lastContact = $null
    }
    
    Return [PSCustomObject] @{
        HostName = $SessionDetails.Session.GuestMachineName
        SessionID = $GUID
        Online = $online
        LastContact = $lastContact
        LastBootTime = ($epoch - $SessionDetails.Session.GuestLastBootTime) | Convert-FromEpoch
        LastInfoUpdateTime = ($epoch - $SessionDetails.Session.GuestInfoUpdateTime) | Convert-FromEpoch
        TimeZone = $SessionDetails.Session.GuestTimeZoneName
        TimeZoneOffset = $SessionDetails.Session.GuestTimeZoneOffsetHours
        wanIP = $SessionDetails.Session.GuestNetworkAddress
        lanIP = $SessionDetails.Session.GuestPrivateNetworkAddress 
        lanMAC = $SessionDetails.Session.GuestHardwareNetworkAddress
        CPUtype = $SessionDetails.Session.GuestProcessorName
        CPUarch = $SessionDetails.Session.GuestProcessorArchitecture
        CPUcount = $SessionDetails.Session.GuestProcessorVirtualCount
        RAM_Megabytes = $SessionDetails.Session.GuestSystemMemoryTotalMegabytes
        MachineMake = $SessionDetails.Session.GuestMachineManufacturerName
        MachineModel = $SessionDetails.Session.GuestMachineModel
        MachineProductNumber = $SessionDetails.Session.GuestMachineProductNumber
        MachineSerialNumber = $SessionDetails.Session.GuestMachineSerialNumber
    }
}