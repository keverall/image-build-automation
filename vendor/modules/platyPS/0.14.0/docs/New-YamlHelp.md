---
external help file: platyPS-help.xml
Module Name: platyPS
online version: https://github.com/PowerShell/platyPS/blob/master/docs/New-YamlHelp.md
schema: 2.0.0
---

# New-YamlHelp

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1: Create YAML files](#example-1-create-yaml-files)
  - [Example 2: Create YAML files with specific encoding](#example-2-create-yaml-files-with-specific-encoding)
- [PARAMETERS](#parameters)
  - [-Encoding](#-encoding)
  - [-Force](#-force)
  - [-Path](#-path)
  - [-OutputFolder](#-outputfolder)
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
Converts Markdown help into YAML to be read easily by external tools

<a name="syntax"></a>
## SYNTAX

```
New-YamlHelp [-Path] <String[]> -OutputFolder <String> [-Encoding <Encoding>] [-Force] [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
The **New-YamlHelp** cmdlet works similarly to the **New-ExternalHelp** cmdlet but rather than creating a MAML file to support **Get-Help**, it creates a set of YAML files that can be read by external tools to provide custom rendering of help pages.

<a name="examples"></a>
## EXAMPLES

<a name="example-1-create-yaml-files"></a>
### Example 1: Create YAML files
```
PS C:\> New-YamlHelp -Path .\docs -OutputFolder .\out\yaml

    Directory: D:\Working\PlatyPS\out\yaml


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        6/15/2017  11:13 AM           2337 Get-HelpPreview.yml
-a----        6/15/2017  11:13 AM           3502 Get-MarkdownMetadata.yml
-a----        6/15/2017  11:13 AM           4143 New-ExternalHelp.yml
-a----        6/15/2017  11:13 AM           3082 New-ExternalHelpCab.yml
-a----        6/15/2017  11:13 AM           2581 New-MarkdownAboutHelp.yml
-a----        6/15/2017  11:13 AM          12356 New-MarkdownHelp.yml
-a----        6/15/2017  11:13 AM           1681 New-YamlHelp.yml
-a----        6/15/2017  11:13 AM           5053 Update-MarkdownHelp.yml
-a----        6/15/2017  11:13 AM           4661 Update-MarkdownHelpModule.yml
-a----        6/15/2017  11:13 AM           3350 Update-MarkdownHelpSchema.yml
```

This creates one YAML file for each cmdlet so external tools can read the structured data for each cmdlet.

<a name="example-2-create-yaml-files-with-specific-encoding"></a>
### Example 2: Create YAML files with specific encoding
```
PS C:\> New-YamlHelp -Path .\docs -OutputFolder .\out\yaml -Force -Encoding ([System.Text.Encoding]::Unicode)

    Directory: D:\Working\PlatyPS\out\yaml


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        6/15/2017  11:13 AM           2337 Get-HelpPreview.yml
-a----        6/15/2017  11:13 AM           3502 Get-MarkdownMetadata.yml
-a----        6/15/2017  11:13 AM           4143 New-ExternalHelp.yml
-a----        6/15/2017  11:13 AM           3082 New-ExternalHelpCab.yml
-a----        6/15/2017  11:13 AM           2581 New-MarkdownAboutHelp.yml
-a----        6/15/2017  11:13 AM          12356 New-MarkdownHelp.yml
-a----        6/15/2017  11:13 AM           1681 New-YamlHelp.yml
-a----        6/15/2017  11:13 AM           5053 Update-MarkdownHelp.yml
-a----        6/15/2017  11:13 AM           4661 Update-MarkdownHelpModule.yml
-a----        6/15/2017  11:13 AM           3350 Update-MarkdownHelpSchema.yml
```

This will both read and write the files in the specified -Encoding.
The -Force parameter will overwrite files that already exist.

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

<a name="-path"></a>
### -Path
Specifies an array of paths of markdown files or folders.
This cmdlet creates external help based on these files and folders.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

<a name="-outputfolder"></a>
### -OutputFolder
Specifies the folder to create the YAML files in

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

<a name="commonparameters"></a>
### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

<a name="inputs"></a>
## INPUTS

<a name="systemstring"></a>
### System.String[]
You can pipe an array of paths to this cmdlet.

<a name="outputs"></a>
## OUTPUTS

<a name="systemiofileinfo"></a>
### System.IO.FileInfo[]
This cmdlet returns a **FileInfo[]** object for created files.

<a name="notes"></a>
## NOTES

<a name="related-links"></a>
## RELATED LINKS
