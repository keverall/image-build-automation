# scripts/bitbucket-md-anchor-toc.ps1
# Add Bitbucket/GitStash compatible anchors to markdown headings and generate a Table of Contents (TOC).


<#
.SYNOPSIS
    Adds Bitbucket/GitStash compatible anchors to markdown headings and generates a Table of Contents (TOC).

.DESCRIPTION
    This script processes a markdown file, adding anchors to headings and generating a Table of Contents (TOC) that links to those anchors. It is designed to be compatible with Bitbucket and GitStash.

.EXAMPLE
    .\bitbucket-md-anchor-toc.ps1

    This command will process the default markdown file located at "..\docs\Generic\testing.md", add anchors to its headings, generate a TOC, and save the output to a new file with ".with-toc.md" appended to the original filename.

.FUNCTIONALITY
    - Reads a markdown file.
    - Adds anchors to headings (H2 and H3).
    - Generates a Table of Contents (TOC) with links to the anchors.
    - Saves the modified content to a new file.

.NOTES
    - Ensure that the input markdown file exists at the specified path.
    - set the $file variable to the path of the markdown file you want to process.
    - Then test that the TOC works and links to the correct anchors in Bitbucket/GitStash.
#>

# =============================================================================
# Main Script
# =============================================================================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $scriptDir "..\docs\Generic\testing.md"

if (-not (Test-Path $file)) {
    Write-Error "Input file not found: $file"
    exit
}


$file = Resolve-Path $file
$output = "$($file.Path).with-toc.md"

$lines = Get-Content $file 


$toc = @()
$updatedContent = @()
$anchorsSeen = @{}

function Get-Anchor($title, [ref]$anchorsSeen) {
    $anchor = $title.ToLower()

    # ✅ normalize ampersand
    $anchor = $anchor -replace '&', 'and'

    # ✅ remove unwanted chars (but keep _ and -)
    $anchor = $anchor -replace '[^a-z0-9\s\-_]', ''

    # ✅ spaces → hyphens
    $anchor = $anchor -replace '\s+', '-'

    if ($anchorsSeen.Value.ContainsKey($anchor)) {
        $anchorsSeen.Value[$anchor]++
        $anchor = "$anchor-$($anchorsSeen.Value[$anchor])"
    } else {
        $anchorsSeen.Value[$anchor] = 0
    }

    return $anchor
}


foreach ($line in $lines) {
    if ($line -match '^(#{1,3})\s+(.+)$') {
        $level = $matches[1].Length
        $title = $matches[2]

        # Skip H1 from TOC if you want (matches your example)
        if ($level -eq 1) {
            $updatedContent += $line
            continue
        }

        $anchor = Get-Anchor $title ([ref]$anchorsSeen)

        # ✅ Proper indentation
        $indent = '  ' * ($level - 2)

        # ✅ FIXED: clickable markdown link
        $toc += "$indent- [$title](#$anchor)"

        # ✅ Insert anchor
        $updatedContent += "<a name=""$anchor""></a>"
        $updatedContent += $line
    }
    else {
        $updatedContent += $line
    }
}

# ✅ Build TOC
$tocBlock = @(
    "## Table of Contents"
    ""
) + $toc + @("")

# ✅ Insert TOC after H1
$finalContent = @()
$inserted = $false

foreach ($line in $updatedContent) {
    $finalContent += $line

    if (-not $inserted -and $line -match '^#\s+') {
        $finalContent += ""
        $finalContent += $tocBlock
        $inserted = $true
    }
}

if (-not $inserted) {
    $finalContent = $tocBlock + $updatedContent
}

# ✅ Write file
$finalContent | Set-Content $output -Encoding utf8

Write-Output "✅ Output written to: $output"