function Enter-CWCSession {
    <#
    .SYNOPSIS
        Opens the ConnectWise Control Host client joined to a session, like Join in the web UI.

    .DESCRIPTION
        Gets a Host access token for the session (PageService.GetAccessToken), builds the client launch
        URL the web client uses (sc-<instance>://...) and opens it with the installed Control client.
        The join is recorded in the session's audit trail (InitiatedJoin), as a web UI join is.

        The client must already be installed for the current Windows user: join any session once from
        the web UI. Launching works on Windows only; on other systems use -UrlOnly and open the URL
        yourself.

        Requires Connect-CWC -Credentials and the JoinSession permission in -Group.

    .PARAMETER GUID
        Session ID. Accepts SessionID from the pipeline (e.g. from Get-CWCSession).

    .PARAMETER Type
        Session type. Defaults to Access.

    .PARAMETER Group
        Session group containing the session: a name, or the path parts of a nested group. Defaults to
        'All Machines' for Access, 'All Sessions' for Support and 'All Meetings' for Meeting.

    .PARAMETER Name
        Session name shown as the client's title. Taken from the pipeline (e.g. from Get-CWCSession);
        when given, the session lookup is skipped.

    .PARAMETER UrlOnly
        Return the launch URL instead of opening the client. The URL holds an access token: treat it
        like a password. It uses a delegated token that expires in 5 minutes when your role has the
        CreateDelegatedAccessToken permission; otherwise a regular Host token (with a warning), which
        is valid for the server's access token lifetime (7 days by default).

    .EXAMPLE
        Enter-CWCSession -GUID 'a1b2c3d4-0000-0000-0000-000000000000'

    .EXAMPLE
        Get-CWCSession -Type Access -Search 'DESKTOP-01' -Limit 1 | Enter-CWCSession

    .EXAMPLE
        $Url = Enter-CWCSession -GUID $SessionID -UrlOnly
        open $Url   # macOS

    .NOTES
        The access token is not written to verbose, debug, warning or error output. It does appear in
        the launched client's command line (as with a web UI join), and PowerShell module or
        script-block logging, when enabled, can record the API response that carries it.
        The token is tied to the public IP address this call comes from, so the URL may not work from
        another network (a different proxy or VPN exit).

        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('SessionID')]
        [guid]$GUID,

        [ValidateSet('Support', 'Meeting', 'Access')]
        [string]$Type = 'Access',

        [string[]]$Group,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$Name,

        [switch]$UrlOnly
    )

    begin {
        $DelegatedTokenSeconds = 300
        $ModuleVersion = $MyInvocation.MyCommand.Module.Version
        # Set after the first failed delegated-token request, so a pipeline doesn't retry and warn per item
        $DelegatedTokenUnavailable = $False
    }

    process {
        if (-not $script:CWCServerConnection) {
            return Write-Error "Not connected to a Control server. Run 'Connect-CWC' first." -ErrorId 'CWC.NotConnected' -Category ConnectionError
        }
        # Checked up front: the launch settings below are read without going through the request helper.
        if (Test-CWCApiSecretConnection) {
            return Write-Error (Get-CWCAuthModeMessage -Command $MyInvocation.MyCommand.Name -Required Credentials) -ErrorId 'CWC.AuthModeMismatch' -Category InvalidOperation
        }
        if (-not $UrlOnly -and [Environment]::OSVersion.Platform -ne 'Win32NT') {
            return Write-Error 'Launching the Control client is supported on Windows only. Use -UrlOnly to get the launch URL and open it yourself.'
        }

        # Local copy: a default chosen for one pipeline item must not stick to the next.
        $SessionGroup = $Group
        if (-not $SessionGroup) { $SessionGroup = $script:CWCDefaultSessionGroup[$Type] }
        $GroupText = $SessionGroup -join '/'

        $LaunchContext = Get-CWCHostLaunchContext
        if (-not $LaunchContext) { return }

        if (-not $UrlOnly -and -not (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\$($LaunchContext.Scheme)")) {
            return Write-Error ("The Control client for $($script:CWCServerConnection.Server) is not installed for this Windows user " +
                "(no handler for $($LaunchContext.Scheme)://). Join any session once from the web UI to install it, or use -UrlOnly.")
        }

        # Title shown by the client. Without -Name, look the session up, which also checks that it exists
        # as this type in this group.
        $Title = $Name
        if (-not $PSBoundParameters.ContainsKey('Name')) {
            $Session = Get-CWCSession -Type $Type -Group $SessionGroup -FindSessionID $GUID |
                Where-Object { "$($_.SessionID)" -eq "$GUID" } | Select-Object -First 1
            if (-not $Session) {
                return Write-Error "Session $GUID was not found among $Type sessions in group '$GroupText'. Check -Type and -Group."
            }
            $Title = "$($Session.Name)"
        }

        $Token = $null
        if ($UrlOnly -and -not $DelegatedTokenUnavailable) {
            try {
                $Token = Invoke-CWCServiceMethod -Service PageService -Method GetDelegatedAccessToken -Arguments @(
                    @($SessionGroup), "$GUID", $script:CWCAllSessionPermissions, $DelegatedTokenSeconds, 'ConnectWiseControlAPI Enter-CWCSession -UrlOnly'
                ) -ErrorAction Stop
            }
            catch {
                # Only a permission failure holds for the rest of the pipeline; anything else is retried per item.
                if ("$($_.Exception.Message)" -match 'SecurityException|permission') { $DelegatedTokenUnavailable = $True }
                Write-Verbose "Delegated access token not available: $($_.Exception.Message)"
                Write-Warning ("Could not get a short-lived delegated token (needs CreateDelegatedAccessToken); the URL uses a regular " +
                    "Host token valid for the server's access token lifetime. Treat it like a password.")
            }
        }
        if (-not $Token) {
            try { $Token = New-CWCAccessToken -Group $SessionGroup -GUID $GUID -ErrorAction Stop }
            catch { return Write-Error "Could not get an access token for session $GUID (JoinSession permission in '$GroupText' is required): $($_.Exception.Message)" }
        }
        if (-not $Token) { return Write-Error "The server returned no access token for session $GUID." }

        $UrlParameters = @{
            Scheme      = $LaunchContext.Scheme
            RelayHost   = $LaunchContext.RelayHost
            RelayPort   = $LaunchContext.RelayPort
            SessionID   = $GUID
            PublicKey   = $LaunchContext.PublicKey
            AccessToken = "$Token"
            SessionType = $Type
            Title       = $Title
        }
        $Url = New-CWCHostLaunchUrl @UrlParameters
        $Token = $null

        if ($UrlOnly) { return $Url }

        Write-Verbose "Opening the Control client for session $GUID."
        try { Start-CWCHostClient -Url $Url }
        catch { return Write-Error "$($_.Exception.Message)" }
        finally { $Url = $null }

        # Same audit entry as a web UI join: LogInitiatedJoin(sessionID, processType, data).
        try {
            $JoinData = "(UrlLaunch) ConnectWiseControlAPI/$ModuleVersion PowerShell/$($PSVersionTable.PSVersion)"
            $null = Invoke-CWCServiceMethod -Service PageService -Method LogInitiatedJoin -Arguments @("$GUID", $script:CWCProcessType.Host, $JoinData) -ErrorAction Stop
        }
        catch {
            Write-Warning "The client was opened, but the join could not be logged on the server: $($_.Exception.Message)"
        }
    }
}
