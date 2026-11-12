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
Send-CWCToolboxItem [-GUID] <Guid> [-Name] <String> [[-Group] <String[]>] [-Elevated] [-Silent] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Queues a QueuedTool session event naming the Toolbox item.
-Elevated queues a QueuedElevatedTool
event instead, which runs the item with administrative privileges; -Silent queues a
QueuedSilentElevatedTool event, which runs it elevated and silently.

-Elevated and -Silent ask for confirmation, like the Remove-* commands: the item runs with
administrative rights, and with -Silent nobody at the machine sees it.
Pass -Confirm:$false in
unattended scripts.

For an unattended run use -Silent.
With -Elevated the server queued the event, but the item did not
start on a machine that had no host connected (seen live, 2026-11-12).

The machine opens the item the way Windows opens a file, so use a file type that runs when opened
(.exe, .msi, .cmd, .bat): a .ps1 opens in its default program instead of running.

Credentials connections: PageService.AddSessionEvents; the user needs the RunSharedTool
permission in -Group.

API secret connections: the RESTful API Manager extension's SendToolboxItemToSession.
The event
is attributed to the extension's RESTfulUserName setting ("RESTful API" unless renamed); -Group
is ignored.
-Elevated and -Silent are not available: the extension only queues the standard event.

## EXAMPLES

### EXAMPLE 1
```
Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.cmd'
```

### EXAMPLE 2
```
Send-CWCToolboxItem -GUID $SessionID -Name 'Installers/Setup.exe' -Elevated
```

Asks for confirmation, then runs the item with administrative privileges.

### EXAMPLE 3
```
Send-CWCToolboxItem -GUID $SessionID -Name 'Cleanup.cmd' -Silent -Confirm:$false
```

Runs the item elevated and silently, without asking.

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
Toolbox item name as shown in the ScreenConnect Toolbox.
For an item in a folder, the Path that
Get-CWCToolbox returns.

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
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```

### -Elevated
Run the item with administrative privileges (QueuedElevatedTool).
Credentials connections only.

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

### -Silent
Run the item elevated and silently (QueuedSilentElevatedTool): it runs as NT AUTHORITY\SYSTEM
(seen live, 2026-11-11).
Implies -Elevated.
Credentials connections only.

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

