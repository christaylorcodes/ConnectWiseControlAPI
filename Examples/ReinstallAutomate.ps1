# Your Control server URL
$Server = 'control.domain.com'

# Get Control credentials
$Credentials = Get-Credential

# Load module
Install-Module 'ConnectWiseControlAPI'
Import-Module 'ConnectWiseControlAPI'

# Save connection info
Connect-CWC -Server $Server -Credentials $Credentials

# Find this machine in Control
$Computer = Get-CWCSession -Type Access -Search $env:COMPUTERNAME -Limit 1

if(!$Computer) {return "Computer not found"}

# Issue a reinstall command against the machine
$Reinstall = @{
    # The session we want to run this command against
    GUID = $Computer.SessionID
    # Lets give this command some time to complete
    TimeOut = 120000
    # The command we want to issue to reinstall Automate
    Command = 'iwr -UseBasicParsing "https://bit.ly/LTPoSh" | iex;Redo-LTService -InstallerToken "MyToken123" -Backup'
    # Tell Control we are pushing a PowerShell command
    PowerShell = $true
}
Invoke-CWCCommand @Reinstall
