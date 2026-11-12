---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Initialize-CWCRemoteWorkforceSessionGroup

## SYNOPSIS
Creates or repairs the session group used by the Remote Workforce extension.

## SYNTAX

```
Initialize-CWCRemoteWorkforceSessionGroup [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Calls the Remote Workforce extension's EnsureCorrectSessionGroupExists endpoint.
The extension
creates its Access session group (name from the SessionGroupName setting, "My Assigned Machines"
by default) with the filter Notes LIKE '*|UserName:' + $USERLOGINNAME + ',*', or repairs an
older group whose filter was missing the trailing comma.
Without this group, assignments made
with New-CWCRemoteWorkforceAssignment are not visible to users.

Idempotent.
Requires the Administer permission.

## EXAMPLES

### EXAMPLE 1
```
Initialize-CWCRemoteWorkforceSessionGroup
```

## PARAMETERS

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
Requires Connect-CWC -Credentials.
Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), ScreenConnect 23.6+.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

