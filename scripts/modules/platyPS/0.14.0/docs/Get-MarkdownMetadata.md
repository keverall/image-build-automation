---
external help file: platyPS-help.xml
Module Name: platyPS
online version: https://github.com/PowerShell/platyPS/blob/master/docs/Get-MarkdownMetadata.md
schema: 2.0.0
---

# Get-MarkdownMetadata

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
  - [FromPath (Default)](#frompath-default)
  - [FromMarkdownString](#frommarkdownstring)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1: Get metadata from a file](#example-1-get-metadata-from-a-file)
  - [Example 2: Get metadata from a markdown string](#example-2-get-metadata-from-a-markdown-string)
  - [Example 3: Get metadata from all files in a folder](#example-3-get-metadata-from-all-files-in-a-folder)
- [PARAMETERS](#parameters)
  - [-Path](#-path)
  - [-Markdown](#-markdown)
  - [CommonParameters](#commonparameters)
- [INPUTS](#inputs)
  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [Dictionary[String, String]](#dictionarystring-string)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


<a name="synopsis"></a>
## SYNOPSIS
Gets metadata from the header of a markdown file.

<a name="syntax"></a>
## SYNTAX

<a name="frompath-default"></a>
### FromPath (Default)
```
Get-MarkdownMetadata -Path <String[]> [<CommonParameters>]
```

<a name="frommarkdownstring"></a>
### FromMarkdownString
```
Get-MarkdownMetadata -Markdown <String> [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
The **Get-MarkdownMetadata** cmdlet gets the metadata from the header of a markdown file that is supported by PlatyPS.
The command returns the metadata as a hash table.

PlatyPS stores metadata in the header block of a markdown file as key-value pairs of strings.
By default, PlatyPS stores help file name and markdown schema version.

Metadata section can contain user-provided values for use with external tools.
The [New-ExternalHelp](New-ExternalHelp.md) cmdlet ignores this metadata.

<a name="examples"></a>
## EXAMPLES

<a name="example-1-get-metadata-from-a-file"></a>
### Example 1: Get metadata from a file
```
PS C:\> Get-MarkdownMetadata -Path ".\docs\Get-MarkdownMetadata.md"

Key                Value
---                -----
external help file platyPS-help.xml
schema             2.0.0
```

This command retrieves metadata from a markdown file.

<a name="example-2-get-metadata-from-a-markdown-string"></a>
### Example 2: Get metadata from a markdown string
```
PS C:\> $Markdown = Get-Content -Path ".\docs\Get-MarkdownMetadata.md" -Raw
PS C:\> Get-MarkdownMetadata -Markdown $Markdown

Key                Value
---                -----
external help file platyPS-help.xml
schema             2.0.0
```

The first command gets the contents of a file, and stores them in the $Markdown variable.

The second command retrieves metadata from the string in $Metadata.

<a name="example-3-get-metadata-from-all-files-in-a-folder"></a>
### Example 3: Get metadata from all files in a folder
```
PS C:\> Get-MarkdownMetadata -Path ".\docs"

Key                Value
---                -----
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
external help file platyPS-help.xml
schema             2.0.0
```

This command gets metadata from each of the markdown files in the .\docs folder.

<a name="parameters"></a>
## PARAMETERS

<a name="-path"></a>
### -Path
Specifies an array of paths of markdown files or folders.

```yaml
Type: String[]
Parameter Sets: FromPath
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: True
```

<a name="-markdown"></a>
### -Markdown
Specifies a string that contains markdown formatted text.

```yaml
Type: String
Parameter Sets: FromMarkdownString
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

<a name="string"></a>
### String[]
You can pipe an array of paths to this cmdlet.

<a name="outputs"></a>
## OUTPUTS

<a name="dictionarystring-string"></a>
### Dictionary[String, String]
The cmdlet returns a **Dictionary\[String, String\]** object.
The dictionary contains key-value pairs found in the markdown metadata block.

<a name="notes"></a>
## NOTES

<a name="related-links"></a>
## RELATED LINKS
