function Connect-CWC {
    <#
    .SYNOPSIS
        Connects to a ConnectWise ScreenConnect server.

    .DESCRIPTION
        Three ways to sign in:

        -Credentials alone (default): Basic auth with a ScreenConnect user account that does not use MFA. Gives
        access to every function in the module, limited by that user's permissions. Never expires.

        -Credentials with -Mfa, -OneTimeCode or -TotpSecret: signs in the way the web page does, with a
        one-time code, for accounts that require MFA. Gives the same access as -Credentials alone. The
        login is a cookie that the server expires; when it does, commands fail with a permission error
        and you run Connect-CWC again. The password and TOTP secret are not kept after the login.

        -ApiSecret: the authentication secret configured in the RESTful API Manager extension's
        RESTfulAuthenticationSecret setting, sent as the CTRLAuthHeader header. Works when every user
        account requires MFA. Only functions backed by that extension are available (see NOTES); other
        functions return an error telling you to connect with -Credentials.

        The connection is validated before it is cached. An existing connection to the same server with
        the same method and identity (user and password, or secret) is reused unless -Force is given;
        anything else reconnects. A cached MFA login is checked with one call first and replaced with a
        new login if it has expired.

    .PARAMETER Server
        ScreenConnect server hostname, e.g. screenconnect.example.com. A leading http(s):// is removed. HTTPS is always used.

    .PARAMETER Credentials
        Username and password of a ScreenConnect user account.

    .PARAMETER Mfa
        Sign in for an account that requires MFA, asking for the one-time code at the console when the
        server requests it. Works with authenticator apps and with codes the server sends by email or
        SMS (they are sent at this point). For interactive use only.

    .PARAMETER OneTimeCode
        The current one-time code (6 to 8 digits) for an account that requires MFA. Quote it, so a
        leading zero is kept.

    .PARAMETER TotpSecret
        The account's authenticator-app (TOTP) secret, for unattended scripts. The current code is
        computed from it at each login; the secret itself is not stored. Accepts the value ScreenConnect stores
        for authenticator apps ("ms:" followed by Base32, as New-CWCMFA creates) or bare Base32.
        Not for email or SMS codes.

        Keep it in a secret store, e.g. Microsoft.PowerShell.SecretManagement: -TotpSecret (Get-Secret ...).
        A TOTP secret stored next to the password turns MFA into a single factor: keep them in separate
        vaults where you can, prefer -ApiSecret when its functions are enough, and replace the secret if
        the computer is compromised.

    .PARAMETER ApiSecret
        The RESTful API Manager extension's RESTfulAuthenticationSecret value.

    .PARAMETER Origin
        Origin header sent with -ApiSecret requests. Defaults to https://<Server>. Set it to match the
        extension's RESTfulAllowedOrigin setting if that setting is configured.

    .PARAMETER Force
        Reconnect even when the cached connection is for the same server, method and identity. If that
        refresh fails, the previous connection is kept. A failed connection to a different server, method
        or identity leaves the module disconnected, so later commands can't reach the old server.

    .EXAMPLE
        Connect-CWC -Server 'screenconnect.example.com' -Credentials (Get-Credential)

        Connects with an account that does not use MFA.

    .EXAMPLE
        Connect-CWC -Server 'screenconnect.example.com' -Credentials (Get-Credential) -Mfa

        Connects with an account that requires MFA and asks for the one-time code.

    .EXAMPLE
        Connect-CWC -Server 'screenconnect.example.com' -Credentials $Credential -OneTimeCode (Read-Host 'One-time code')

        Connects with an account that requires MFA, using a code you supply. Reading it with Read-Host
        keeps it out of the command history.

    .EXAMPLE
        $Credential = Get-Secret -Name 'CWC-Login'
        Connect-CWC -Server 'screenconnect.example.com' -Credentials $Credential -TotpSecret (Get-Secret -Name 'CWC-TOTP')

        Unattended login for an account that requires MFA. Run it again before each batch of work: when
        the cached login is still valid it costs one call, and when it has expired it logs in again.

    .EXAMPLE
        $Secret = Read-Host -AsSecureString -Prompt 'RESTful API secret'
        Connect-CWC -Server 'screenconnect.example.com' -ApiSecret $Secret

        Connects with the RESTful API Manager extension's secret.

    .NOTES
        Functions available with -ApiSecret: Get-CWCSessionDetail, Update-CWCSessionName,
        Invoke-CWCCommand (queues the command; output is not retrieved), Find-CWCSession,
        New-CWCSession, Add-CWCSessionNote, Send-CWCSessionMessage, Send-CWCToolboxItem.
        Only calls that are safe to repeat (reads, "set to value" updates) are retried on HTTP 500.

        The API secret is not tied to a ScreenConnect user: the extension does not apply role permissions or
        session group scoping, so it can act on every session. Treat it like an administrator password.
        Requires the RESTful API Manager extension (2d558935-686a-4bd0-9991-07539f5fe749).

        MFA logins are never retried automatically: each attempt counts toward the server's login limits.
        Errors carry an ErrorId: CWC.MfaRequired, CWC.MfaCodeRejected, CWC.LoginFailed, CWC.LoginThrottled
        or CWC.NoResponse. The device is never marked as trusted, and the login is never saved to disk.

        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credentials')]
    param(
        # Positions 0 and 1 keep 0.4-style calls working: Connect-CWC 'server' $Credentials
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'Credentials')]
        [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'Mfa')]
        [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'OneTimeCode')]
        [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'TotpSecret')]
        [pscredential]$Credentials,

        [Parameter(Mandatory = $True, ParameterSetName = 'Mfa')]
        [switch]$Mfa,

        [Parameter(Mandatory = $True, ParameterSetName = 'OneTimeCode')]
        [ValidatePattern('^\d{6,8}$')]
        [string]$OneTimeCode,

        [Parameter(Mandatory = $True, ParameterSetName = 'TotpSecret')]
        [securestring]$TotpSecret,

        [Parameter(Mandatory = $True, ParameterSetName = 'ApiSecret')]
        [securestring]$ApiSecret,

        [Parameter(ParameterSetName = 'ApiSecret')]
        [ValidateNotNullOrEmpty()]
        [string]$Origin,

        [switch]$Force
    )

    $Server = $Server -replace ("http.*:\/\/", '')
    # The three MFA parameter sets are one auth method
    $RequestedAuthType = switch ($PSCmdlet.ParameterSetName) {
        'Credentials' { 'Credentials' }
        'ApiSecret' { 'ApiSecret' }
        default { 'Mfa' }
    }

    if ($RequestedAuthType -eq 'ApiSecret' -and $ApiSecret.Length -eq 0) { throw 'ApiSecret cannot be empty.' }
    if ($PSCmdlet.ParameterSetName -eq 'TotpSecret') {
        if ($TotpSecret.Length -eq 0) { throw 'TotpSecret cannot be empty.' }
        # Check the secret decodes before any request (and before a wait for a fresh code)
        $Key = Get-CWCTotpKey -Secret $TotpSecret
        [array]::Clear($Key, 0, $Key.Length)
    }

    if ($RequestedAuthType -eq 'Credentials') {
        $EncodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credentials.UserName):$($Credentials.GetNetworkCredential().Password)"))
    }
    if ($RequestedAuthType -eq 'Mfa') {
        $IdentityHash = Get-CWCIdentityHash -Credentials $Credentials
    }

    # Is the cached connection the same server, auth method and identity as requested?
    $SameAsCached = $False
    $Cached = $script:CWCServerConnection
    if ($Cached) {
        $CachedAuthType = if ($Cached.AuthType) { $Cached.AuthType } else { 'Credentials' }
        if ($Cached.Server -eq $Server -and $CachedAuthType -eq $RequestedAuthType) {
            switch ($RequestedAuthType) {
                'Credentials' { $SameAsCached = $Cached.Headers.authorization -eq "Basic $EncodedCredentials" }
                'ApiSecret' { $SameAsCached = (ConvertFrom-CWCSecureString $Cached.ApiSecret) -eq (ConvertFrom-CWCSecureString $ApiSecret) }
                'Mfa' { $SameAsCached = [bool]$Cached.IdentityHash -and $Cached.IdentityHash -eq $IdentityHash }
            }
        }
    }

    # Reuse the cached connection only for the same server, method and identity. Anything else reconnects:
    # keeping the old connection would send later commands (including deletes) to the wrong server, or
    # run them as the wrong user.
    if ($SameAsCached -and !$Force) {
        if ($RequestedAuthType -ne 'Mfa') {
            Write-Verbose 'Using cached Authentication information.'
            return
        }
        # An MFA login is a cookie the server expires: check it is still accepted
        try {
            $null = Invoke-CWCServiceMethod -Service PageService -Method GetEligibleHosts -Idempotent -ErrorAction Stop
            Write-Verbose 'Using the cached MFA login.'
            return
        }
        catch {
            if ($_.FullyQualifiedErrorId -notlike 'CWC.Http*') {
                # No answer: says nothing about the login. Keep it rather than spend a new code.
                Write-Error "Could not reach 'https://$Server' to check the cached MFA login: $($_.Exception.Message)"
                return
            }
            Write-Verbose "The cached MFA login is no longer accepted; logging in again. $($_.Exception.Message)"
            # Never restore an expired login
            $SameAsCached = $False
            $Cached = $null
        }
    }

    # On failure, restore the previous connection only when this was a refresh of that same connection
    # (-Force). After a failed switch to another server, method or identity, stay disconnected.
    $PreviousConnection = $null
    if ($SameAsCached) { $PreviousConnection = $Cached }
    $script:CWCServerConnection = $null

    # A switch away from an MFA login drops it whatever happens next: log it out so its cookie stops
    # working on the server too. A refresh of the same login is not logged out (it is restored if the
    # refresh fails, and the server may end all of the user's logins), nor is an expired one.
    if ($Cached -and $Cached.AuthType -eq 'Mfa' -and -not $SameAsCached) {
        Invoke-CWCLogout -Connection $Cached
    }

    if ($RequestedAuthType -eq 'ApiSecret') {
        if (-not $Origin) { $Origin = "https://$Server" }

        # Own copy, so the caller disposing their SecureString doesn't break later requests
        $StoredSecret = $ApiSecret.Copy()
        $StoredSecret.MakeReadOnly()

        # No Basic auth, anti-forgery token or cookies: the extension only checks CTRLAuthHeader,
        # which Invoke-CWCWebRequest adds per request from the stored SecureString.
        $script:CWCServerConnection = @{
            Server    = $Server
            AuthType  = 'ApiSecret'
            ApiSecret = $StoredSecret
            Headers   = @{
                'content-type' = 'application/json; charset=utf-8'
                'origin'       = $Origin
            }
        }

        try {
            # Lookup of an all-zero session ID: returns an empty list when the secret is valid.
            $null = Invoke-CWCServiceMethod -RestApi -Method GetSessionBySessionID -Arguments ([guid]::Empty.ToString()) -Idempotent -ErrorAction Stop
            Write-Verbose "Connected to ScreenConnect server with API secret: https://$Server"
        }
        catch {
            $script:CWCServerConnection = $PreviousConnection
            Write-Verbose 'Authentication failed.'
            Write-Error ("API secret authentication to 'https://$Server' failed. Check that the RESTful API Manager " +
                "extension is installed, its RESTfulAuthenticationSecret matches, and RESTfulAllowedOrigin is empty " +
                "or equals '$Origin' (see -Origin). $_")
        }
    }
    elseif ($RequestedAuthType -eq 'Mfa') {
        $LoginParameters = @{ Server = $Server; Credentials = $Credentials; IdentityHash = $IdentityHash }
        switch ($PSCmdlet.ParameterSetName) {
            'Mfa' { $LoginParameters.Prompt = $True }
            'OneTimeCode' { $LoginParameters.OneTimeCode = $OneTimeCode }
            'TotpSecret' { $LoginParameters.TotpSecret = $TotpSecret }
        }
        try {
            Invoke-CWCMfaLogin @LoginParameters
            Write-Verbose "Connected to ScreenConnect server with an MFA login: https://$Server"
        }
        catch {
            $script:CWCServerConnection = $PreviousConnection
            Write-Verbose 'Authentication failed.'
            # Keeps the ErrorId (CWC.MfaRequired, CWC.MfaCodeRejected, ...) for callers
            $PSCmdlet.WriteError($_)
        }
    }
    else {
        $Headers = @{
            'authorization' = "Basic $EncodedCredentials"
            'content-type'  = 'application/json; charset=utf-8'
            'origin'        = "https://$Server"
        }

        # The WebRequestSession keeps the cookies the server sets (e.g. .ASPXAUTH) and sends them back on
        # every later request, the way a browser does. The anti-forgery token is issued alongside them.
        $WebSession = $null
        $FrontPage = $null
        try {
            $FrontPage = Invoke-WebRequest -Uri $Headers.origin -Headers $Headers -UseBasicParsing -SessionVariable 'WebSession'
        }
        catch {
            $script:CWCServerConnection = $PreviousConnection
            Write-Error "Failed to connect to ScreenConnect server 'https://$Server': $_"
        }

        if ($FrontPage) {
            $Token = Get-CWCAntiForgeryToken -Content $FrontPage.content
            if ($Token) { $Headers.'x-anti-forgery-token' = $Token }
            else { Write-Warning 'Unable to find the anti-forgery token on the server front page. Commands that change sessions may fail with "Invalid anti-forgery token".' }

            $script:CWCServerConnection = @{
                Server     = $Server
                AuthType   = 'Credentials'
                Headers    = $Headers
                WebSession = $WebSession
                # Until the validation call passes: keeps Invoke-CWCWebRequest from suggesting a stale login
                LoggingIn  = $True
            }
            Write-Verbose "Connected to ScreenConnect server: https://$Server"

            try {
                # GetEligibleHosts requires any permission, so it validates auth for non-admin accounts too
                # (Get-CWCSessionGroup requires ManageSessionGroups).
                $null = Invoke-CWCServiceMethod -Service PageService -Method GetEligibleHosts -Idempotent -ErrorAction Stop
                Write-Verbose '$CWCServerConnection, variable initialized.'
            }
            catch {
                $script:CWCServerConnection = $PreviousConnection
                Write-Verbose 'Authentication failed.'
                if ($_.FullyQualifiedErrorId -like 'CWC.Http*') {
                    # The server answered and rejected the call. Bad credentials are not rejected with a 401: the
                    # request runs as an anonymous user and fails with "Needs permission", so name the likely causes.
                    Write-Error ("Authentication to 'https://$Server' failed. Check the username and password, " +
                        'that the account does not require MFA (for one that does, add -Mfa, -OneTimeCode or ' +
                        "-TotpSecret), and that its role grants at least one permission. $_")
                }
                else {
                    # No answer from the server (DNS, TLS, network) or a local PowerShell error: says nothing
                    # about the credentials.
                    Write-Error "Connecting to 'https://$Server' failed before authentication could be checked: $_"
                }
            }
            finally {
                # Also when interrupted (Ctrl+C); after a failure this is the restored connection, or none
                if ($script:CWCServerConnection) { $script:CWCServerConnection.Remove('LoggingIn') }
            }
        }
    }
}
