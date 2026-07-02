$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $scriptDir "..\docs\SETUP-GUIDE.md"

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