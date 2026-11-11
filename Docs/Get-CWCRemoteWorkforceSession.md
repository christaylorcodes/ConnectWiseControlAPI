---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCRemoteWorkforceSession

## SYNOPSIS
Lists the Remote Workforce machines assigned to the calling user.

## SYNTAX

```
Get-CWCRemoteWorkforceSession [<CommonParameters>]
```

## DESCRIPTION
Calls the Remote Workforce extension's GetRemoteWorkforceSessions endpoint, which returns the
sessions in the extension's session group for the CALLING user that they can view and join.
The server's name-to-ID map is returned as objects with Name and SessionID properties.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCRemoteWorkforceSession
```

### EXAMPLE 2
```
Get-CWCRemoteWorkforceSession | Get-CWCRemoteWorkforceLaunchURL
```

## PARAMETERS


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Requires the Remote Workforce extension (2c4f522f-b39a-413a-8807-dc52a2fce13e), ScreenConnect 23.6+.
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

