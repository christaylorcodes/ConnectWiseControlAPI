---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# New-CWCAccessToken

## SYNOPSIS
Gets an access token for joining a session.

## SYNTAX

```
New-CWCAccessToken [[-Group] <String>] [-GUID] <Guid> [<CommonParameters>]
```

## DESCRIPTION
Calls PageService.GetAccessToken.
The token lets a Host client join the session with the
connected user's permissions for that session group; the user needs the JoinSession
permission in -Group.
Treat the token as a secret.

## EXAMPLES

### EXAMPLE 1
```
$Token = New-CWCAccessToken -GUID $SessionID
```

## PARAMETERS

### -Group
Session group containing the session.
Defaults to 'All Machines'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```

### -GUID
Session ID.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Requires Connect-CWC -Credentials.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

