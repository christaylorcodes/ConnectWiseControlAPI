---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Invoke-CWCWake

## SYNOPSIS
Will issue a wake command to a given session.

## SYNTAX

```
Invoke-CWCWake -GUID <Guid[]> -Type <String> [<CommonParameters>]
```

## DESCRIPTION
Will issue a wake command to a given access or support session.

## EXAMPLES

### EXAMPLE 1
```
End-CWWake -GUID $GUID
```

Will issue a wake command to a given session.

## PARAMETERS

### -GUID
The GUID identifier for the session you wish to end.
Accepts an array of GUIDs

```yaml
Type: Guid[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Type
The type of session Support/Access

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.0
Author:         Chris Taylor
Creation Date:  12/7/2018
Purpose/Change: Initial script development

## RELATED LINKS
