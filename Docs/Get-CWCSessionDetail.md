---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCSessionDetail

## SYNOPSIS
Returns the details of a session: session info, events, connections and guest screenshot.

## SYNTAX

```
Get-CWCSessionDetail [[-Group] <String[]>] [-GUID] <Guid> [[-Include] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Credentials connections: PageService.GetSessionDetails.
Event Time values are milliseconds elapsed
since the event, relative to the response's BaseTime.
The call is rate limited by the server.

API secret connections: the RESTful API Manager extension's GetSessionDetailsBySessionID, which
returns the server's raw session details; -Group and -Include are ignored.

## EXAMPLES

### EXAMPLE 1
```
(Get-CWCSessionDetail -GUID $SessionID -Include Events).Events | Where-Object EventType -eq 32
```

Returns the note events of the session (event type 32 is AddedNote), without downloading the
screenshot.
A deleted note stays in the list; a later event whose CorrelationEventID is the note's
EventID marks it as deleted.

## PARAMETERS

### -Group
Session group containing the session: a name, or the path parts of a nested group.
Defaults to
'All Machines'.

```yaml
Type: String[]
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

### -Include
Parts to return: SessionInfo, GuestScreenshotContent, Events, Connections.
Omit for everything,
including the guest screenshot.
Request only what you need when polling.
Ignored on API secret
connections.

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


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### The session details object the server returns.
## NOTES
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

