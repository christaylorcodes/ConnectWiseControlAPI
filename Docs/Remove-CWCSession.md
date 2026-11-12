---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Remove-CWCSession

## SYNOPSIS
Deletes sessions, optionally uninstalling the Access client first.

## SYNTAX

```
Remove-CWCSession [-GUID] <Guid[]> [-Group] <String[]> [-Uninstall]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Queues a DeletedSession event (21) per session, or QueuedUninstallAndDelete (100) with -Uninstall.
Prompts for each session by default (ConfirmImpact High); use -Confirm:$false in unattended scripts.

## EXAMPLES

### EXAMPLE 1
```
Remove-CWCSession -GUID $SessionID -Group 'All Machines' -Uninstall -Confirm:$false
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

### -Group
Session group containing the sessions: a name, or the path parts of a nested group.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Uninstall
Uninstall the Access client from the machine and delete the session, instead of only deleting the
session record.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
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
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

