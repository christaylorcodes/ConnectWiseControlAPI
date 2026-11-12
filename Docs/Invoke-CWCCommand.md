---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Invoke-CWCCommand

## SYNOPSIS
Runs a command on a session's machine and returns its output.

## SYNTAX

```
Invoke-CWCCommand [-GUID] <Guid> [[-Command] <String>] [[-TimeOut] <Int32>] [[-MaxLength] <Int32>]
 [-PowerShell] [[-Group] <String[]>] [-NoWait] [<CommonParameters>]
```

## DESCRIPTION
Queues a QueuedCommand event (44) and polls the session's events until the matching RanCommand
output (70) arrives or -TimeOut passes.

API secret connections queue the command through the RESTful API Manager extension; the output is
not retrieved (a warning says so unless -NoWait is used).

## EXAMPLES

### EXAMPLE 1
```
Invoke-CWCCommand -GUID $SessionID -Command 'hostname'
```

Runs hostname in cmd.exe on the machine and returns its output.

### EXAMPLE 2
```
Invoke-CWCCommand -GUID $SessionID -Command 'Get-Service Spooler' -PowerShell -TimeOut 30000
```

Runs a PowerShell command and waits up to 30 seconds for its output.

## PARAMETERS

### -GUID
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

### -Command
Command line to run (cmd.exe unless -PowerShell is used).

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

### -TimeOut
Milliseconds the command may run, and how long to wait for its output.
Defaults to 10000.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 10000
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxLength
Maximum number of characters of output to return.
Defaults to 10000.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 10000
Accept pipeline input: False
Accept wildcard characters: False
```

### -PowerShell
Run the command in PowerShell.

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

### -Group
Session group containing the session: a name, or the path parts of a nested group.
Defaults to
'All Machines'.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoWait
Queue the command and return without waiting for output.

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


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

