---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Find-CWCSession

## SYNOPSIS
Finds sessions by session filter expression, name or ID (API secret connections).

## SYNTAX

### Filter (Default)
```
Find-CWCSession -Filter <String> [<CommonParameters>]
```

### Name
```
Find-CWCSession -Name <String> [<CommonParameters>]
```

### GUID
```
Find-CWCSession -GUID <Guid> [<CommonParameters>]
```

## DESCRIPTION
Calls the RESTful API Manager extension.
Searches all sessions of every type; results are not
limited by role permissions or session groups.

-Filter uses Control's session filter syntax, the same syntax as session group filters,
e.g.
"Name LIKE 'DESKTOP-*'" or "CustomProperty1 = 'Acme'".

## EXAMPLES

### EXAMPLE 1
```
Find-CWCSession -Filter "GuestOperatingSystemName LIKE '*Server*'"
```

### EXAMPLE 2
```
Find-CWCSession -Name 'DESKTOP-01'
```

## PARAMETERS

### -Filter
A session filter expression (GetSessionsByFilter).

```yaml
Type: String
Parameter Sets: Filter
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Exact session name (GetSessionsByName).
Single quotes are not allowed because the extension
inserts the name into a filter expression without escaping.

```yaml
Type: String
Parameter Sets: Name
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -GUID
Session ID (GetSessionBySessionID).

```yaml
Type: Guid
Parameter Sets: GUID
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
Requires Connect-CWC -ApiSecret and the RESTful API Manager extension.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

