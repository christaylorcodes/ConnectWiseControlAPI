---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Get-CWCLastContact

## SYNOPSIS
Returns the date the machine last connected to the control server.

## SYNTAX

```
Get-CWCLastContact [-GUID] <Guid> [-Quiet] [[-Seconds] <Int32>] [[-Group] <String>] [<CommonParameters>]
```

## DESCRIPTION
Returns the date the machine last connected to the control server.

## EXAMPLES

### EXAMPLE 1
```powershell
Get-CWCLastContact -GUID $GUID
```

Will return the last contact of the machine with that GUID.

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
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
Will output a boolean result, $True for Connected or $False for Offline.

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

### -Seconds
Used with the Quiet switch.
The number of seconds a machine needs to be offline before returning $False.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Name of session group to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: All Machines
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [datetime] -or [boolean]
## NOTES
Version:        1.1
Author:         Chris Taylor
Creation Date:  1/20/2016
Purpose/Change: Initial script development

Update Date:  8/24/2018
Purpose/Change: Fix Timespan Seconds duration

## RELATED LINKS
