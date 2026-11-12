---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Invoke-CWCWake

## SYNOPSIS
Sends a wake (Wake-on-LAN) request to sessions.

## SYNTAX

```
Invoke-CWCWake [-GUID] <Guid[]> [-Type] <String> [<CommonParameters>]
```

## DESCRIPTION
Queues a QueuedWake event (43) for each session, in the built-in group for -Type.

## EXAMPLES

### EXAMPLE 1
```
Invoke-CWCWake -GUID $SessionID -Type Access
```

## PARAMETERS

### -GUID
One or more session IDs.

```yaml
Type: Guid[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Type
Session type: Support or Access.

```yaml
Type: String
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
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

