function Connect-CWC {
    <#
    .SYNOPSIS
        Connects to a ConnectWise Control server.

    .DESCRIPTION
        Two authentication methods are supported:

        -Credentials (default): Basic auth with a Control user account that does not use MFA. Gives
        access to every function in the module, limited by that user's permissions.

        -ApiSecret: the authentication secret configured in the RESTful API Manager extension's
        RESTfulAuthenticationSecret setting, sent as the CTRLAuthHeader header. Works when every user
        account requires MFA. Only functions backed by that extension are available (see NOTES); other
        functions return an error telling you to connect with -Credentials.

        The connection is validated before it is cached. Without -Force an existing connection is reused.

    .PARAMETER Server
        Control server hostname, e.g. control.example.com. A leading http(s):// is removed. HTTPS is always used.

    .PARAMETER Credentials
        Credentials for a Control user account without MFA.

    .PARAMETER ApiSecret
        The RESTful API Manager extension's RESTfulAuthenticationSecret value.

    .PARAMETER Origin
        Origin header sent with -ApiSecret requests. Defaults to https://<Server>. Set it to match the
        extension's RESTfulAllowedOrigin setting if that setting is configured.

    .PARAMETER Force
        Replace an existing cached connection. If the new connection fails validation, the previous
        connection is kept.

    .EXAMPLE
        Connect-CWC -Server 'control.example.com' -Credentials (Get-Credential)

    .EXAMPLE
        $Secret = Read-Host -AsSecureString -Prompt 'RESTful API secret'
        Connect-CWC -Server 'control.example.com' -ApiSecret $Secret

    .NOTES
        Functions available with -ApiSecret: Get-CWCSessionDetail, Update-CWCSessionName,
        Invoke-CWCCommand (queues the command; output is not retrieved), Find-CWCSession,
        New-CWCSession, Add-CWCSessionNote, Send-CWCSessionMessage, Send-CWCToolboxItem.
        Only calls that are safe to repeat (reads, "set to value" updates) are retried on HTTP 500.

        The API secret is not tied to a Control user: the extension does not apply role permissions or
        session group scoping, so it can act on every session. Treat it like an administrator password.
        Requires the RESTful API Manager extension (2d558935-686a-4bd0-9991-07539f5fe749).

        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credentials')]
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory = $True, ParameterSetName = 'Credentials')]
        [pscredential]$Credentials,

        [Parameter(Mandatory = $True, ParameterSetName = 'ApiSecret')]
        [securestring]$ApiSecret,

        [Parameter(ParameterSetName = 'ApiSecret')]
        [ValidateNotNullOrEmpty()]
        [string]$Origin,

        [switch]$Force
    )

    $Server = $Server -replace("http.*:\/\/",'')
    $RequestedAuthType = $PSCmdlet.ParameterSetName

    if ($script:CWCServerConnection -and !$Force) {
        $Cached = $script:CWCServerConnection
        $CachedAuthType = if ($Cached.AuthType) { $Cached.AuthType } else { 'Credentials' }
        if ($Cached.Server -ne $Server -or $CachedAuthType -ne $RequestedAuthType) {
            Write-Warning "Already connected to '$($Cached.Server)' with $CachedAuthType. Keeping that connection; use -Force to connect to '$Server' with $RequestedAuthType."
        }
        else {
            Write-Verbose "Using cached Authentication information."
        }
        return
    }

    # Kept so a failed -Force reconnect leaves the previous working connection in place
    $PreviousConnection = $script:CWCServerConnection

    if ($RequestedAuthType -eq 'ApiSecret') {
        if ($ApiSecret.Length -eq 0) {
            throw 'ApiSecret cannot be empty.'
        }
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
                'content-type' = "application/json; charset=utf-8"
                'origin'       = $Origin
            }
        }

        try {
            # Lookup of an all-zero session ID: returns an empty list when the secret is valid.
            $null = Invoke-CWCServiceMethod -RestApi -Method GetSessionBySessionID -Arguments ([guid]::Empty.ToString()) -Idempotent -ErrorAction Stop
            Write-Verbose "Connected to Control server with API secret: https://$Server"
        }
        catch {
            $script:CWCServerConnection = $PreviousConnection
            Write-Verbose 'Authentication failed.'
            Write-Error ("API secret authentication to 'https://$Server' failed. Check that the RESTful API Manager " +
                "extension is installed, its RESTfulAuthenticationSecret matches, and RESTfulAllowedOrigin is empty " +
                "or equals '$Origin' (see -Origin). $_")
        }
        return
    }

    $EncodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credentials.UserName):$($Credentials.GetNetworkCredential().Password)"))
    $Headers = @{
        'authorization' = "Basic $EncodedCredentials"
        'content-type' = "application/json; charset=utf-8"
        'origin' = "https://$Server"
    }

    # The WebRequestSession keeps the cookies the server sets (e.g. .ASPXAUTH) and sends them back on
    # every later request, the way a browser does. The anti-forgery token is issued alongside them.
    $WebSession = $null
    try {
        $FrontPage = Invoke-WebRequest -Uri $Headers.origin -Headers $Headers -UseBasicParsing -SessionVariable 'WebSession'
    }
    catch {
        Write-Error "Failed to connect to Control server 'https://$Server': $_"
        return
    }

    # Match only a token-shaped value, so a change in the page's JSON key order can't break the
    # capture (the old pattern required "isUserAdministrator" to follow) and no other page content is taken.
    $Regex = [Regex]'antiForgeryToken":"([A-Za-z0-9+/=_-]{16,512})"'
    $Match = $Regex.Match($FrontPage.content)
    if ($Match.Success) { $Headers.'x-anti-forgery-token' = $Match.Groups[1].Value }
    else { Write-Warning 'Unable to find the anti-forgery token on the server front page. Commands that change sessions may fail with "Invalid anti-forgery token".' }

    $script:CWCServerConnection = @{
        Server     = $Server
        AuthType   = 'Credentials'
        Headers    = $Headers
        WebSession = $WebSession
    }
    Write-Verbose "Connected to Control server: https://$Server"

    try{
        # GetEligibleHosts requires any permission, so it validates auth for non-admin accounts too
        # (Get-CWCSessionGroup requires ManageSessionGroups).
        $null = Invoke-CWCServiceMethod -Service PageService -Method GetEligibleHosts -Idempotent -ErrorAction Stop
        Write-Verbose '$CWCServerConnection, variable initialized.'
    }
    catch{
        $script:CWCServerConnection = $PreviousConnection
        Write-Verbose 'Authentication failed.'
        if ($_.FullyQualifiedErrorId -like '*WriteErrorException*') {
            # The server rejected the call. Bad credentials are not rejected with a 401: the request runs
            # as an anonymous user and fails with "Needs permission", so name the likely causes.
            Write-Error ("Authentication to 'https://$Server' failed. Check the username and password, that the " +
                "account does not require MFA, and that its role grants at least one permission. $_")
        }
        else {
            # A local failure (e.g. a PowerShell error) says nothing about the credentials.
            Write-Error "Connecting to 'https://$Server' failed before authentication could be checked: $_"
        }
    }
}
