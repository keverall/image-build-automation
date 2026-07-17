---
external help file: platyPS-help.xml
Module Name: platyPS
online version: https://github.com/PowerShell/platyPS/blob/master/docs/Get-HelpPreview.md
schema: 2.0.0
---

# Get-HelpPreview

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1: Preview the PlatyPS help](#example-1-preview-the-platyps-help)
- [PARAMETERS](#parameters)
  - [-Path](#-path)
  - [-ConvertNotesToList](#-convertnotestolist)
  - [-ConvertDoubleDashLists](#-convertdoubledashlists)
  - [CommonParameters](#commonparameters)
- [INPUTS](#inputs)
  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Help Object](#help-object)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


<a name="synopsis"></a>
## SYNOPSIS
Displays your generated external help as **Get-Help** output.

<a name="syntax"></a>
## SYNTAX

```
Get-HelpPreview -Path <String[]> [-ConvertNotesToList] [-ConvertDoubleDashLists] [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
The **Get-HelpPreview** cmdlet displays your generated external help as **Get-Help** output.
Specify one or more files in Microsoft Assistance Markup Language (MAML) format.

<a name="examples"></a>
## EXAMPLES

<a name="example-1-preview-the-platyps-help"></a>
### Example 1: Preview the PlatyPS help
```
PS C:\> $Help = Get-HelpPreview -Path ".\out\platyPS\en-US\PlatyPS-help.xml"

PS C:\> $Help.Name

Get-HelpPreview
Get-MarkdownMetadata
New-ExternalHelp
New-ExternalHelpCab
New-MarkdownHelp
Update-MarkdownHelp
Update-MarkdownHelpModule
Update-MarkdownHelpSchema
```

The first command creates a **Help** object for the the specified MAML file.
The command stores it in the $Help variable.

The second command displays the **Name** property for each of the objects in $Help.

<a name="parameters"></a>
## PARAMETERS

<a name="-path"></a>
### -Path
Specifies an array of paths of MAML external help files.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: True
```

<a name="-convertnotestolist"></a>
### -ConvertNotesToList
Indicates that this cmldet formats multiple paragraph items in the **NOTES** section as single list items.
This output follows TechNet formatting.

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

<a name="-convertdoubledashlists"></a>
### -ConvertDoubleDashLists
Indicates that this cmldet converts double-hyphen list bullets into single-hyphen bullets.
Double-hyphen lists are common in Windows PowerShell documentation.
Markdown accepts single-hyphens for lists.

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

<a name="commonparameters"></a>
### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

<a name="inputs"></a>
## INPUTS

<a name="string"></a>
### String[]
You can pipe an array of paths to this cmdlet.

<a name="outputs"></a>
## OUTPUTS

<a name="help-object"></a>
### Help Object
This cmdlet returns a **Help** object, which is the same output as **Get-Help**.

<a name="notes"></a>
## NOTES

<a name="related-links"></a>
## RELATED LINKS
