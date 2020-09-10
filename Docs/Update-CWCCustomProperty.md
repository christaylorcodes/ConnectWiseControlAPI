---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Update-CWCCustomProperty

## SYNOPSIS
Will update a custom property for a session.

## SYNTAX

```
Update-CWCCustomProperty -GUID <Guid> -Property <Int32> [-Value <String>] [-Group <String[]>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Will update a custom property for a session.

## EXAMPLES

### EXAMPLE 1
```
Update-CWCCustomProperty -GUID $GUID -Property 2 -Value 'New Department'
```

Will update the sessions department to 'New Department'

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

### -Group
Look for the session in these groups.

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

### -Property
The property number of the property you want to change.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Value
The value you want to set the property to.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

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
