---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCAuditLog

## SYNOPSIS
Returns audit log entries for a time range.

## SYNTAX

```
Get-CWCAuditLog [[-StartDate] <DateTime>] [[-EndDate] <DateTime>] [[-SessionName] <String>]
 [-IncludeSessionCaptures] [[-EventTypes] <Int32[]>] [[-SecurityTypes] <Int32[]>] [<CommonParameters>]
```

## DESCRIPTION
Calls AuditService.QueryAuditLog.
Times are converted to UTC.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCAuditLog -StartDate (Get-Date).AddDays(-7) -SessionName 'DESKTOP-01'
```

Returns the last 7 days of audit entries for the session named DESKTOP-01.

## PARAMETERS

### -StartDate
Start of the time range.
Defaults to 24 hours ago.
Local times are converted to UTC.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-Date).AddDays(-1)
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndDate
End of the time range.
Defaults to now.
Local times are converted to UTC.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: (Get-Date)
Accept pipeline input: False
Accept wildcard characters: False
```

### -SessionName
Only return entries for sessions with this name.

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

### -IncludeSessionCaptures
Deprecated.
The server no longer accepts this option; it is ignored with a warning.

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

### -EventTypes
Session event type numbers to include, for example 44 (QueuedCommand) or 70 (RanCommand).

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecurityTypes
Security event type numbers to include.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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

