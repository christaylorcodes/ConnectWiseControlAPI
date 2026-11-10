<#
    This script searches for multiple access sessions for the same machine,
    and removes all but the last connected one.
    This only looks at the session name for uniqueness. If you have multiple machines with the same name this will not work as expected.
    You will need to get session details to further determine uniqueness.
#>

# Your Control server URL
$Server = 'control.domain.com'

# Get Control credentials
$Credentials = Get-Credential

# Set GroupName to Search in
$GroupName = 'All Machines'

# Activate Confirmation
[Switch]$Confirm = $true

# Activate WhatIf
[Switch]$WhatIf = $true

# Load module
Import-Module 'ConnectWiseControlAPI'

# Save connection info
Connect-CWC -Server $Server -Credentials $Credentials

# Search for multiple sessions for the same machine, and collect all but the last connected one
$RedundantSessionColl = Get-CWCSession -Type Access -Group $GroupName |
Group-Object -Property Name |
Where-Object -Property Count -gt 1 |
ForEach-Object {
    # LastConnectedEventTime is seconds since the last connection: smallest first, so Skip 1 keeps
    # the most recently connected session
    # A session that never connected (no time) sorts last, so it is never the one kept
    $_.Group | Sort-Object -Property { if ($null -eq $_.LastConnectedEventTime) { [double]::MaxValue } else { [double]$_.LastConnectedEventTime } } |
    Select-Object -Skip 1
}

# Remove Redundant Sessions
$RemovedSessionColl = foreach ($RedundantSession in $RedundantSessionColl)
{
    $RemoveCWCSessionProps = @{
        GUID    = $RedundantSession.SessionID
        Group   = $GroupName
        Confirm = $Confirm
        WhatIf  = $WhatIf
    }
    Remove-CWCSession @RemoveCWCSessionProps
}

# Output Result
$RemovedSessionColl