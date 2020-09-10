---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Update-CWCSessionName

## SYNOPSIS
Updates the name of a session.

## SYNTAX

```
Update-CWCSessionName -GUID <Guid> -NewName <String> [-Group <String>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Updates the name of a session on the control server.

## EXAMPLES

### EXAMPLE 1
```powershell
Update-CWCSessionName -GUID $GUID -NewName 'Session1'
```

Will rename the session to Session1

## PARAMETERS

### -GUID
The GUID/SessionID for the machine you wish to connect to.
You can retrieve session info with the 'Get-CWCSessions' commandlet

On Windows clients, the launch parameters are located in the registry at:
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ScreenConnect Client (xxxxxxxxxxxxxxxx)\ImagePath
On Linux and Mac clients, it's found in the ClientLaunchParameters.txt file in the client installation folder:
    /opt/screenconnect-xxxxxxxxxxxxxxxx/ClientLaunchParameters.txt

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

### -NewName
The new name for the session.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Group to look for the session in.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: All Machines
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.1
Author:         Chris Taylor
Creation Date:  10/25/2018
Purpose/Change: Initial script development

## RELATED LINKS
