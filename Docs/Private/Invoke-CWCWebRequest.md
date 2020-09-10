---
external help file:
Module Name:
online version:
schema: 2.0.0
---

# Invoke-CWCWebRequest

## SYNOPSIS
Used to make the web requests for the module

## SYNTAX

```
Invoke-CWCWebRequest [[-Arguments] <Object>] [[-MaxRetry] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Used by the module to invoke requests and handle errors

## EXAMPLES

### Example 1
```powershell
PS C:\> Invoke-CWCWebRequest -Arguments $Args
```

Passes a set of arguments to the web request handler.

## PARAMETERS

### -Arguments
An object containing parameters for the web request

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxRetry
amount of times a request will be attempted before failing

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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
