---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# New-CWCUser

## SYNOPSIS
Creates an internal user.

## SYNTAX

```
New-CWCUser [-Credentials] <PSCredential> [[-OTP] <String>] [[-DisplayName] <String>] [-Email] <String>
 [[-SecurityGroups] <String[]>] [[-ForcePassChange] <Boolean>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Calls SecurityService.SaveUser.
The password is never written to verbose or debug output.

## EXAMPLES

### EXAMPLE 1
```
$Credentials = Get-Credential -UserName 'jdoe' -Message 'Password for the new user'
New-CWCUser -Credentials $Credentials -Email 'jdoe@example.com' -SecurityGroups 'Technicians'
```

Creates the user jdoe in the Technicians role.
The user must change the password at first login.

### EXAMPLE 2
```
$Mfa = New-CWCMFA -UserAccount 'jdoe'
New-CWCUser -Credentials $Credentials -OTP $Mfa.OTP -SecurityGroups 'Technicians' -ForcePassChange $false
```

Creates the user with an authenticator-app secret and without a forced password change.

## PARAMETERS

### -Credentials
User name and password of the new user.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OTP
The OTP key used for MFA.
Can be generated with New-CWCMFA.

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

### -DisplayName
Display name.

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

### -Email
Email address.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecurityGroups
Roles the user is a member of.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ForcePassChange
Force the user to change their password at next login.
Defaults to $true.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: True
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

