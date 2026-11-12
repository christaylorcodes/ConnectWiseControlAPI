---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCRemoteWorkforceLaunchURL

## SYNOPSIS
Gets a Remote Workforce host launch URL for an assigned machine.

## SYNTAX

### GUID (Default)
```
Get-CWCRemoteWorkforceLaunchURL -GUID <Guid[]> [<CommonParameters>]
```

### SessionName
```
Get-CWCRemoteWorkforceLaunchURL -SessionName <String> [<CommonParameters>]
```

## DESCRIPTION
Calls the Remote Workforce extension's GetLaunchUrlForSessionId (by session GUID) or
GetLaunchUrl (by session name) endpoint and returns a ClickOnce launch URL.

The extension only returns a URL when the CALLING user is the user the machine is assigned to
(the session is in their Remote Workforce session group, "My Assigned Machines" by default)
and has View and Join permissions on that group.
Otherwise the server returns null and this
function writes a warning.
An administrator cannot get launch URLs for other users' machines.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCRemoteWorkforceLaunchURL -GUID 'd2b6f0a1-1111-2222-3333-444455556666'
```

### EXAMPLE 2
```
Get-CWCRemoteWorkforceSession | Get-CWCRemoteWorkforceLaunchURL
```

### EXAMPLE 3
```
Get-CWCRemoteWorkforceLaunchURL -SessionName 'DESKTOP-01'
```

## PARAMETERS

### -GUID
One or more session IDs.
Each is requested separately.

```yaml
Type: Guid[]
Parameter Sets: GUID
Aliases: SessionID

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SessionName
The session name to look up within the caller's Remote Workforce sessions.

```yaml
Type: String
Parameter Sets: SessionName
Aliases:

Required: True
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

