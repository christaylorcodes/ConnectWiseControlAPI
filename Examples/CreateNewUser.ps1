# Your ScreenConnect server URL
$Server = 'screenconnect.domain.com'

# Get ScreenConnect credentials (an account that can manage users)
$Credentials = Get-Credential

# Load module
Install-Module 'ConnectWiseControlAPI'
Import-Module 'ConnectWiseControlAPI'

# Save connection info
Connect-CWC -Server $Server -Credentials $Credentials

# The user to create
$UserName = 'jdoe'
$Email = 'jdoe@domain.com'
$DisplayName = 'John Doe'

# User name and first password of the new user
$NewUserCredentials = Get-Credential -UserName $UserName -Message 'Password for the new user'

# Generate an authenticator-app (TOTP) secret for the user. Nothing is sent to the server yet.
$MFA = New-CWCMFA -UserAccount $UserName

$NewUser = @{
    Credentials    = $NewUserCredentials
    Email          = $Email
    DisplayName    = $DisplayName
    # Sets the secret on the account, so the user signs in with a code from their authenticator app
    OTP            = $MFA.OTP
    # The role(s) the user gets. This one is created by Add-CWCRemoteWorkforceRequiredRole
    SecurityGroups = 'Remote Workforce'
}
# The user must change the password at first login (pass -ForcePassChange $false to turn that off)
New-CWCUser @NewUser

# You now have a new Remote Workforce user with MFA enabled.
# The user adds the secret to an authenticator app by scanning a QR code. This URL shows one, but it is on
# quickchart.io and contains the secret: open it only if you accept sending the secret to that service.
$MFA.QR
