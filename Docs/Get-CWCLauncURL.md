---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCLauncURL

## SYNOPSIS
DEPRECATED.
Use Get-CWCRemoteWorkforceLaunchURL.

## SYNTAX

```
Get-CWCLauncURL [-GUID] <Guid[]> [[-OnSuccess] <String>] [[-OnFailure] <String>] [[-UserContext] <String>]
 [[-UserNameOverride] <String>] [[-PasswordOverride] <SecureString>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Retained for backwards compatibility.
Forwards -GUID to Get-CWCRemoteWorkforceLaunchURL.
The Remote Workforce GetLaunchUrlForSessionId endpoint takes only a session ID, so the
OnSuccess, OnFailure, UserContext, UserNameOverride and PasswordOverride parameters are
ignored.
This function will be removed in v1.0.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCRemoteWorkforceLaunchURL -GUID $SessionID
```

## PARAMETERS

### -GUID
One or more session IDs.

```yaml
Type: Guid[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnSuccess
Ignored.
Not accepted by the server.

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

### -OnFailure
Ignored.
Not accepted by the server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserContext
Ignored.
Not accepted by the server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserNameOverride
Ignored.
Not accepted by the server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PasswordOverride
Ignored.
Not accepted by the server.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
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
Deprecated in favor of Get-CWCRemoteWorkforceLaunchURL.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

