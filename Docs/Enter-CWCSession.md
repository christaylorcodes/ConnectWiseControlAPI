---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Enter-CWCSession

## SYNOPSIS
Opens the ConnectWise ScreenConnect Host client joined to a session, like Join in the web UI.

## SYNTAX

```
Enter-CWCSession [-GUID] <Guid> [[-Type] <Object>] [[-Group] <String[]>] [[-Name] <String>] [-UrlOnly] [<CommonParameters>]
```

## DESCRIPTION
Gets a Host access token for the session (PageService.GetAccessToken), builds the client launch
URL the web client uses (sc-\<instance\>://...) and opens it with the installed ScreenConnect client.
The join is recorded in the session's audit trail (InitiatedJoin), as a web UI join is.

The client must already be installed for the current Windows user: join any session once from
the web UI.
Launching works on Windows only; on other systems use -UrlOnly and open the URL
yourself.

Requires Connect-CWC -Credentials and the JoinSession permission in -Group.

## EXAMPLES

### EXAMPLE 1
```
Enter-CWCSession -GUID 'a1b2c3d4-0000-0000-0000-000000000000'
```

### EXAMPLE 2
```
Get-CWCSession -Type Access -Search 'DESKTOP-01' -Limit 1 | Enter-CWCSession
```

### EXAMPLE 3
```
$Url = Enter-CWCSession -GUID $SessionID -UrlOnly
open $Url   # macOS
```

## PARAMETERS

### -GUID
Session ID.
Accepts SessionID from the pipeline (e.g.
from Get-CWCSession).

```yaml
Type: Guid
Parameter Sets: (All)
Aliases: SessionID

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Type
Session type.
Defaults to Access.

```yaml
Type: Object
Parameter Sets: (All)
Aliases: SessionType

Required: False
Position: 2
Default value: Access
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Group
Session group containing the session: a name, or the path parts of a nested group.
Defaults to
'All Machines' for Access, 'All Sessions' for Support and 'All Meetings' for Meeting.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Session name shown as the client's title.
Taken from the pipeline (e.g.
from Get-CWCSession);
when given, the session lookup is skipped.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -UrlOnly
Return the launch URL instead of opening the client.
The URL holds an access token: treat it
like a password.
It uses a delegated token that expires in 5 minutes when your role has the
CreateDelegatedAccessToken permission; otherwise a regular Host token (with a warning), which
is valid for the server's access token lifetime (7 days by default).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String
## NOTES
The access token is not written to verbose, debug, warning or error output.
It does appear in
the launched client's command line (as with a web UI join), and PowerShell module or
script-block logging, when enabled, can record the API response that carries it.
The token is tied to the public IP address this call comes from, so the URL may not work from
another network (a different proxy or VPN exit).

Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

