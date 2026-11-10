---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Connect-CWC

## SYNOPSIS
Connects to a ConnectWise Control server.

## SYNTAX

### Credentials (Default)
```
Connect-CWC -Server <String> -Credentials <PSCredential> [-Force]
 [<CommonParameters>]
```

### TotpSecret
```
Connect-CWC -Server <String> -Credentials <PSCredential> -TotpSecret <SecureString> [-Force] [<CommonParameters>]
```

### OneTimeCode
```
Connect-CWC -Server <String> -Credentials <PSCredential> -OneTimeCode <String> [-Force] [<CommonParameters>]
```

### Mfa
```
Connect-CWC -Server <String> -Credentials <PSCredential> [-Mfa] [-Force]
 [<CommonParameters>]
```

### ApiSecret
```
Connect-CWC -Server <String> -ApiSecret <SecureString> [-Origin <String>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
Three ways to sign in:

-Credentials alone (default): Basic auth with a Control user account that does not use MFA.
Gives access to every function in the module, limited by that user's permissions. Never expires.

-Credentials with -Mfa, -OneTimeCode or -TotpSecret: signs in the way the web page does, with a one-time
code, for accounts that require MFA. Gives the same access as -Credentials alone. The login is a cookie
that the server expires; when it does, commands fail with a permission error and you run Connect-CWC
again. The password and TOTP secret are not kept after the login.

-ApiSecret: the authentication secret configured in the RESTful API Manager extension's
RESTfulAuthenticationSecret setting, sent as the CTRLAuthHeader header. Works when every user account
requires MFA. Only functions backed by that extension are available (see NOTES); other functions return
an error telling you to connect with -Credentials.

The connection is validated before it is cached. An existing connection to the same server with the same
method and identity (user and password, or secret) is reused unless -Force is given; anything else
reconnects. A cached MFA login is checked with one call first and replaced with a new login if it has
expired.

## EXAMPLES

### Example 1
```powershell
PS C:\> Connect-CWC -Server 'control.example.com' -Credentials (Get-Credential)
```

Connects with an account that does not use MFA.

### Example 2
```powershell
PS C:\> Connect-CWC -Server 'control.example.com' -Credentials (Get-Credential) -Mfa
```

Connects with an account that requires MFA and asks for the one-time code.

### Example 3
```powershell
PS C:\> Connect-CWC -Server 'control.example.com' -Credentials $Credential -OneTimeCode (Read-Host 'One-time code')
```

Connects with an account that requires MFA, using a code you supply.
Reading it with Read-Host keeps it out of the command history.

### Example 4
```powershell
PS C:\> $Credential = Get-Secret -Name 'CWC-Login'
PS C:\> Connect-CWC -Server 'control.example.com' -Credentials $Credential -TotpSecret (Get-Secret -Name 'CWC-TOTP')
```

Unattended login for an account that requires MFA.
Run it again before each batch of work: when the cached login is still valid it costs one call, and when
it has expired it logs in again.

### Example 5
```powershell
PS C:\> $Secret = Read-Host -AsSecureString -Prompt 'RESTful API secret'
PS C:\> Connect-CWC -Server 'control.example.com' -ApiSecret $Secret
```

Connects with the RESTful API Manager extension's secret.

## PARAMETERS

### -Server
Control server hostname, e.g. control.example.com. A leading http(s):// is removed. HTTPS is always used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credentials
Username and password of a Control user account.

```yaml
Type: PSCredential
Parameter Sets: Credentials, TotpSecret, OneTimeCode, Mfa
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Mfa
Sign in for an account that requires MFA, asking for the one-time code at the console when the server
requests it. Works with authenticator apps and with codes the server sends by email or SMS (they are sent
at this point). For interactive use only.

```yaml
Type: SwitchParameter
Parameter Sets: Mfa
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -OneTimeCode
The current one-time code (6 to 8 digits) for an account that requires MFA.
Quote it, so a leading zero is kept.

```yaml
Type: String
Parameter Sets: OneTimeCode
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TotpSecret
The account's authenticator-app (TOTP) secret, for unattended scripts.
The current code is computed from it at each login; the secret itself is not stored.
Accepts the value Control stores for authenticator apps ("ms:" followed by Base32, as New-CWCMFA creates)
or bare Base32. Not for email or SMS codes.

Keep it in a secret store, e.g. Microsoft.PowerShell.SecretManagement: -TotpSecret (Get-Secret ...).
A TOTP secret stored next to the password turns MFA into a single factor: keep them in separate vaults
where you can, prefer -ApiSecret when its functions are enough, and replace the secret if the computer is
compromised.

```yaml
Type: SecureString
Parameter Sets: TotpSecret
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiSecret
The RESTful API Manager extension's RESTfulAuthenticationSecret value.

```yaml
Type: SecureString
Parameter Sets: ApiSecret
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Origin
Origin header sent with -ApiSecret requests. Defaults to https://<Server>. Set it to match the
extension's RESTfulAllowedOrigin setting if that setting is configured.

```yaml
Type: String
Parameter Sets: ApiSecret
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Reconnect even when the cached connection is for the same server, method and identity.
If that refresh fails, the previous connection is kept.
A failed connection to a different server, method or identity leaves the module disconnected, so later
commands can't reach the old server.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Functions available with -ApiSecret: Get-CWCSessionDetail, Update-CWCSessionName, Invoke-CWCCommand
(queues the command; output is not retrieved), Find-CWCSession, New-CWCSession, Add-CWCSessionNote,
Send-CWCSessionMessage, Send-CWCToolboxItem.
Only calls that are safe to repeat (reads, "set to value" updates) are retried on HTTP 500.

The API secret is not tied to a Control user: the extension does not apply role permissions or session
group scoping, so it can act on every session. Treat it like an administrator password.
Requires the RESTful API Manager extension (2d558935-686a-4bd0-9991-07539f5fe749).

MFA logins are never retried automatically: each attempt counts toward the server's login limits.
Errors carry an ErrorId: CWC.MfaRequired, CWC.MfaCodeRejected, CWC.LoginFailed, CWC.LoginThrottled or
CWC.NoResponse. The device is never marked as trusted, and the login is never saved to disk.

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)
