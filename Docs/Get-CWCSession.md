---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Get-CWCSession

## SYNOPSIS
Will return a list of sessions.

## SYNTAX

```
Get-CWCSession -Type <Object> [-Group <String>] [-Search <String>] [-Limit <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Allows you to search for access or service sessions.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCAccessSessions -Search "server1" -Limit 10
```

Will return the first 10 access sessions that match 'server1'.

## PARAMETERS

### -Type
The type of session Support/Access

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Name of session group to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```

### -Search
Limit results with search pattern.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
Limit the number of results returned.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### ConnectWise Control session objects
## NOTES
Version:        1.0
Author:         Chris Taylor
Creation Date:  10/10/2018
Purpose/Change: Initial script development

## RELATED LINKS
