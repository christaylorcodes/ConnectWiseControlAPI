---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCLastContact

## SYNOPSIS
Returns when a machine was last connected, or whether it connected recently.

## SYNTAX

```
Get-CWCLastContact -GUID <Guid> [-Quiet] [-Seconds <Int32>] [-Group <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Reads the session's connect/disconnect events.
Returns the current time if the guest is connected
now, otherwise the time of its last disconnect.
With -Quiet, returns $True when the guest is
connected or was connected within -Seconds, else $False.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCLastContact -GUID $SessionID -Quiet -Seconds 300
```

Returns $True when the machine is connected or was connected in the last 5 minutes.

## PARAMETERS

### -GUID
Session ID.

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

### -Quiet
Return $True or $False instead of a date.

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

### -Seconds
Used with -Quiet: how recent the last contact must be to count.
Defaults to 0, so only a guest that
is connected now counts.

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

### -Group
Session group containing the session: a name, or the path parts of a nested group.
Defaults to
'All Machines'.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Boolean
### System.DateTime
## NOTES
Requires Connect-CWC -Credentials.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

