---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Get-CWCSessionDetail

## SYNOPSIS
Will return information about a session.

## SYNTAX

```
Get-CWCSessionDetail [-Group <String>] -GUID <Guid> [<CommonParameters>]
```

## DESCRIPTION
Dispays more information about a session.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCAccessSessions -Search "server1" -Limit 10
```

Will return the first 10 access sessions that match 'server1'.

## PARAMETERS

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

### -GUID
GUID of the machine to retreive session details.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
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
Creation Date:  1/15/2019
Purpose/Change: Initial script development

## RELATED LINKS
