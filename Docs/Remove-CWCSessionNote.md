---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Remove-CWCSessionNote

## SYNOPSIS
Removes notes from a session.

## SYNTAX

### ById (Default)
```
Remove-CWCSessionNote -GUID <Guid> -NoteEventID <Guid[]> [-Group <String[]>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### All
```
Remove-CWCSessionNote -GUID <Guid> [-All] [-Group <String[]>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes notes (AddedNote events) by adding a DeletedEvent correlated to each note, the same way
the Control web UI removes a note.
The user needs the RemoveNote permission in -Group.

-NoteEventID removes specific notes; -All removes every note still on the session.
Notes that
are already deleted are skipped.

## EXAMPLES

### EXAMPLE 1
```
Remove-CWCSessionNote -GUID $SessionID -All
```

Removes every note on the session, prompting for each one.

### EXAMPLE 2
```
$Notes = (Get-CWCSessionDetail -GUID $SessionID -Include Events).Events | Where-Object EventType -eq 32
$Notes | Where-Object Data -like 'Rebooted*' | ForEach-Object {
    Remove-CWCSessionNote -GUID $SessionID -NoteEventID $_.EventID -Confirm:$false
}
```

## PARAMETERS

### -GUID
Session ID.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases: SessionID

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoteEventID
Event ID of each note to remove (the EventID of an AddedNote event in Get-CWCSessionDetail).

```yaml
Type: Guid[]
Parameter Sets: ById
Aliases: EventID

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Remove every note on the session.

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Session group containing the session: a name, or the path parts of a nested group.
Defaults to 'All Machines'.

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
Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot delete notes).
Based on the design in #27 by CitybookServicesLTD.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

