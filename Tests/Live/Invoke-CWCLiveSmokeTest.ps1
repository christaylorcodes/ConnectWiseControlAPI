<#
.SYNOPSIS
    Live smoke test against a real ScreenConnect server. Answers the questions the unit tests can't.

.DESCRIPTION
    Read-only by default. -AllowWrites adds actions on ONE test session you choose (a command, a note,
    a message, an optional toolbox item, a wake) and creates + deletes one throwaway Support session.
    -CleanupOnly is the other exception: it deletes the notes earlier runs left on the test session.

    Records results (no secrets, no headers) to a JSON file. Run once on PS 7 and once on PS 5.1.

    Questions it answers:
      - Connect-CWC works with a ViewSessionGroup-only role (#14)
      - Invoke-CWCCommand works over credentials, i.e. anti-forgery/cookies (#22), and queues event 44 / output 70
      - SessionEventType numbers (from the web client scripts, and from events produced by each action)
      - The RESTful API Manager's GetSessionDetailsBySessionID event Time format
      - PageService.CreateSession + Remove-CWCSession round trip

.EXAMPLE
    ./Tests/Live/Invoke-CWCLiveSmokeTest.ps1 -Server screenconnect.example.com -TestSessionID <guid>

.EXAMPLE
    ./Tests/Live/Invoke-CWCLiveSmokeTest.ps1 -Server screenconnect.example.com -TestSessionID <guid> -AllowWrites -ToolboxItem 'Test.ps1'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$Server,

    # An online Access session you're happy to run 'hostname' on and send a note/message to.
    [Parameter(Mandatory = $True)]
    [guid]$TestSessionID,

    [string]$Group = 'All Machines',

    [switch]$AllowWrites,

    # Name of an existing toolbox item to send (skipped when empty).
    [string]$ToolboxItem,

    # Test the MFA login (#12) with this account: Connect-CWC -Mfa (asks for the code), reads, the cached
    # reconnect and, with -AllowWrites, a note. Optionally Connect-CWC -TotpSecret and an expired login.
    [string]$MfaUserName,

    # With -MfaUserName: also record the raw TryLogin result for a missing and a wrong code. Each is a
    # failed login that counts toward the server's limits for the account.
    [switch]$MfaNegativeProbes,

    # With -AllowWrites: test the unattended TOTP login (Connect-CWC -TotpSecret). Creates a temporary
    # user with this role (it needs at least one permission, e.g. ViewSessionGroup) and a seed from
    # New-CWCMFA, logs in, checks the cached reconnect and an expired login, then deletes the user.
    [string]$TotpTestRole,

    # Only delete the notes earlier runs left on the test session, then exit.
    [switch]$CleanupOnly,

    [string]$OutputPath ="C:\Temp\cwc-smoke-ps$($PSVersionTable.PSVersion.Major).json"
)

$ErrorActionPreference = 'Stop'
# Module functions report failures with non-terminating Write-Error; make them fail the step.
$PSDefaultParameterValues['*-CWC*:ErrorAction'] = 'Stop'
# Unload every copy first (e.g. a Gallery install imported earlier), so the script tests this checkout only
Get-Module ConnectWiseControlAPI | Remove-Module -Force
$CWCModule = Import-Module (Join-Path $PSScriptRoot '..\..\source\ConnectWiseControlAPI.psd1') -Force -PassThru

$Results = [ordered]@{
    PSVersion   = $PSVersionTable.PSVersion.ToString()
    StartedUtc  = [DateTime]::UtcNow.ToString('o')
    AllowWrites = [bool]$AllowWrites
    Steps       = [ordered]@{}
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Script)
    Write-Host "== $Name" -ForegroundColor Cyan
    try {
        $Value = & $Script
        $Results.Steps[$Name] = [ordered]@{ Ok = $True; Value = $Value }
        Write-Host '   ok' -ForegroundColor Green
    }
    catch {
        $Results.Steps[$Name] = [ordered]@{ Ok = $False; Error = "$_" }
        Write-Host "   FAILED: $_" -ForegroundColor Red
    }
}

function Disconnect-Test { & $CWCModule { $script:CWCServerConnection = $null } }

# Events with only the fields we need; Data/Host trimmed so output stays small.
function Select-Event {
    param($Events)
    $Events | ForEach-Object {
        [ordered]@{
            EventType = $_.EventType
            # IDs show whether output events (70) point back at their command (44) via CorrelationEventID
            EventID   = $_.EventID
            CorrelationEventID = $_.CorrelationEventID
            Time      = $_.Time
            TimeType  = if ($null -ne $_.Time) { $_.Time.GetType().Name } else { $null }
            Host      = $_.Host
            Data      = if ($_.Data) { "$($_.Data)".Substring(0, [math]::Min(80, "$($_.Data)".Length)) } else { $null }
        }
    }
}

# Credentials-mode events that appeared since $SinceUtc.
function Get-NewEvent {
    param([datetime]$SinceUtc)
    $ElapsedMs = ([DateTime]::UtcNow - $SinceUtc).TotalMilliseconds + 500
    $Detail = Get-CWCSessionDetail -Group $Group -GUID $TestSessionID -Include Events
    Select-Event ($Detail.Events | Where-Object { [double]$_.Time -le $ElapsedMs })
}

# Notes this script added to the test session (any run) that are not deleted yet. The event numbers are
# written out (AddedNote 32, DeletedEvent 1) so this checks the server independently of the module.
function Get-OpenSmokeTestNote {
    $Events = @((Get-CWCSessionDetail -Group $Group -GUID $TestSessionID -Include Events).Events)
    $AlreadyDeleted = @($Events | Where-Object { $_.EventType -eq 1 } | ForEach-Object CorrelationEventID)
    @($Events | Where-Object {
        $_.EventType -eq 32 -and "$($_.Data)" -like 'CWC smoke test note*' -and $_.EventID -notin $AlreadyDeleted
    })
}

# Deletes every note this script added, with Remove-CWCSessionNote (so it is exercised live), and
# checks none remain. Needs a credentials connection and the RemoveNote permission.
function Remove-SmokeTestNote {
    $TestNotes = @(Get-OpenSmokeTestNote)
    if ($TestNotes.Count -gt 0) {
        Remove-CWCSessionNote -GUID $TestSessionID -Group $Group -NoteEventID ($TestNotes | ForEach-Object { [guid]$_.EventID }) -Confirm:$false
        Start-Sleep -Seconds 2
    }
    $Remaining = @(Get-OpenSmokeTestNote).Count
    if ($Remaining -gt 0) { throw "$Remaining smoke test note(s) still on session $TestSessionID" }
    [ordered]@{ Deleted = $TestNotes.Count; Remaining = $Remaining }
}

$AdminCredential = Get-Credential -Message 'Admin (non-MFA) ScreenConnect account'

if ($CleanupOnly) {
    Invoke-Step 'Creds.Connect' { Connect-CWC -Server $Server -Credentials $AdminCredential -Force; 'connected' }
    Invoke-Step 'Cleanup.RemoveTestNotes' { Remove-SmokeTestNote }
    Disconnect-Test
    $Results | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "`nResults: $OutputPath" -ForegroundColor Yellow
    return
}
$LimitedUserName = Read-Host -Prompt 'OPTIONAL: username of an account whose role has only ViewSessionGroup (Enter to skip)'
$LimitedCredential = if ($LimitedUserName) { Get-Credential -UserName $LimitedUserName -Message 'Limited account' } else { $null }
$ApiSecret = Read-Host -AsSecureString -Prompt 'OPTIONAL: RESTful API Manager secret (Enter to skip)'

#region Credentials, read-only
Invoke-Step 'Creds.Connect' { Connect-CWC -Server $Server -Credentials $AdminCredential -Force; 'connected' }

Invoke-Step 'Creds.SessionEventTypeEnum' {
    # The enum only exists in the web client's scripts; grab the text around each mention.
    $Connection = & $CWCModule { $script:CWCServerConnection }
    $Front = Invoke-WebRequest -Uri "https://$Server" -WebSession $Connection.WebSession -UseBasicParsing
    $ScriptUrls = [regex]::Matches($Front.Content, '<script[^>]+src="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -notmatch '^https?://' -or $_ -match [regex]::Escape($Server) }
    $Found = @()
    foreach ($Url in $ScriptUrls) {
        $Absolute = if ($Url -match '^https?://') { $Url } else { "https://$Server/$($Url.TrimStart('/'))" }
        $Content = (Invoke-WebRequest -Uri $Absolute -WebSession $Connection.WebSession -UseBasicParsing).Content
        if ($Content -is [byte[]]) { $Content = [Text.Encoding]::UTF8.GetString($Content) }
        foreach ($Match in [regex]::Matches($Content, 'SessionEventType')) {
            $Start = [math]::Max(0, $Match.Index - 100)
            $Found += [ordered]@{ Script = ($Url -replace '\?.*$', ''); Text = $Content.Substring($Start, [math]::Min(3000, $Content.Length - $Start)) }
            if ($Found.Count -ge 6) { break }
        }
        if ($Found.Count -ge 6) { break }
    }
    if (-not $Found) { throw "SessionEventType not found in $(@($ScriptUrls).Count) scripts" }
    $Found
}

Invoke-Step 'Creds.GetSession' { @(Get-CWCSession -Type Access -Group $Group -Limit 5).Count }
Invoke-Step 'Creds.GetSessionDetail' {
    $Detail = Get-CWCSessionDetail -Group $Group -GUID $TestSessionID -Include Events
    [ordered]@{ BaseTime = $Detail.BaseTime; Events = @(Select-Event ($Detail.Events | Select-Object -First 15)) }
}
Invoke-Step 'Creds.LastContact' { (Get-CWCLastContact -GUID $TestSessionID -Group $Group).ToString('o') }

# A wrong password must fail fast (no retries) with the login hint, and leave the module disconnected.
Invoke-Step 'Creds.WrongPasswordFailsFast' {
    $BadCredential = [pscredential]::new($AdminCredential.UserName, (ConvertTo-SecureString 'definitely-wrong-password' -AsPlainText -Force))
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    $Message = $null
    try { Connect-CWC -Server $Server -Credentials $BadCredential -WarningAction SilentlyContinue }
    catch { $Message = "$_" }
    $Timer.Stop()
    $Connected = [bool](& $CWCModule { $script:CWCServerConnection })
    if ($Timer.Elapsed.TotalSeconds -gt 10) { throw "Took $([int]$Timer.Elapsed.TotalSeconds) s; retries are still happening" }
    if ($Connected) { throw 'Still connected after a failed login to a different identity' }
    [ordered]@{ Seconds = [math]::Round($Timer.Elapsed.TotalSeconds, 1); MentionsLogin = $Message -match 'username and password' }
}
Invoke-Step 'Creds.ReconnectAfterWrongPassword' { Connect-CWC -Server $Server -Credentials $AdminCredential; 'connected' }
#endregion

#region Limited role (#14)
if ($LimitedCredential) {
    Disconnect-Test
    Invoke-Step 'Limited.Connect' { Connect-CWC -Server $Server -Credentials $LimitedCredential -Force; 'connected' }
    Invoke-Step 'Limited.GetSession' { @(Get-CWCSession -Type Access -Group $Group -Limit 5).Count }
}
#endregion

#region MFA login (#12)
# Login cookies without their values: name, lifetime and flags only
function Get-MfaCookieInfo {
    $Connection = & $CWCModule { $script:CWCServerConnection }
    @($Connection.WebSession.Cookies.GetCookies("https://$Server") | ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Name
                Session  = ($_.Expires -eq [datetime]::MinValue)
                Expires  = if ($_.Expires -ne [datetime]::MinValue) { $_.Expires.ToUniversalTime().ToString('o') } else { $null }
                Expired  = $_.Expired
                Secure   = $_.Secure
                HttpOnly = $_.HttpOnly
            }
        })
}
function Get-MfaConnectionInfo {
    $Connection = & $CWCModule { $script:CWCServerConnection }
    [pscustomobject]@{
        AuthType      = $Connection.AuthType
        HasAuthHeader = [bool]$Connection.Headers.authorization
        HasToken      = [bool]$Connection.Headers.'x-anti-forgery-token'
        HasPassword   = [bool]($Connection.Values | Where-Object { $_ -is [securestring] -or $_ -is [pscredential] })
    }
}

if ($MfaUserName) {
    $MfaCredential = Get-Credential -UserName $MfaUserName -Message 'MFA account'

    # Raw failed logins, to record the result codes. Off by default: each one counts toward the server's
    # login limits for this account.
    if ($MfaNegativeProbes) {
        function Invoke-RawTryLogin {
            param($OneTimeCode)
            $Page = Invoke-WebRequest -Uri "https://$Server" -UseBasicParsing -SessionVariable 'RawSession'
            $Match = [regex]::Match($Page.Content, 'antiForgeryToken":"([A-Za-z0-9+/=_-]{16,512})"')
            $Headers = @{ 'content-type' = 'application/json; charset=utf-8'; origin = "https://$Server" }
            if ($Match.Success) { $Headers['x-anti-forgery-token'] = $Match.Groups[1].Value }
            $Password = $MfaCredential.GetNetworkCredential().Password
            try {
                $Body = ConvertTo-Json -InputObject @($MfaUserName, $Password, $OneTimeCode, $False, $null)
                $Raw = (Invoke-WebRequest -Uri "https://$Server/Services/AuthenticationService.ashx/TryLogin" -Method Post -Headers $Headers -Body $Body -WebSession $RawSession -UseBasicParsing).Content
            }
            finally { Remove-Variable -Name Password, Body -ErrorAction SilentlyContinue }
            [pscustomobject]@{
                RawResponse = "$Raw"
                Cookies     = @($RawSession.Cookies.GetCookies("https://$Server") | ForEach-Object Name)
            }
        }
        Invoke-Step 'Mfa.Raw.TryLoginWithoutCode' { Invoke-RawTryLogin $null }
        Invoke-Step 'Mfa.Raw.TryLoginWrongCode' { Invoke-RawTryLogin '000000' }
    }

    # Interactive: Connect-CWC -Mfa asks for the code
    Disconnect-Test
    Invoke-Step 'Mfa.Connect' {
        Connect-CWC -Server $Server -Credentials $MfaCredential -Mfa
        Get-MfaConnectionInfo
    }
    Invoke-Step 'Mfa.Cookies' { Get-MfaCookieInfo }
    Invoke-Step 'Mfa.GetSession' { @(Get-CWCSession -Type Access -Group $Group -Limit 5).Count }
    Invoke-Step 'Mfa.GetSessionDetail' { @((Get-CWCSessionDetail -Group $Group -GUID $TestSessionID -Include Events).Events).Count }
    Invoke-Step 'Mfa.CachedReconnect' {
        # Same credentials again: must reuse the login (one check call, no new code)
        $Before = & $CWCModule { $script:CWCServerConnection }
        Connect-CWC -Server $Server -Credentials $MfaCredential -Mfa
        $After = & $CWCModule { $script:CWCServerConnection }
        if (-not [object]::ReferenceEquals($Before, $After)) { throw 'Logged in again instead of reusing the cached login' }
        'reused'
    }
    if ($AllowWrites) {
        Invoke-Step 'Mfa.AddNote' { $null = Add-CWCSessionNote -GUID $TestSessionID -Group $Group -Note 'CWC smoke test note (MFA login)'; 'sent' }
    }
}

# Unattended TOTP login with a temporary user whose seed this script creates (New-CWCMFA), then deletes.
if ($TotpTestRole -and $AllowWrites) {
    Disconnect-Test
    Invoke-Step 'Totp.AdminConnect' { Connect-CWC -Server $Server -Credentials $AdminCredential -Force; 'connected' }
    $TotpUserName = "cwc-smoke-totp-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
    $TotpMfa = New-CWCMFA -DisplayName 'CWC smoke test' -UserAccount $TotpUserName -Confirm:$False
    $TotpSeed = ConvertTo-SecureString $TotpMfa.OTP -AsPlainText -Force
    # Random password the server should accept: mixed case, digit, symbol
    $TotpPassword = ConvertTo-SecureString ("Sm0ke!" + [guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $TotpCredential = [pscredential]::new($TotpUserName, $TotpPassword)
    $TotpMfa = $null

    Invoke-Step 'Totp.CreateUser' {
        $null = New-CWCUser -Credentials $TotpCredential -OTP (& $CWCModule { param($s) ConvertFrom-CWCSecureString $s } $TotpSeed) `
            -DisplayName 'CWC smoke test (TOTP)' -Email 'cwc-smoke-totp@example.invalid' -SecurityGroups $TotpTestRole -ForcePassChange $False -Confirm:$False
        [pscustomobject]@{ UserName = $TotpUserName; Role = $TotpTestRole }
    }
    if ($Results.Steps['Totp.CreateUser'].Ok) {
        Disconnect-Test
        Invoke-Step 'Totp.Connect' {
            Connect-CWC -Server $Server -Credentials $TotpCredential -TotpSecret $TotpSeed
            Get-MfaConnectionInfo
        }
        if ($Results.Steps['Totp.Connect'].Ok) {
            Invoke-Step 'Totp.GetSession' { @(Get-CWCSession -Type Access -Group $Group -Limit 5).Count }
            Invoke-Step 'Totp.CachedReconnect' {
                $Before = & $CWCModule { $script:CWCServerConnection }
                Connect-CWC -Server $Server -Credentials $TotpCredential -TotpSecret $TotpSeed
                $After = & $CWCModule { $script:CWCServerConnection }
                if (-not [object]::ReferenceEquals($Before, $After)) { throw 'Logged in again instead of reusing the cached login' }
                'reused'
            }
            Invoke-Step 'Totp.ExpiredLoginHint' {
                # Log out on the server, as an expired login would behave
                & $CWCModule { Invoke-CWCLogout -Connection $script:CWCServerConnection }
                $Message = $null
                try { $null = Get-CWCSession -Type Access -Group $Group -Limit 5 } catch { $Message = "$_" }
                if (-not $Message) { throw 'Requests still worked after logout' }
                [pscustomobject]@{ MentionsExpiredLogin = $Message -match 'MFA login has expired'; Message = $Message.Substring(0, [math]::Min(200, $Message.Length)) }
            }
            Invoke-Step 'Totp.ReconnectAfterLogout' {
                # Same 30-second step was just used: the module must wait for a fresh code
                $Timer = [Diagnostics.Stopwatch]::StartNew()
                $Before = & $CWCModule { $script:CWCServerConnection }
                Connect-CWC -Server $Server -Credentials $TotpCredential -TotpSecret $TotpSeed
                $After = & $CWCModule { $script:CWCServerConnection }
                if ([object]::ReferenceEquals($Before, $After)) { throw 'Kept the logged-out login' }
                [pscustomobject]@{ Sessions = @(Get-CWCSession -Type Access -Group $Group -Limit 5).Count; Seconds = [math]::Round($Timer.Elapsed.TotalSeconds, 1) }
            }
        }

        # Always delete the temporary user
        Disconnect-Test
        Invoke-Step 'Totp.RemoveUser' {
            Connect-CWC -Server $Server -Credentials $AdminCredential -Force
            $null = Remove-CWCUser -User $TotpUserName -Confirm:$False
            'removed'
        }
    }
    Remove-Variable -Name TotpSeed, TotpPassword, TotpCredential -ErrorAction SilentlyContinue
}
#endregion

#region API secret, read-only
if ($ApiSecret.Length -gt 0) {
    Disconnect-Test
    Invoke-Step 'Api.Connect' { Connect-CWC -Server $Server -ApiSecret $ApiSecret -Force; 'connected' }
    Invoke-Step 'Api.FindSession' { @(Find-CWCSession -GUID $TestSessionID).Count }
    Invoke-Step 'Api.GetSessionDetail' {
        $Detail = Get-CWCSessionDetail -GUID $TestSessionID
        [ordered]@{
            TopLevelProperties = @($Detail.PSObject.Properties.Name)
            BaseTime           = $Detail.BaseTime
            Events             = @(Select-Event ($Detail.Events | Select-Object -First 15))
        }
    }
}
#endregion

#region Writes
if ($AllowWrites) {
    if ($ApiSecret.Length -gt 0) {
        # API-secret-only actions; read the resulting event types back over credentials.
        $Since = [DateTime]::UtcNow
        Invoke-Step 'Api.AddNote' { Add-CWCSessionNote -GUID $TestSessionID -Note 'CWC smoke test note'; 'sent' }
        Invoke-Step 'Api.SendMessage' { Send-CWCSessionMessage -GUID $TestSessionID -Message 'CWC smoke test message'; 'sent' }
        if ($ToolboxItem) { Invoke-Step 'Api.SendToolboxItem' { Send-CWCToolboxItem -GUID $TestSessionID -Name $ToolboxItem; 'sent' } }
        Invoke-Step 'Api.CommandQueue' { Invoke-CWCCommand -GUID $TestSessionID -Command 'hostname' 3>$null; 'queued' }
        Start-Sleep -Seconds 5
        Invoke-Step 'Api.EventsAfterActions' {
            $Detail = Get-CWCSessionDetail -GUID $TestSessionID
            @(Select-Event ($Detail.Events | Select-Object -First 15))
        }
    }

    Disconnect-Test
    Invoke-Step 'Creds.Reconnect' { Connect-CWC -Server $Server -Credentials $AdminCredential -Force; 'connected' }
    if ($ApiSecret.Length -gt 0) { Invoke-Step 'Creds.EventsFromApiActions' { @(Get-NewEvent -SinceUtc $Since) } }

    $Since = [DateTime]::UtcNow
    Invoke-Step 'Creds.AddNote' { $null = Add-CWCSessionNote -GUID $TestSessionID -Group $Group -Note 'CWC smoke test note (credentials)'; 'sent' }
    Invoke-Step 'Creds.SendMessage' { $null = Send-CWCSessionMessage -GUID $TestSessionID -Group $Group -Message 'CWC smoke test message (credentials)'; 'sent' }
    if ($ToolboxItem) { Invoke-Step 'Creds.SendToolboxItem' { $null = Send-CWCToolboxItem -GUID $TestSessionID -Group $Group -Name $ToolboxItem; 'sent' } }
    Start-Sleep -Seconds 2
    Invoke-Step 'Creds.EventsFromNoteMessageTool' { @(Get-NewEvent -SinceUtc $Since) }

    $Since = [DateTime]::UtcNow
    Invoke-Step 'Creds.InvokeCommand' { Invoke-CWCCommand -GUID $TestSessionID -Group $Group -Command 'hostname' -TimeOut 60000 }
    Invoke-Step 'Creds.EventsFromCommand' { @(Get-NewEvent -SinceUtc $Since) }

    $Since = [DateTime]::UtcNow
    Invoke-Step 'Creds.Wake' { $null = Invoke-CWCWake -GUID $TestSessionID -Type Access; 'sent' }
    Start-Sleep -Seconds 2
    Invoke-Step 'Creds.EventsFromWake' { @(Get-NewEvent -SinceUtc $Since) }

    Invoke-Step 'Creds.CreateAndRemoveSession' {
        $Name = "cwc-smoke-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
        $Created = New-CWCSession -Type Support -Name $Name
        $NewID = if ($Created.SessionID) { $Created.SessionID } else { "$Created".Trim('"') }
        $FoundAfterCreate = @(Get-CWCSession -Type Support -Group 'All Sessions' -Search $Name).Count
        $null = Remove-CWCSession -GUID $NewID -Group 'All Sessions' -Confirm:$False
        Start-Sleep -Seconds 2
        $FoundAfterRemove = @(Get-CWCSession -Type Support -Group 'All Sessions' -Search $Name).Count
        if ($FoundAfterRemove -ne 0) { throw "Session $NewID ($Name) still listed after Remove-CWCSession; delete it by hand." }
        [ordered]@{ Name = $Name; Created = $Created; FoundAfterCreate = $FoundAfterCreate; FoundAfterRemove = $FoundAfterRemove }
    }

    # Last: remove the notes this run (and any earlier run) added, including the API-secret and MFA ones.
    Invoke-Step 'Cleanup.RemoveTestNotes' { Remove-SmokeTestNote }
}
#endregion

Disconnect-Test
$Results | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "`nResults: $OutputPath" -ForegroundColor Yellow
