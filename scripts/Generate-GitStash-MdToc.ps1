function Generate-GitStash-MdToc
{
    <#
.SYNOPSIS
Generates a Markdown table of contents (TOC) with optional anchor injection.

.DESCRIPTION
Parses a Markdown file and generates a clickable Table of Contents based on headings.
Optionally injects HTML anchor tags to ensure compatibility with Bitbucket and other renderers.

Supports pipeline input, in-place updates, or writing to a new output file.

.PARAMETER Path
Path to the Markdown file(s).

.PARAMETER OutputPath
Optional output path. If not specified, ".with-toc.md" is appended.

.PARAMETER InPlace
Overwrite the original file instead of creating a new one.

.PARAMETER MaxDepth
Maximum heading depth to include (default: 3 = ###).

.PARAMETER NoAnchors
Do not inject <a name="..."> anchor tags.

.EXAMPLE
Generate-GitStash-MdToc -Path docs\file.md

.EXAMPLE
Generate-GitStash-MdToc docs\file.md -InPlace

.EXAMPLE
Get-ChildItem docs\*.md | Generate-GitStash-MdToc -InPlace

.EXAMPLE
Generate-GitStash-MdToc docs\file.md -MaxDepth 4 -Verbose

.NOTES
Compatible with Bitbucket Markdown rendering.
Designed for automation and CI pipelines.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Path,

        [string]$OutputPath,

        [switch]$InPlace,

        [int]$MaxDepth = 3,

        [switch]$NoAnchors
    )

    begin
    {
        Write-Verbose "Starting TOC generation"
    }

    process
    {
        foreach ($file in $Path)
        {

            if (-not (Test-Path $file))
            {
                Write-Warning "File not found: $file"
                continue
            }

            Write-Verbose "Processing file: $file"

            $lines = Get-Content $file
            $toc = @()
            $updatedContent = @()
            $anchorsSeen = @{}

            function Get-Anchor($title, [ref]$anchorsSeen)
            {
                $anchor = $title.ToLower()
                $anchor = $anchor -replace '[^a-z0-9\s\-]', ''
                $anchor = $anchor -replace '\s+', '-'

                if ($anchorsSeen.Value.ContainsKey($anchor))
                {
                    $anchorsSeen.Value[$anchor]++
                    $anchor = "$anchor-$($anchorsSeen.Value[$anchor])"
                } else
                {
                    $anchorsSeen.Value[$anchor] = 0
                }

                return $anchor
            }

            foreach ($line in $lines)
            {
                if ($line -match '^(#+)\s+(.+)$')
                {
                    $level = $matches[1].Length
                    $title = $matches[2]

                    if ($level -gt $MaxDepth)
                    {
                        $updatedContent += $line
                        continue
                    }

                    if ($level -eq 1)
                    {
                        $updatedContent += $line
                        continue
                    }

                    $anchor = Get-Anchor $title ([ref]$anchorsSeen)

                    $indent = '  ' * ($level - 2)

                    # ✅ clickable TOC entry
                    $toc += "$indent- [$title](#$anchor)"

                    if (-not $NoAnchors)
                    {
                        $updatedContent += "<a name=""$anchor""></a>"
                    }

                    $updatedContent += $line
                } else
                {
                    $updatedContent += $line
                }
            }

            # Build TOC block
            $tocBlock = @(
                "## Table of Contents"
                ""
            ) + $toc + @("")

            # Remove existing TOC
            $cleanContent = @()
            $skip = $false

            foreach ($line in $updatedContent)
            {
                if ($line -match '^## Table of Contents')
                {
                    $skip = $true
                    continue
                }

                if ($skip -and $line -match '^## ')
                {
                    $skip = $false
                }

                if (-not $skip)
                {
                    $cleanContent += $line
                }
            }

            # Insert TOC after H1
            $finalContent = @()
            $inserted = $false

            foreach ($line in $cleanContent)
            {
                $finalContent += $line

                if (-not $inserted -and $line -match '^#\s+')
                {
                    $finalContent += ""
                    $finalContent += $tocBlock
                    $inserted = $true
                }
            }

            if (-not $inserted)
            {
                $finalContent = $tocBlock + $cleanContent
            }

            # Determine output path
            $outFile = if ($InPlace)
            {
                $file
            } elseif ($OutputPath)
            {
                $OutputPath
            } else
            {
                "$file.with-toc.md"
            }

            Write-Verbose "Writing output to: $outFile"

            $finalContent | Set-Content $outFile -Encoding utf8

            Write-Output $outFile
        }
    }

   
    end
    {
        Write-Verbose "TOC generation complete"
    }
}
if ($MyInvocation.InvocationName -ne '.') {
    Generate-GitStash-MdToc @PSBoundParameters
}