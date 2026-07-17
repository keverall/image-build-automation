---
external help file: platyPS-help.xml
Module Name: platyPS
online version: https://github.com/PowerShell/platyPS/blob/master/docs/New-MarkdownAboutHelp.md
schema: 2.0.0
---

# New-MarkdownAboutHelp

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
- [PARAMETERS](#parameters)
  - [-AboutName](#-aboutname)
  - [-OutputFolder](#-outputfolder)
  - [CommonParameters](#commonparameters)
- [INPUTS](#inputs)
  - [None](#none)
- [OUTPUTS](#outputs)
  - [System.Object](#systemobject)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


<a name="synopsis"></a>
## SYNOPSIS
Generates a new About Topic MD file from template.

<a name="syntax"></a>
## SYNTAX

```
New-MarkdownAboutHelp [-OutputFolder] <String> [[-AboutName] <String>] [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
The **New-MarkdownAboutHelp** cmdlet generates a Markdown file that is prepopulated with the standard elements of an About Topic.
The cmdlet copies the template MD, renames headers and file name according to the **AboutName** parameter,
and deposits the file in the directory designated by the **OutputFoler** parameter.

The About Topic can be converted to Txt format.
About topics must be in txt format or the PowerShell Help engine will not be able to parse the document.
Use the [New-ExternalHelp](New-ExternalHelp.md) cmdlet to convert About Topic markdown files into About Topic txt files.

<a name="examples"></a>
## EXAMPLES

<a name="example-1"></a>
### Example 1
```
PS C:\> New-MarkdownAboutHelp -OutputFolder C:\Test -AboutName
PS C:\> Get-ChildItem C:\Test

    Directory: C:\Test


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        7/13/2016   2:12 PM           1491 TestAboutTopic.md
```

Create and display file info for PowerShell About Topic Markdown File.

<a name="example-2"></a>
### Example 2
```
PS C:\> New-ExternalHelp -Path C:\Test\ -OutputPath C:\Test


    Directory: C:\Test


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        7/13/2016   2:15 PM           1550 TestAboutTopic.txt
```

Create PowerShell About Topic Txt file from existing Markdown About file.

<a name="parameters"></a>
## PARAMETERS

<a name="-aboutname"></a>
### -AboutName
The name of the about topic.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-outputfolder"></a>
### -OutputFolder
The directory to create the about topic in.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="commonparameters"></a>
### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

<a name="inputs"></a>
## INPUTS

<a name="none"></a>
### None

<a name="outputs"></a>
## OUTPUTS

<a name="systemobject"></a>
### System.Object
This cmdlet returns a object for created files.

<a name="notes"></a>
## NOTES
The about topics will need to be added to a cab file to leverage updatable help.

<a name="related-links"></a>
## RELATED LINKS

[New-ExternalHelp](New-ExternalHelp.md)

[New-ExternalHelpCab](New-ExternalHelpCab.md)
