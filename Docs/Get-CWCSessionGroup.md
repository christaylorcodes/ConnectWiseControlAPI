---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCSessionGroup

## SYNOPSIS
Returns all session groups.

## SYNTAX

```
Get-CWCSessionGroup [<CommonParameters>]
```

## DESCRIPTION
Calls SessionGroupService.GetSessionGroups.
Requires the ManageSessionGroups permission.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCSessionGroup | Select-Object Name, SessionType
```

## PARAMETERS


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

