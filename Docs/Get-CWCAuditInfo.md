---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Get-CWCAuditInfo

## SYNOPSIS
Used to search the audit logs.

## SYNTAX

```
Get-CWCAuditInfo [[-StartDate] <DateTime>] [[-EndDate] <DateTime>] [[-SessionName] <String>]
 [[-EventTypes] <Int32[]>] [<CommonParameters>]
```

## DESCRIPTION
You can search the audit logs and apply some filters.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-CWCAuditInfo -StartDate $(Get-Date).AddDays(-1) -EndDate $(Get-Date) -SessionName 'Computer1'
```

Get the audit logs for Computer1 for the last day.

## PARAMETERS

### -EndDate
End date for the date range to search for logs.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EventTypes
The [event type](https://docs.connectwise.com/ConnectWise_Control_Documentation/Developers/Session_events) you want to search for.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SessionName
Name of the session to search for logs

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartDate
Start date for the date range to search for logs.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
