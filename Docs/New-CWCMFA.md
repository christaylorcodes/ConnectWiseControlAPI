---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# New-CWCMFA

## SYNOPSIS
Creates a new authenticator-app (TOTP) secret for a ScreenConnect user.

## SYNTAX

```
New-CWCMFA [[-DisplayName] <Object>] [[-UserAccount] <Object>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Generates a random 16-character Base32 secret.
Returns it in the form ScreenConnect stores ("ms:\<secret\>") together with a QR code URL to scan with an
authenticator app.
Nothing is sent to the ScreenConnect server: pass the OTP value to New-CWCUser or Update-CWCUser to set it on
an account.

The QR code URL is on quickchart.io and contains the secret.
Open it only if you accept sending the secret to that service.

## EXAMPLES

### Example 1
```powershell
PS C:\> New-CWCMFA -DisplayName 'My ScreenConnect Server' -UserAccount 'CTaylor'
```

Creates an MFA OTP code and QR URL with the provided information.

## PARAMETERS

### -DisplayName
Label the authenticator app shows for the entry.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: ScreenConnect
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserAccount
User account to display in OTP app.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### None
## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
