---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Get-CWCToolbox

## SYNOPSIS
Lists the contents of the ScreenConnect Toolbox.

## SYNTAX

```
Get-CWCToolbox [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Calls PageService.GetToolbox, the same call the host client makes to list Toolbox items.
Any
signed-in user can call it.

The server returns a tree: a root folder whose Items hold folders and files, each with a Name,
Attributes (1 for a folder, 0 for a file), a base64 icon (Image) and its own Items.
By default the tree is
flattened to one object per folder and file, with its Path inside the Toolbox and without the icon.

Use it to find an item for Send-CWCToolboxItem, or to check an upload made with Add-CWCToolboxItem.

## EXAMPLES

### EXAMPLE 1
```
Get-CWCToolbox
```

Lists every folder and file in the Toolbox.

### EXAMPLE 2
```
Get-CWCToolbox | Where-Object { -not $_.IsFolder -and $_.Path -like 'Scripts/*' }
```

## PARAMETERS

### -Raw
Return the tree as the server sends it, including the icons.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```


### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot list the Toolbox).
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

