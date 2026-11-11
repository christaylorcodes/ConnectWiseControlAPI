---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Remove-CWCHostFromSession

## SYNOPSIS
Disconnects one connection (for example a host) from a session.

## SYNTAX

```
Remove-CWCHostFromSession [-SessionID] <Guid> [-ConnectionID] <Guid> [-Group] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Queues a QueuedForceDisconnect session event (type 48) for the given connection, the same
action as disconnecting a participant in the ScreenConnect web UI.
Connection IDs are listed in
(Get-CWCSessionDetail -GUID \<session\> -Include Connections).Connections.

## EXAMPLES

### EXAMPLE 1
```
$Connections = (Get-CWCSessionDetail -GUID $SessionID -Include Connections).Connections
$HostConnection = $Connections | Where-Object { $_.ProcessType -eq 1 } | Select-Object -First 1
Remove-CWCHostFromSession -SessionID $SessionID -ConnectionID $HostConnection.ConnectionID -Group 'All Machines'
```

Disconnects the first host connected to the session (ProcessType 1 = Host).

## PARAMETERS

### -SessionID
Session ID.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConnectionID
ID of the connection to disconnect.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Session group containing the session: a name, or the path parts of a nested group.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
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
Contributed by turbo-donkey (#28).
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

