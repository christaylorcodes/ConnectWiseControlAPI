function Invoke-CWCMfaLogin {
    <#
    .SYNOPSIS
        Logs in the way the web client does (AuthenticationService.TryLogin with a one-time code) and
        stores a cookie-based connection in $script:CWCServerConnection. Used by Connect-CWC.

    .DESCRIPTION
        1. Front page with a new WebRequestSession: cookies and the pre-login anti-forgery token.
        2. TryLogin(userName, password, oneTimePassword, shouldTrust = false, securityNonce = null).
           Live-verified results: 1 = success (sets .ASPXAUTH), 11 = one-time code required, 10 = wrong code.
        3. Front page again: the anti-forgery token changes after login.
        4. Validation with PageService.GetEligibleHosts.
        No Authorization header is sent; the .ASPXAUTH cookie carries the login. The password is used only
        in the TryLogin body and is not stored.

        On failure it throws an ErrorRecord with one of these ErrorIds and leaves
        $script:CWCServerConnection set to the half-built connection; Connect-CWC restores the state.
        CWC.MfaRequired, CWC.MfaCodeRejected, CWC.LoginFailed, CWC.LoginThrottled, CWC.NoResponse.

    .PARAMETER Prompt
        If the server asks for a one-time code (11), read it from the console. Covers email and SMS codes,
        which the server sends only after this first TryLogin.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prompt')]
    param(
        [Parameter(Mandatory = $True)]
        [string]$Server,

        [Parameter(Mandatory = $True)]
        [pscredential]$Credentials,

        [Parameter(Mandatory = $True)]
        [string]$IdentityHash,

        [Parameter(Mandatory = $True, ParameterSetName = 'Prompt')]
        [switch]$Prompt,

        [Parameter(Mandatory = $True, ParameterSetName = 'OneTimeCode')]
        [string]$OneTimeCode,

        [Parameter(Mandatory = $True, ParameterSetName = 'TotpSecret')]
        [securestring]$TotpSecret
    )

    $Origin = "https://$Server"
    $UserName = $Credentials.UserName

    function New-LoginError {
        param([string]$Message, [string]$ErrorId, [System.Management.Automation.ErrorCategory]$Category)
        New-Object System.Management.Automation.ErrorRecord ((New-Object Exception $Message), $ErrorId, $Category, $null)
    }

    # GET the front page with the shared cookie jar; returns its anti-forgery token
    function Get-FrontPageToken {
        try {
            $Page = Invoke-WebRequest -Uri $Origin -WebSession $WebSession -UseBasicParsing -ErrorAction Stop
        }
        catch {
            throw (New-LoginError "Failed to connect to ScreenConnect server '$Origin': $($_.Exception.Message)" 'CWC.NoResponse' ConnectionError)
        }
        Get-CWCAntiForgeryToken -Content $Page.Content
    }

    # One TryLogin call. Never retried: each attempt counts toward the server's login limits.
    function Invoke-TryLogin {
        # Untyped: a [string] parameter would turn $null into "", and "no code" must be sent as null
        param($Code)
        $Password = $Credentials.GetNetworkCredential().Password
        try {
            $Arguments = @($UserName, $Password, $Code, $False, $null)
            Invoke-CWCServiceMethod -Service AuthenticationService -Method TryLogin -Arguments $Arguments -Sensitive -ErrorAction Stop
        }
        catch {
            $Message = $_.Exception.Message
            if ($_.FullyQualifiedErrorId -like 'CWC.Http*') {
                if ($Message -match 'OperationLimit|RateLimit|Throttl|Too many') {
                    throw (New-LoginError "Login to '$Origin' was refused because of too many attempts. Wait before trying again. $Message" 'CWC.LoginThrottled' LimitsExceeded)
                }
                throw (New-LoginError "Login to '$Origin' failed: $Message" 'CWC.LoginFailed' AuthenticationError)
            }
            throw (New-LoginError "Connecting to '$Origin' failed before authentication could be checked: $Message" 'CWC.NoResponse' ConnectionError)
        }
        finally {
            $Password = $null
            $Arguments = $null
        }
    }

    $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $Headers = @{
        'content-type' = 'application/json; charset=utf-8'
        'origin'       = $Origin
    }
    $Token = Get-FrontPageToken
    if ($Token) { $Headers.'x-anti-forgery-token' = $Token }

    $script:CWCServerConnection = @{
        Server       = $Server
        AuthType     = 'Mfa'
        UserName     = $UserName
        IdentityHash = $IdentityHash
        Headers      = $Headers
        WebSession   = $WebSession
        # Tells Invoke-CWCWebRequest not to suggest an expired login while logging in
        LoggingIn    = $True
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Prompt' {
            $Result = Invoke-TryLogin -Code $null
            if ("$Result" -eq '11') {
                $SecureCode = $null
                try { $SecureCode = Read-Host -AsSecureString -Prompt "One-time code for $UserName" }
                catch { Write-Verbose "Could not prompt for the one-time code: $($_.Exception.Message)" }
                $Code = $null
                if ($SecureCode -and $SecureCode.Length -gt 0) { $Code = (ConvertFrom-CWCSecureString $SecureCode).Trim() }
                if (-not $Code) {
                    throw (New-LoginError ("The account '$UserName' requires a one-time code and none was entered. " +
                        'In scripts, use -OneTimeCode or -TotpSecret.') 'CWC.MfaRequired' AuthenticationError)
                }
                $Result = Invoke-TryLogin -Code $Code
                $Code = $null
            }
        }
        'OneTimeCode' {
            $Result = Invoke-TryLogin -Code $OneTimeCode
        }
        'TotpSecret' {
            $StepKey = "$Server|$UserName".ToLowerInvariant()
            $Totp = Get-CWCTotpLoginCode -Secret $TotpSecret -Key $StepKey
            $Result = Invoke-TryLogin -Code $Totp.Code
            # The server has seen this step's code (accepted or rejected): don't send it again
            if ("$Result" -in '1', 'Success', '10') { $script:CWCLastTotpStep[$StepKey] = $Totp.Step }
            $Totp = $null
        }
    }

    # SecurityOperationResult comes back as a bare number. Compare as text: Int32 on PS 5.1, Int64 on 7.
    switch ("$Result") {
        { $_ -in '1', 'Success' } { break }
        '11' {
            throw (New-LoginError "The account '$UserName' requires a one-time code. Use -Mfa, -OneTimeCode or -TotpSecret." 'CWC.MfaRequired' AuthenticationError)
        }
        '10' {
            throw (New-LoginError ("The one-time code for '$UserName' was rejected: wrong, expired or already used. " +
                'With -TotpSecret, check that the secret is right and the computer clock is accurate.') 'CWC.MfaCodeRejected' AuthenticationError)
        }
        default {
            throw (New-LoginError "Login to '$Origin' failed (result '$Result'). Check the username and password." 'CWC.LoginFailed' AuthenticationError)
        }
    }

    # Logged in from here on: if a later step fails, log out so the login doesn't stay valid on the server
    try {
        # The anti-forgery token is issued per login: fetch the new one
        $Token = Get-FrontPageToken
        if ($Token) { $Headers.'x-anti-forgery-token' = $Token }
        else {
            $Headers.Remove('x-anti-forgery-token')
            Write-Warning 'Unable to find the anti-forgery token on the server front page. Commands that change sessions may fail with "Invalid anti-forgery token".'
        }

        try {
            # GetEligibleHosts requires any permission, so it validates non-admin accounts too
            $null = Invoke-CWCServiceMethod -Service PageService -Method GetEligibleHosts -Idempotent -ErrorAction Stop
        }
        catch {
            if ($_.FullyQualifiedErrorId -like 'CWC.Http*') {
                throw (New-LoginError ("Logged in to '$Origin' as '$UserName', but the account can't use the API. " +
                    "Check that its role grants at least one permission. $($_.Exception.Message)") 'CWC.LoginFailed' AuthenticationError)
            }
            throw (New-LoginError "Connecting to '$Origin' failed after login: $($_.Exception.Message)" 'CWC.NoResponse' ConnectionError)
        }
    }
    catch {
        Invoke-CWCLogout -Connection $script:CWCServerConnection
        throw
    }
    $script:CWCServerConnection.Remove('LoggingIn')
}
