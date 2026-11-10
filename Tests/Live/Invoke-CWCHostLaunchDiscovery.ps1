<#
.SYNOPSIS
    Live discovery for Enter-CWCSession (issue #13): how the web client launches the Host client.

.DESCRIPTION
    Read-only. Connects with a non-MFA account and records, without secrets:
      - whether SC.context (instanceUrlScheme, clp = relay host/port/public key) is on '/' and '/Host'
      - web client code around the launch URL builder, ProcessType/SessionType enums, LogInitiatedJoin
        and the join-reason prompt, so the URL format and encoding can be copied exactly
      - whether this Windows user has the protocol handler for the instance's sc-<id> scheme

    Every captured text is scrubbed (anti-forgery token, the server public key, cookie values,
    token-shaped strings, user names) and the output is checked for the known secrets before it is
    written. Run once on PS 7 and once on Windows PowerShell 5.1.

.EXAMPLE
    ./Tests/Live/Invoke-CWCHostLaunchDiscovery.ps1 -Server control.example.com

.EXAMPLE
    ./Tests/Live/Invoke-CWCHostLaunchDiscovery.ps1 -Server control.example.com -Launch -TestSessionID <guid>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$Server,

    [string]$OutputPath = "C:\Temp\cwc-hostlaunch-discovery-ps$($PSVersionTable.PSVersion.Major).json",

    # Also test Enter-CWCSession on this session: -UrlOnly (URL shape only, no secrets recorded), then a
    # real launch you confirm, then a check that the join was logged.
    [switch]$Launch,
    [guid]$TestSessionID,
    [ValidateSet('Support', 'Meeting', 'Access')]
    [string]$Type = 'Access',
    [string]$Group,

    # Module manifest to load. Defaults to this checkout's copy.
    [string]$ModulePath
)

$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*-CWC*:ErrorAction'] = 'Stop'
# $PSScriptRoot is empty in parameter defaults on Windows PowerShell 5.1, so resolve the default here.
if (-not $ModulePath) { $ModulePath = Join-Path $PSScriptRoot '..\..\ConnectWiseControlAPI\ConnectWiseControlAPI.psd1' }
Import-Module $ModulePath -Force

$Server = $Server -replace '^https?://', '' -replace '/+$', ''

$Results = [ordered]@{
    PSVersion  = $PSVersionTable.PSVersion.ToString()
    StartedUtc = [DateTime]::UtcNow.ToString('o')
    Steps      = [ordered]@{}
}

# Values that must never reach the output file. Filled in as they are discovered.
$Secrets = New-Object System.Collections.Generic.List[string]

function Invoke-Step {
    param([string]$Name, [scriptblock]$Script)
    Write-Host "== $Name" -ForegroundColor Cyan
    try {
        $Value = & $Script
        $Results.Steps[$Name] = [ordered]@{ Ok = $True; Value = $Value }
        Write-Host '   ok' -ForegroundColor Green
    }
    catch {
        $Results.Steps[$Name] = [ordered]@{ Ok = $False; Error = (Protect-Text "$_") }
        Write-Host "   FAILED: $(Protect-Text "$_")" -ForegroundColor Red
    }
}

# Removes secrets from captured text. Code stays readable: only token-shaped runs are replaced.
function Protect-Text {
    param([string]$Text)
    if (-not $Text) { return $Text }
    foreach ($Secret in $Secrets) {
        if (-not $Secret) { continue }
        $Text = $Text.Replace($Secret, '<secret>')
        $Text = $Text.Replace($Secret.Replace('/', '\/'), '<secret>')                 # JSON-escaped form
        $Text = $Text.Replace([uri]::EscapeDataString($Secret), '<secret>')           # URL-encoded form
    }
    $Text = $Text -replace 'antiForgeryToken"\s*:\s*"[^"]*"', 'antiForgeryToken":"<redacted>"'
    $Text = $Text -replace '(?i)(\.ASPXAUTH|ASP\.NET_SessionId|__RequestVerificationToken)=[^;"\s&]+', '$1=<redacted>'
    $Text = $Text -replace '(?i)"(userName|userDisplayName|userEmail|loginUserName)"\s*:\s*"[^"]*"', '"$1":"<redacted>"'
    # Base64-looking runs (keys, tokens): 40+ chars with a digit and both letter cases.
    $Text = [regex]::Replace($Text, '[A-Za-z0-9+/_%-]{40,}={0,2}', {
            param($M)
            $V = $M.Value
            if ($V -cmatch '[0-9]' -and $V -cmatch '[A-Z]' -and $V -cmatch '[a-z]') { '<redacted-b64>' } else { $V }
        })
    $Text
}

function Get-Page {
    param([string]$Path)
    $Connection = & (Get-Module ConnectWiseControlAPI) { $script:CWCServerConnection }
    $Headers = @{}
    foreach ($Key in $Connection.Headers.Keys) { if ($Key -ne 'content-type') { $Headers[$Key] = $Connection.Headers[$Key] } }
    $Response = Invoke-WebRequest -Uri "https://$Server/$($Path.TrimStart('/'))" -Headers $Headers -WebSession $Connection.WebSession -UseBasicParsing
    $Content = $Response.Content
    if ($Content -is [byte[]]) { $Content = [Text.Encoding]::UTF8.GetString($Content) }
    $Content
}

function Get-CharacterClass {
    param([string]$Value)
    [ordered]@{
        Length     = $Value.Length
        HasPlus    = $Value.Contains('+')
        HasSlash   = $Value.Contains('/')
        HasEquals  = $Value.Contains('=')
        HasPercent = $Value.Contains('%')
        HasDashOrUnderscore = ($Value -match '[-_]')
    }
}

$Credential = Get-Credential -Message 'Non-MFA Control account (needs JoinSession)'

Invoke-Step 'Connect' {
    Connect-CWC -Server $Server -Credentials $Credential -Force
    $Connection = & (Get-Module ConnectWiseControlAPI) { $script:CWCServerConnection }
    if ($Connection.Headers.'x-anti-forgery-token') { $Secrets.Add($Connection.Headers.'x-anti-forgery-token') }
    $Secrets.Add($Credential.GetNetworkCredential().Password)
    $Secrets.Add(($Connection.Headers.authorization -replace '^Basic ', ''))
    'connected'
}

if (-not $Results.Steps['Connect'].Ok) {
    $Results | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    throw "Connect failed; see $OutputPath. Nothing else was run."
}

$Pages = [ordered]@{}
$ScriptUrls = New-Object System.Collections.Generic.List[string]
$State = @{ Scheme = $null }

foreach ($Path in @('/', '/Host')) {
    Invoke-Step "Page $Path" {
        $Html = Get-Page $Path
        $Pages[$Path] = $Html

        foreach ($M in [regex]::Matches($Html, '<script[^>]*\ssrc="([^"]+)"')) {
            $Url = [System.Net.WebUtility]::HtmlDecode($M.Groups[1].Value)
            if (($Url -notmatch '^https?://' -or $Url -match [regex]::Escape($Server)) -and -not $ScriptUrls.Contains($Url)) { $ScriptUrls.Add($Url) }
        }

        $SchemeMatch = [regex]::Match($Html, '"instanceUrlScheme"\s*:\s*"([^"]*)"')
        $ClpMatch = [regex]::Match($Html, '"clp"\s*:\s*\{([^}]*)\}')
        $Clp = $null
        if ($ClpMatch.Success) {
            $Body = $ClpMatch.Groups[1].Value
            $K = [regex]::Match($Body, '"k"\s*:\s*"([^"]*)"').Groups[1].Value
            $KDecoded = $K.Replace('\/', '/')
            if ($K) { $Secrets.Add($K); $Secrets.Add($KDecoded) }
            $Clp = [ordered]@{
                Keys    = @([regex]::Matches($Body, '"(\w+)"\s*:') | ForEach-Object { $_.Groups[1].Value })
                h       = [regex]::Match($Body, '"h"\s*:\s*"([^"]*)"').Groups[1].Value
                p       = [regex]::Match($Body, '"p"\s*:\s*("?)([^,"}]*)\1').Groups[2].Value
                k       = if ($K) { Get-CharacterClass $KDecoded } else { $null }
                kJsonEscapesSlash = $K.Contains('\/')
                Context = Protect-Text $Html.Substring([math]::Max(0, $ClpMatch.Index - 300), [math]::Min(600, $Html.Length - [math]::Max(0, $ClpMatch.Index - 300)))
            }
        }
        if ($SchemeMatch.Success -and -not $State.Scheme) { $State.Scheme = $SchemeMatch.Groups[1].Value }

        [ordered]@{
            Length            = $Html.Length
            InstanceUrlScheme = if ($SchemeMatch.Success) { $SchemeMatch.Groups[1].Value } else { $null }
            Clp               = $Clp
            HasProcessType    = [regex]::Match($Html, '"processType"\s*:\s*[^,}]+').Value
            ContextAssignment = @([regex]::Matches($Html, 'SC\.(context\s*=|util\.mergeIntoContext\()') | ForEach-Object { $_.Value })
        }
    }
}

# Web client code around the launch logic. Patterns are case-sensitive JS identifiers.
$Patterns = [ordered]@{
    InstanceUrlScheme = 'instanceUrlScheme'
    Clp               = 'context\.clp'
    StartJoinSession  = 'startJoinSession'
    LaunchUrl         = '(?i)launchUrl|getClientLaunchUrl|buildLaunchUrl|ClientLaunchParameters'
    LogInitiatedJoin  = 'LogInitiatedJoin'
    ProcessTypeEnum   = 'ProcessType\s*[=:]\s*\{|ProcessType\b[^;]{0,40}Host'
    SessionTypeEnum   = 'SessionType\s*[=:]\s*\{'
    JoinPrompt        = 'PromptVisible'
    ReasonCode        = 'AddReasonCodeToSession|ReasonCode'
    AccessToken       = 'GetAccessToken'
    HostLaunchParams  = 'getClientLaunchParameters\('
    AccessTokenExpiry = 'accessTokenExpireSeconds'
}
$MaxHitsPerPattern = 4

Invoke-Step 'WebClientScripts' {
    $Found = [ordered]@{}
    foreach ($Name in $Patterns.Keys) { $Found[$Name] = New-Object System.Collections.ArrayList }
    $Scanned = @()
    foreach ($Url in $ScriptUrls) {
        $Path = if ($Url -match '^https?://') { $Url -replace '^https?://[^/]+', '' } else { $Url }
        try { $Content = Get-Page $Path }
        catch { $Scanned += [ordered]@{ Script = ($Url -replace '\?.*$', ''); Error = (Protect-Text "$_") }; continue }
        $Scanned += [ordered]@{ Script = ($Url -replace '\?.*$', ''); Length = $Content.Length }
        foreach ($Name in $Patterns.Keys) {
            foreach ($M in [regex]::Matches($Content, $Patterns[$Name])) {
                if ($Found[$Name].Count -ge $MaxHitsPerPattern) { break }
                $Start = [math]::Max(0, $M.Index - 400)
                $null = $Found[$Name].Add([ordered]@{
                        Script = ($Url -replace '\?.*$', '')
                        Text   = Protect-Text $Content.Substring($Start, [math]::Min(3000, $Content.Length - $Start))
                    })
            }
        }
    }
    [ordered]@{ Scanned = $Scanned; Found = $Found }
}

Invoke-Step 'ProtocolHandler' {
    $Scheme = $State.Scheme
    # The scheme is published in Script.ashx, not the HTML pages.
    if (-not $Scheme) { $Scheme = & (Get-Module ConnectWiseControlAPI) { (Get-CWCHostLaunchContext -ErrorAction Stop).Scheme } }
    if (-not $Scheme) { throw 'instanceUrlScheme not found on any page' }
    $OnWindows = [Environment]::OSVersion.Platform -eq 'Win32NT'
    if (-not $OnWindows) { return 'not Windows' }
    $Key = "Registry::HKEY_CLASSES_ROOT\$Scheme"
    $Command = $null
    if (Test-Path "$Key\shell\open\command") { $Command = (Get-ItemProperty "$Key\shell\open\command").'(default)' }
    [ordered]@{
        Scheme          = $Scheme
        Registered      = Test-Path $Key
        PerUser         = Test-Path "Registry::HKEY_CURRENT_USER\Software\Classes\$Scheme"
        PerMachine      = Test-Path "Registry::HKEY_LOCAL_MACHINE\Software\Classes\$Scheme"
        OpenCommand     = Protect-Text $Command
    }
}

if ($Launch) {
    if (-not $TestSessionID) { throw '-Launch needs -TestSessionID.' }
    $EnterParameters = @{ GUID = $TestSessionID; Type = $Type }
    if ($Group) { $EnterParameters.Group = $Group }

    Invoke-Step 'Launch.UrlOnly' {
        $Url = Enter-CWCSession @EnterParameters -UrlOnly -WarningVariable UrlWarnings -WarningAction SilentlyContinue
        $Segments = "$Url" -split '/'
        $Token = [uri]::UnescapeDataString($Segments[5])
        $Secrets.Add($Token); $Secrets.Add($Segments[5]); $Secrets.Add($Segments[4])
        $Shape = [ordered]@{
            Scheme          = $Segments[0]
            RelayHostPort   = $Segments[2]
            SessionID       = $Segments[3]
            Key             = Get-CharacterClass ([uri]::UnescapeDataString($Segments[4]))
            Token           = Get-CharacterClass $Token
            ParticipantName = $Segments[6]
            SessionType     = $Segments[7]
            Title           = [uri]::UnescapeDataString($Segments[8])
            Attributes      = $Segments[9]
            LogonSessionID  = $Segments[10]
            SegmentCount    = $Segments.Count
        }
        $Url = $null
        [ordered]@{ UsedDelegatedToken = (@($UrlWarnings).Count -eq 0); Warnings = @($UrlWarnings | ForEach-Object { Protect-Text "$_" }); Shape = $Shape }
    }

    Invoke-Step 'Launch.Open' {
        $Before = [DateTime]::UtcNow
        $Output = & { Enter-CWCSession @EnterParameters -Verbose } 4>&1 3>&1 | ForEach-Object { Protect-Text "$_" }
        $Answer = Read-Host 'Did the Control client open and join the test session? (y/n)'
        Start-Sleep -Seconds 2
        $ElapsedMs = ([DateTime]::UtcNow - $Before).TotalMilliseconds + 1000
        $DetailParameters = @{ GUID = $TestSessionID; Include = 'Events' }
        if ($Group) { $DetailParameters.Group = $Group }
        $Detail = Get-CWCSessionDetail @DetailParameters
        $Joins = @($Detail.Events | Where-Object { $_.EventType -eq 30 -and [double]$_.Time -le $ElapsedMs } |
                ForEach-Object { [ordered]@{ Host = Protect-Text "$($_.Host)"; Data = Protect-Text "$($_.Data)" } })
        [ordered]@{ ClientJoined = ($Answer -match '^y'); Output = @($Output); InitiatedJoinEvents = $Joins }
    }
}

$Json = $Results | ConvertTo-Json -Depth 10
$Leaks = @($Secrets | Where-Object { $_ -and $_.Length -ge 8 -and $Json.Contains($_) })
if ($Leaks.Count -gt 0) {
    throw "Refusing to write $OutputPath : $($Leaks.Count) known secret value(s) survived redaction. Nothing was written."
}
$Json | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "`nResults: $OutputPath  (scrubbed; review before sharing)" -ForegroundColor Yellow
