---
external help file: platyPS-help.xml
Module Name: platyPS
online version: https://github.com/PowerShell/platyPS/blob/master/docs/New-ExternalHelp.md
schema: 2.0.0
---

# New-ExternalHelp

## Table of Contents

- [SYNOPSIS](#synopsis)
- [SYNTAX](#syntax)
- [DESCRIPTION](#description)
- [EXAMPLES](#examples)
  - [Example 1: Create external help based on the contents of a folder](#example-1-create-external-help-based-on-the-contents-of-a-folder)
  - [Example 2: Create help that uses custom encoding](#example-2-create-help-that-uses-custom-encoding)
  - [Example 3: Write warnings and errors to file](#example-3-write-warnings-and-errors-to-file)
- [PARAMETERS](#parameters)
  - [-OutputPath](#-outputpath)
  - [-Encoding](#-encoding)
  - [-Force](#-force)
  - [-Path](#-path)
  - [-ApplicableTag](#-applicabletag)
  - [-MaxAboutWidth](#-maxaboutwidth)
  - [-ErrorLogFile](#-errorlogfile)
  - [-ShowProgress](#-showprogress)
  - [CommonParameters](#commonparameters)
- [INPUTS](#inputs)
  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


  - [String[]](#string)
- [OUTPUTS](#outputs)
  - [System.IO.FileInfo[]](#systemiofileinfo)
- [NOTES](#notes)
- [RELATED LINKS](#related-links)


<a name="synopsis"></a>
## SYNOPSIS
Creates external help file based on markdown supported by PlatyPS.

<a name="syntax"></a>
## SYNTAX

```
New-ExternalHelp -Path <String[]> -OutputPath <String> [-ApplicableTag <String[]>] [-Encoding <Encoding>]
 [-MaxAboutWidth <Int32>] [-ErrorLogFile <String>] [-Force] [-ShowProgress] [<CommonParameters>]
```

<a name="description"></a>
## DESCRIPTION
The **New-ExternalHelp** cmdlet creates an external help file based on markdown help files supported by PlatyPS.
You can ship this with a module to provide help by using the **Get-Help** cmdlet.

If the markdown files that you specify do not follow the PlatyPS [Schema](https://github.com/PowerShell/platyPS/blob/master/platyPS.schema.md), this cmdlet returns error messages.

<a name="examples"></a>
## EXAMPLES

<a name="example-1-create-external-help-based-on-the-contents-of-a-folder"></a>
### Example 1: Create external help based on the contents of a folder
```
PS C:\> New-ExternalHelp -Path ".\docs" -OutputPath "out\platyPS\en-US"

    Directory: D:\Working\PlatyPS\out\platyPS\en-US


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        5/19/2016  12:32 PM          46776 platyPS-help.xml
```

This command creates an external help file in the specified location.
This command uses the best practice that the folder name includes the locale.

<a name="example-2-create-help-that-uses-custom-encoding"></a>
### Example 2: Create help that uses custom encoding
```
PS C:\> New-ExternalHelp -Path ".\docs" -OutputPath "out\PlatyPS\en-US" -Force -Encoding ([System.Text.Encoding]::Unicode)


    Directory: D:\Working\PlatyPS\out\PlatyPS\en-US


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        5/22/2016   6:34 PM         132942 platyPS-help.xml
```

This command creates an external help file in the specified location.
This command specifies the *Force* parameter, therefore, it overwrites an existing file.
The command specifies Unicode encoding for the created file.

<a name="example-3-write-warnings-and-errors-to-file"></a>
### Example 3: Write warnings and errors to file
```
PS C:\> New-ExternalHelp -Path ".\docs" -OutputPath "out\platyPS\en-US" -ErrorLogFile ".\WarningsAndErrors.json"

    Directory: D:\Working\PlatyPS\out\platyPS\en-US


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        5/19/2016  12:32 PM          46776 platyPS-help.xml
```

This command creates an external help file in the specified location.
This command uses the best practice that the folder name includes the locale.
This command writes the warnings and errors to the WarningsAndErrors.json file.

<a name="parameters"></a>
## PARAMETERS

<a name="-outputpath"></a>
### -OutputPath
Specifies the path of a folder where this cmdlet saves your external help file.
The folder name should end with a locale folder, as in the following example: `.\out\PlatyPS\en-US\`.

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
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: True
```

<a name="-applicabletag"></a>
### -ApplicableTag
Specify array of tags to use as a filter.
If cmdlet has `applicable` in the yaml metadata and none of the passed tags is
mentioned there, cmdlet would be ignored in the generated help.
Same applies to the Parameter level `applicable` yaml metadata.
If `applicable` is ommited, cmdlet or parameter would be always present.
See [design issue](https://github.com/PowerShell/platyPS/issues/273) for more details.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-maxaboutwidth"></a>
### -MaxAboutWidth
Specifies the maximimum line length when generating "about" help text files.
(See New-MarkdownAboutHelp.) Other help file types are not affected by this
parameter.

Lines inside code blocks are not wrapped at all and are not affected by the
MaxAboutWidth parameter.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 80
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-errorlogfile"></a>
### -ErrorLogFile
The path where this cmdlet will save formatted results log file.

The path must include the location and name of the folder and file name with
the json extension. The JSON object contains three properties, Message, FilePath,
and Severity (Warning or Error).

If this path is not provided, no log will be generated.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

<a name="-showprogress"></a>
### -ShowProgress
Display progress bars under parsing existing markdown files.

If this is used generating of help is much slower.

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

<a name="systemiofileinfo"></a>
### System.IO.FileInfo[]
This cmdlet returns a **FileInfo[]** object for created files.

<a name="notes"></a>
## NOTES

<a name="related-links"></a>
## RELATED LINKS

[PowerShell V2 External MAML Help](https://blogs.msdn.microsoft.com/powershell/2008/12/24/powershell-v2-external-maml-help/)

[Schema](https://github.com/PowerShell/platyPS/blob/master/platyPS.schema.md)
