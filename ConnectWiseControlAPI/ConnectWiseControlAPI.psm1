#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue -Recurse )

#Dot source the files
Foreach($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    } Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Set Security Protocol to TLS 1.2+
if([Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

$script:InternalUserSource = 'InternalMembershipProvider'

# ScreenConnect.SessionType values (verified against ScreenConnect.Core.dll)
$script:CWCSessionType = @{ Support = 0; Meeting = 1; Access = 2 }

# ScreenConnect.SessionEventType values used by this module (verified live from the web client's
# SC.types.SessionEventType, 2026-11-10)
$script:CWCSessionEventType = @{
    DeletedEvent             = 1
    Connected                = 10
    Disconnected             = 11
    DeletedSession           = 21
    AddedNote                = 32
    QueuedWake               = 43
    QueuedCommand            = 44
    QueuedMessage            = 45
    QueuedTool               = 47
    QueuedForceDisconnect    = 48
    RanCommand               = 70
    QueuedUninstallAndDelete = 100
}

# Remote Workforce extension ID (App_Extensions/<ID>/Service.ashx)
$script:CWCRemoteWorkforceExtensionID = '2c4f522f-b39a-413a-8807-dc52a2fce13e'

# RESTful API Manager extension ID, used by Connect-CWC -ApiSecret
$script:CWCRestApiExtensionID = '2d558935-686a-4bd0-9991-07539f5fe749'

# Export Public functions ($Public.BaseName) for WIP modules
Export-ModuleMember -Function $Public.Basename