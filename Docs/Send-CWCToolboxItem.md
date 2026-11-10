---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Send-CWCToolboxItem

## SYNOPSIS
Queues a Toolbox item to run on a session.

## SYNTAX

```
Send-CWCToolboxItem [-GUID] <Guid> [-Name] <String> [[-Group] <String>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Queues a QueuedTool session event naming the Toolbox item.

Credentials connections: PageService.AddSessionEvents; the user needs the RunSharedTool
permission in -Group.

API secret connections: the RESTful API Manager extension's SendToolboxItemToSession; -Group is ignored.

## EXAMPLES

### EXAMPLE 1
```
Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.ps1'
```

## PARAMETERS

### -GUID
Session ID.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases: SessionID

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
Toolbox item name as shown in the Control Toolbox.

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

### -Group
Session group containing the session (credentials connections only).
Defaults to 'All Machines'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All Machines
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

