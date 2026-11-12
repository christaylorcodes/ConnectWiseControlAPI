---
external help file: ConnectWiseControlAPI-help.xml
Module Name: ConnectWiseControlAPI
online version: https://github.com/christaylorcodes/ConnectWiseControlAPI
schema: 2.0.0
---

# Add-CWCToolboxItem

## SYNOPSIS
Uploads a file to the shared ScreenConnect Toolbox, or creates a Toolbox folder.

## SYNTAX

### File (Default)
```
Add-CWCToolboxItem -Path <String> [-Name <String>] [-ChunkSize <Int32>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Directory
```
Add-CWCToolboxItem -Name <String> [-Directory] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Calls ToolboxService.WriteToolboxFileContent.
The file is sent in chunks: the first chunk creates
the item, replacing an item of the same name, and the rest are appended.
The user needs the
ManageSharedToolbox permission.

When -Name contains a folder, that folder is created first.
If a chunk fails, a partial file is
left in the Toolbox; run the command again to replace it.

Several files can be piped in; each keeps its own file name.

Run the uploaded item on a session with Send-CWCToolboxItem.

## EXAMPLES

### EXAMPLE 1
```
Add-CWCToolboxItem -Path .\Cleanup.cmd
```

Uploads Cleanup.cmd to the top level of the Toolbox.

### EXAMPLE 2
```
Add-CWCToolboxItem -Path .\Cleanup.cmd -Name 'Scripts/Cleanup.cmd'
```

Creates the Scripts folder if needed and uploads the file into it.

### EXAMPLE 3
```
Get-ChildItem .\Tools\*.exe | Add-CWCToolboxItem
```

### EXAMPLE 4
```
Add-CWCToolboxItem -Directory -Name 'Scripts'
```

## PARAMETERS

### -Path
Local file to upload.
Accepts paths and Get-Item / Get-ChildItem output from the pipeline.

```yaml
Type: String
Parameter Sets: File
Aliases: FullName

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Name
Path of the item inside the Toolbox, e.g.
'Cleanup.cmd' or 'Scripts/Cleanup.cmd'.
Defaults to the
file name of -Path.
It names one item, so it cannot be used when several files are piped in.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: Directory
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Directory
Create the Toolbox folder -Name instead of uploading a file.

```yaml
Type: SwitchParameter
Parameter Sets: Directory
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ChunkSize
Bytes of the file sent per request.
Defaults to 524288 (512 KB).
Lower it if the server rejects
the request as too large.

```yaml
Type: Int32
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: 524288
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
Requires Connect-CWC -Credentials (the RESTful API Manager extension cannot write to the Toolbox).
Author: Chris Taylor

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseControlAPI](https://github.com/christaylorcodes/ConnectWiseControlAPI)

