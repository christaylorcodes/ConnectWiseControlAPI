---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Add-CWCRemoteWorkforceRequiredRole

## SYNOPSIS
Creates the security role required by the Remote Workforce extension.

## SYNTAX

```
Add-CWCRemoteWorkforceRequiredRole [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Calls the Remote Workforce extension's EnsureRemoteWorkforceSecurityRoleExists endpoint.
The extension creates its role (name from the extension's RoleName setting, "Remote Workforce"
by default) with View Session Group, Join Session and Host Session Without Consent scoped to the
extension's session group, then marks the role as created in the extension settings.

Idempotent: if the role already exists nothing is changed.
Requires the Administer permission.

## EXAMPLES

### EXAMPLE 1
```
Add-CWCRemoteWorkforceRequiredRole
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
Pair with Initialize-CWCRemoteWorkforceSessionGroup.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

