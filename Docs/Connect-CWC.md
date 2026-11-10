---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version:
schema: 2.0.0
---

# Connect-CWC

## SYNOPSIS
Initializes the connection parameters for the module.

## SYNTAX

### Credentials (Default)
```
Connect-CWC -Server <String> -Credentials <PSCredential> [-Force]
 [<CommonParameters>]
```

### ApiSecret
```
Connect-CWC -Server <String> -ApiSecret <SecureString> [-Origin <String>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
Initializes the connection parameters used by other commands in the module.

## EXAMPLES

### Example 1
```powershell
PS C:\> Connect-CWC -Server 'control.christaylor.codes' -Credentials $Credentials -Force
```

Sets connection information used by the module and overwrites any previously set information.

## PARAMETERS

### -Server
The URL to your control server.

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

### -Credentials
Credentials used to authenticate with the control server.

```yaml
Type: PSCredential
Parameter Sets: Credentials
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiSecret
The RESTful API Manager extension's RESTfulAuthenticationSecret value.

```yaml
Type: SecureString
Parameter Sets: ApiSecret
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Origin
Origin header sent with -ApiSecret requests. Defaults to https://<Server>. Set it to match the
extension's RESTfulAllowedOrigin setting if that setting is configured.

```yaml
Type: String
Parameter Sets: ApiSecret
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Used to overwrite any information already loaded in the session.

```yaml
Type: SwitchParameter
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

## RELATED LINKS
