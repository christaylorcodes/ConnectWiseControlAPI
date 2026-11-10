<#
.SYNOPSIS
    Live smoke test against a real Control server. Answers the questions the unit tests can't.

.DESCRIPTION
    Read-only by default. -AllowWrites adds actions on ONE test session you choose (a command, a note,
    a message, an optional toolbox item, a wake) and creates + deletes one throwaway Support session.

    Records results (no secrets, no headers) to a JSON file. Run once on PS 7 and once on PS 5.1.

    Questions it answers:
      - Connect-CWC works with a ViewSessionGroup-only role (#14)
      - Invoke-CWCCommand works over credentials, i.e. anti-forgery/cookies (#22), and queues event 44 / output 70
      - SessionEventType numbers (from the web client scripts, and from events produced by each action)
      - The RESTful API Manager's GetSessionDetailsBySessionID event Time format
      - PageService.CreateSession + Remove-CWCSession round trip

.EXAMPLE
    ./Tests/Live/Invoke-CWCLiveSmokeTest.ps1 -Server control.example.com -TestSessionID <guid>

.EXAMPLE
    ./Tests/Live/Invoke-CWCLiveSmokeTest.ps1 -Server control.example.com -TestSessionID <guid> -AllowWrites -ToolboxItem 'Test.ps1'
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

    # Probe the MFA login flow (#12) with this account: TryLogin with a one-time password, then
    # call PageService with only the login cookies + anti-forgery token (no Basic auth).
    [string]$MfaUserName,

    # Only delete the notes earlier runs left on the test session, then exit.
    [switch]$CleanupOnly,

    [string]$OutputPath ="C:\Temp\cwc-smoke-ps$($PSVersionTable.PSVersion.Major).json"
)

$ErrorActionPreference = 'Stop'
# Module functions report failures with non-terminating Write-Error; make them fail the step.
$PSDefaultParameterValues['*-CWC*:ErrorAction'] = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\ConnectWiseControlAPI\ConnectWiseControlAPI.psd1') -Force

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

function Disconnect-Test { $Module = Get-Module ConnectWiseControlAPI; & $Module { $script:CWCServerConnection = $null } }

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

$AdminCredential = Get-Credential -Message 'Admin (non-MFA) Control account'

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
    $Connection = & (Get-Module ConnectWiseControlAPI) { $script:CWCServerConnection }
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
    $Connected = [bool](& (Get-Module ConnectWiseControlAPI) { $script:CWCServerConnection })
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

#region MFA login probe (#12): raw requests, not module code
if ($MfaUserName) {
    $MfaCredential = Get-Credential -UserName $MfaUserName -Message 'MFA account'
    $Mfa = @{ Session = $null; Token = $null }

    # Result object with secrets dropped and long strings cut, so it's safe to record.
    function Select-LoginResult {
        param($LoginResult)
        # SecurityOperationResult may come back as a bare enum value (number or string)
        if ($null -eq $LoginResult -or $LoginResult -is [ValueType] -or $LoginResult -is [string]) {
            return [ordered]@{ Raw = $LoginResult; Type = if ($null -ne $LoginResult) { $LoginResult.GetType().Name } else { 'null' } }
        }
        $Safe = [ordered]@{}
        foreach ($Property in @($LoginResult.PSObject.Properties)) {
            if ($Property.Name -match 'nonce|token|secret|password|key') { $Safe[$Property.Name] = '<redacted>'; continue }
            $Value = "$($Property.Value)"
            $Safe[$Property.Name] = $Value.Substring(0, [math]::Min(120, $Value.Length))
        }
        $Safe
    }

    function Get-AntiForgeryToken {
        $Page = Invoke-WebRequest -Uri "https://$Server" -WebSession $Mfa.Session -UseBasicParsing
        $Match = [regex]::Match($Page.Content, 'antiForgeryToken":"([A-Za-z0-9+/=_-]{16,512})"')
        if ($Match.Success) { $Match.Groups[1].Value } else { $null }
    }

    function Invoke-MfaRequest {
        param([string]$Endpoint, $Arguments)
        $Headers = @{ 'content-type' = 'application/json; charset=utf-8'; origin = "https://$Server" }
        if ($Mfa.Token) { $Headers['x-anti-forgery-token'] = $Mfa.Token }
        $Body = ConvertTo-Json -InputObject @($Arguments) -Depth 10
        (Invoke-WebRequest -Uri "https://$Server/$Endpoint" -Method Post -Headers $Headers -Body $Body -WebSession $Mfa.Session -UseBasicParsing).Content | ConvertFrom-Json
    }

    Invoke-Step 'Mfa.FrontPage' {
        $null = Invoke-WebRequest -Uri "https://$Server" -UseBasicParsing -SessionVariable 'MfaSession'
        $Mfa.Session = $MfaSession
        $Mfa.Token = Get-AntiForgeryToken
        [ordered]@{ TokenFound = [bool]$Mfa.Token; Cookies = @($Mfa.Session.Cookies.GetCookies("https://$Server") | ForEach-Object Name) }
    }

    $Password = $MfaCredential.GetNetworkCredential().Password
    function Get-MfaCookieName { @($Mfa.Session.Cookies.GetCookies("https://$Server") | ForEach-Object Name) }
    # One TryLogin attempt: the login result code and which cookies the session holds afterwards
    function Invoke-TryLoginStep {
        param([string]$Name, $OneTimeCode)
        Invoke-Step $Name {
            [ordered]@{
                Result  = Select-LoginResult (Invoke-MfaRequest 'Services/AuthenticationService.ashx/TryLogin' @($MfaUserName, $Password, $OneTimeCode, $False, $null))
                Cookies = Get-MfaCookieName
            }
        }
    }

    Invoke-TryLoginStep 'Mfa.TryLoginWithoutOtp' $null
    Invoke-TryLoginStep 'Mfa.TryLoginWrongOtp' '000000'

    $OneTimePassword = Read-Host -Prompt "One-time password for $MfaUserName (Enter to skip)"
    if ($OneTimePassword) {
        Invoke-TryLoginStep 'Mfa.TryLoginWithOtp' $OneTimePassword
        Invoke-Step 'Mfa.CookiesAfterLogin' { Get-MfaCookieName }

        # Anti-forgery tokens may be tied to the logged-in user: compare old and fresh.
        Invoke-Step 'Mfa.RefreshToken' {
            $OldToken = $Mfa.Token
            $Mfa.Token = Get-AntiForgeryToken
            [ordered]@{ TokenFound = [bool]$Mfa.Token; ChangedAfterLogin = ($OldToken -ne $Mfa.Token) }
        }
        Invoke-Step 'Mfa.GetEligibleHosts' { @(Invoke-MfaRequest 'Services/PageService.ashx/GetEligibleHosts' @()).Count }
        Invoke-Step 'Mfa.GetSessionDetail' {
            $Detail = Invoke-MfaRequest 'Services/PageService.ashx/GetSessionDetails' @($Group, "$TestSessionID")
            @($Detail.Events).Count
        }
        if ($AllowWrites) {
            Invoke-Step 'Mfa.AddNote' {
                $NoteEvent = @{ SessionID = "$TestSessionID"; EventType = 32; Data = 'CWC smoke test note (MFA login)' }
                $null = Invoke-MfaRequest 'Services/PageService.ashx/AddSessionEvents' @(@($Group), @($NoteEvent))
                'sent'
            }
        }
    }
    $Password = $null
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
