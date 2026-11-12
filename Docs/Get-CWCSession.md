---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCSession

## SYNOPSIS
Lists sessions of one type in a session group.

## SYNTAX

```
Get-CWCSession [-Type] <Object> [[-Group] <String[]>] [[-Search] <String>] [[-FindSessionID] <String>]
 [[-Limit] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Calls PageService.GetLiveData, the same query the web UI's session list uses.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCSession -Type Access -Search 'DESKTOP-01' -Limit 1
```

Returns the first Access session that matches DESKTOP-01.
Its SessionID is the -GUID the other
session commands take.

## PARAMETERS

### -Type
Session type: Support, Access or Meeting.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Session group: a name, or the path parts of a nested group (e.g.
'Clients','Acme').
Defaults to
the built-in group for -Type: 'All Machines' (Access), 'All Sessions' (Support) or
'All Meetings' (Meeting).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Search
Filter text, as typed in the web UI's search box.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FindSessionID
Session ID to locate, so it is included even when -Limit would cut it off.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
Maximum number of sessions to return.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### ScreenConnect session objects.
## NOTES
Requires Connect-CWC -Credentials.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

