---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Remove-CWCToolboxItem

## SYNOPSIS
Deletes a file or folder from the shared ScreenConnect Toolbox.

## SYNTAX

```
Remove-CWCToolboxItem [-Path] <String> [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Calls ToolboxService.ProcessToolboxOperation with the Delete operation.
The user needs the
ManageSharedToolbox permission.

Only items stored in the server's Toolbox folder can be deleted.
Items that an extension adds
(for example Command Toolbox commands) are refused by the server with "Cannot edit virtual toolbox
item".

After the delete the command lists the Toolbox and returns CWC.ToolboxItemNotRemoved when the item,
or something inside a deleted folder, is still there: the server can answer success and leave a file
it has open, for example one that is queued to run.

## EXAMPLES

### EXAMPLE 1
```
Remove-CWCToolboxItem -Path 'Scripts/Cleanup.cmd'
```

### EXAMPLE 2
```
Get-CWCToolbox | Where-Object Path -like 'API Test/*.cmd' | Remove-CWCToolboxItem -Confirm:$false
```

## PARAMETERS

### -Path
Path of the item inside the Toolbox, e.g.
'Cleanup.cmd' or 'Scripts/Cleanup.cmd': the Path that
Get-CWCToolbox returns.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
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
Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot change the Toolbox).
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

