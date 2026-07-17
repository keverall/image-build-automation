---
external help file: platyPS-help.xml
Module Name: platyPS
online version:
schema: 2.0.0
---

# Merge-MarkdownHelp

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1](#example-1)
- [PARAMETERS](#parameters)
  - [-Encoding](#-encoding)
  - [-ExplicitApplicableIfAll](#-explicitapplicableifall)
  - [-Force](#-force)
  - [-MergeMarker](#-mergemarker)
  - [-OutputPath](#-outputpath)
  - [-Path](#-path)
  - [CommonParameters](#commonparameters)
- [INPUTS](#inputs)
  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [System.String[]](#systemstring)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


<a name="synopsis"></a>
## SYNOPSIS
Merge multiple markdown versions of the same cmdlet into a single markdown file.

<a name="syntax"></a>
## SYNTAX

```
Merge-MarkdownHelp [-Path] <String[]> [-OutputPath] <String> [-Encoding <Encoding>] [-ExplicitApplicableIfAll]
 [-Force] [[-MergeMarker] <String>] [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
Similar modules, or different versions of the same module, often contain duplicate content.

Merge-MarkdownHelp merges the multiple markdown files into a single markdown file.
It uses the `applicable:` yaml metadata field to identify what versions or tags are applicable.
It acts on two levels: for the whole cmdlet and for individual parameters.

The resulting markdown contains the `applicable:` tags as well as all of the content of the original markdown files.
Duplicate content is simply ignored.
Content that is unique to each file is merged using **merge markers**, followed by a comma-separated list of applicable tags.
A **merge marker** is a string of text that acts as a marker to describe the content that was merged.
The default **merge marker** text consists of three exclamation points !!! however this can be changed to any relevant text using the **-MergeMarker** flag.

<a name="examples"></a>
## EXAMPLES

<a name="example-1"></a>
### Example 1
The Test-CsPhoneBootstrap.md cmdlet is included in both Lync Server 2010 and Lync Server 2013.
Much of the content is duplicated and thus we want to have a single file for the cmdlet with unique content merged from each individual file.

```
PS C:\> Merge-MarkdownHelp -Path @('Lync Server 2010\Test-CsPhoneBootstrap.md', 'Lync Server 2013\Test-CsPhoneBootstrap.md') -OutputPath lync
```

The resulting file will be located at lync\Test-CsPhoneBootstrap.md

<a name="parameters"></a>
## PARAMETERS

<a name="-encoding"></a>
### -Encoding
Specifies the character encoding for your external help file.
Specify a **System.Text.Encoding** object.
For more information, see [Character Encoding in the .NET Framework](https://msdn.microsoft.com/en-us/library/ms404377.aspx) in the Microsoft Developer Network.
For example, you can control Byte Order Mark (BOM) preferences.
For more information, see [Using PowerShell to write a file in UTF-8 without the BOM](http://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom) at the Stack Overflow community.

```yaml
Type: Encoding
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: UTF8 without BOM
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-explicitapplicableifall"></a>
### -ExplicitApplicableIfAll
Always write out full list of applicable tags.
By default cmdlets and parameters that are present in all variations don't get an application tag.

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

<a name="-force"></a>
### -Force
Indicates that this cmdlet overwrites an existing file that has the same name.

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

<a name="-mergemarker"></a>
### -MergeMarker
String to be used as a merge text indicator.
Applicable tag list would be included after the marker

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: '!!! '
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-outputpath"></a>
### -OutputPath
Specifies the path of the folder where this cmdlet creates the combined markdown help files.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-path"></a>
### -Path
Specifies an array of paths of markdown files or folders.
This cmdlet creates combined markdown help based on these files and folders.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: True
```

<a name="commonparameters"></a>
### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

<a name="inputs"></a>
## INPUTS

<a name="systemstring"></a>
### System.String[]

<a name="outputs"></a>
## OUTPUTS

<a name="systemiofileinfo"></a>
### System.IO.FileInfo[]

<a name="notes"></a>
## NOTES

<a name="related-links"></a>
## RELATED LINKS
