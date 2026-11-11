# Your ScreenConnect server URL
$Server = 'screenconnect.domain.com'

# Get ScreenConnect credentials
$Credentials = Get-Credential

# Load module
Install-Module 'ConnectWiseControlAPI'
Import-Module 'ConnectWiseControlAPI'

# Save connection info
Connect-CWC -Server $Server -Credentials $Credentials

# Find this machine in ScreenConnect
$Computer = Get-CWCSession -Type Access -Search $env:COMPUTERNAME -Limit 1

if(!$Computer){ return "Computer not found" }

# We now have some basic information about this session
$Computer

# We can use this to issue other command like getting the machines last contact
Get-CWCLastContact -GUID $Computer.SessionID