---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Remove-CWCSession

## SYNOPSIS
Will end a given session.

## SYNTAX

```
Remove-CWCSession [-GUID] <Guid[]> [-Group] <String[]> [-Uninstall]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Will end a given access or support session.

## EXAMPLES

### EXAMPLE 1
```powershell
Remove-CWCAccessSession -GUID $GUID
```

Will remove the given access session

## PARAMETERS

### -GUID
The GUID identifier for the session you wish to end.
Accepts an array of GUIDs.

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
Session group containing the session(s). Defaults to 'All Machines' where a default exists.

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
Queue an uninstall of the Access client and delete the session (QueuedUninstallAndDelete) instead of only deleting the session record.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

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
Version:        1.0
Author:         Chris Taylor
Creation Date:  10/10/2018
Purpose/Change: Initial script development

## RELATED LINKS
