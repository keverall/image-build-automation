<#
.SYNOPSIS
    Shared helpers for markdown documentation tooling (make docs / make fix-docs).

.DESCRIPTION
    Single source of truth for the logging helper and for the placement of the
    document "top" anchor (<a id="top"></a>). Previously this logic was duplicated
    across validate-docs-links.ps1, bitbucket-md-anchor-toc.ps1 and
    Generate-GitStash-MdToc.ps1, which let the two Makefile targets (docs vs
    fix-docs) drift apart. Centralising it here keeps every doc script consistent.

    Follows the repository convention for shared modules: a *.Common.ps1 file that
    defines functions (function-mode) so it can be dot-sourced or imported.
#>

$Green  = "`e[0;32m"
$Yellow = "`e[1;33m"
$Red    = "`e[0;31m"
$Cyan   = "`e[0;36m"
$Reset  = "`e[0m"

$script:_docsStatusLogFile = $null

function Set-DocsStatusLog {
    <#
    .SYNOPSIS
        Sets the log file path that Write-Status writes to.
    #>
    param([string]$Path)
    $script:_docsStatusLogFile = $Path
}

function Write-Status {
    <#
    .SYNOPSIS
        Writes a colourised status message to the host and (optionally) a log file.
    #>
    param([string]$Color, [string]$Message)
    $cleanMessage = $Message -replace '\x1b\[[0-9;]*m', ''
    Write-Output "${Color}${Message}${Reset}"
    if ($script:_docsStatusLogFile) {
        $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $cleanMessage"
        Add-Content -Path $script:_docsStatusLogFile -Value $logEntry -Encoding UTF8
    }
}

function Set-TopAnchor {
    <#
    .SYNOPSIS
        Ensures a single <a id="top"></a> anchor sits immediately below the first H1,
        above any Table of Contents, separated by exactly one blank line on each side.

    .DESCRIPTION
        This is the canonical implementation used by both `make docs` and
        `make fix-docs`. It is idempotent: any existing top anchor is stripped and
        re-inserted in the canonical position, and runs of blank lines are collapsed
        to a single blank so the result stays MD012-compliant.

    .PARAMETER Lines
        Markdown content as an array of lines (in-memory use). Returns the updated
        array.

    .PARAMETER File
        A markdown file. The file is rewritten unless -DryRun is supplied.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Lines,
        [System.IO.FileInfo]$File,
        [switch]$DryRun
    )

    if ($File) {
        $content = @(Get-Content $File.FullName)
        $updated = Set-TopAnchorCore -Lines $content
        if (-not $DryRun) {
            $updated | Set-Content $File.FullName -Encoding utf8
        }
        return
    }

    return @(Set-TopAnchorCore -Lines $Lines)
}

function Set-TopAnchorCore {
    param([string[]]$Lines)

    # Strip any existing top anchors so we always rebuild from a clean state.
    $stripped = $Lines | Where-Object { $_ -notmatch '^<a\s+id="top"\s*></a>\s*$' }

    $h1Index = -1
    for ($i = 0; $i -lt $stripped.Count; $i++) {
        if ($stripped[$i] -match '^#\s+') { $h1Index = $i; break }
    }
    if ($h1Index -eq -1) { return $stripped }

    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $stripped.Count; $i++) {
        $out.Add($stripped[$i])
        if ($i -eq $h1Index) {
            $out.Add('')
            $out.Add('<a id="top"></a>')
            $out.Add('')
        }
    }

    # Collapse runs of consecutive blank lines into a single blank line.
    $collapsed = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $out) {
        if ($l -eq '' -and $collapsed.Count -gt 0 -and $collapsed[$collapsed.Count - 1] -eq '') {
            continue
        }
        $collapsed.Add($l)
    }
    return $collapsed
}

# ------------------------------------------------------------------
# Canonical markdown TOC + anchor generation (shared source of truth)
#
# Used by both `make docs` (via bitbucket-md-anchor-toc.ps1) and the
# Generate-PSDocs.ps1 dynamic-code-docs generator so every markdown file in the
# repo - hand-written docs AND auto-generated API reference - ends up in the
# exact same canonical form (Bitbucket/GitStash anchors + TOC + "top" anchor).
# Keeping it here prevents the two Makefile targets from drifting apart.
# ------------------------------------------------------------------

function Get-Anchor($title, [ref]$anchorsSeen) {
    $anchor = $title.ToLower()
    $anchor = $anchor -replace '&', 'and'
    $anchor = $anchor -replace '[^a-z0-9\s\-_]', ''
    $anchor = $anchor -replace '\s+', '-'

    if ($anchorsSeen.Value.ContainsKey($anchor)) {
        $anchorsSeen.Value[$anchor]++
        $anchor = "$anchor-$($anchorsSeen.Value[$anchor])"
    } else {
        $anchorsSeen.Value[$anchor] = 0
    }
    return $anchor
}

function Remove-ExistingToc([string[]]$lines) {
    $result  = [System.Collections.Generic.List[string]]::new()
    $skipToc = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($skipToc) {
            $isBlank    = $lines[$i] -match '^\s*$'
            $isTocEntry = $lines[$i] -match '^\s*- \[[^\]]+\]\(#[^)]+\)$'
            if ($isBlank -or $isTocEntry) {
                continue
            }
            $skipToc = $false
            $result.Add($lines[$i])
            continue
        }
        if ($lines[$i] -match '^## Table of Contents$') {
            $skipToc = $true
            continue
        }
        $result.Add($lines[$i])
    }
    return $result.ToArray()
}

function Remove-ExistingAnchors([string[]]$lines) {
    $result = [System.Collections.Generic.List[string]]::new()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^<a\s+id="top"\s*></a>\s*$') {
            continue
        }

        $isAnchorLine = $lines[$i] -match '^<a name="[^"]*"></a>$'
        if ($isAnchorLine) {
            $headingBelow = $false
            $limit = [Math]::Min($i + 2, $lines.Count - 1)
            for ($j = $i + 1; $j -le $limit; $j++) {
                if ($lines[$j] -match '^#{2,3}\s+') { $headingBelow = $true; break }
            }
            if ($headingBelow) {
                continue
            }
        }
        $result.Add($lines[$i])
    }
    return $result.ToArray()
}

function Build-CanonicalContent([string[]]$lines) {
    $cleaned = Remove-ExistingToc $lines
    $cleaned = Remove-ExistingAnchors $cleaned

    $updatedContent = [System.Collections.Generic.List[string]]::new()
    $toc            = [System.Collections.Generic.List[string]]::new()
    $anchorsSeen    = @{}
    $needBlankBeforeNext = $false

    function Ensure-BlankBefore([System.Collections.Generic.List[string]]$list) {
        if ($list.Count -eq 0) { return }
        if ($list[$list.Count - 1] -eq '') { return }
        $list.Add('')
    }

    foreach ($line in $cleaned) {
        if ($needBlankBeforeNext) {
            if ($line -ne '') {
                $updatedContent.Add('')
            }
            $needBlankBeforeNext = $false
        }

        if ($line -match '^(#{1,6})\s+(.+)$') {
            $level = $matches[1].Length
            $title = $matches[2]

            if ($level -eq 1) {
                $updatedContent.Add($line)
                continue
            }

            Ensure-BlankBefore $updatedContent

            if ($level -le 3) {
                $anchor = Get-Anchor $title ([ref]$anchorsSeen)
                $indent = '  ' * ($level - 2)
                $toc.Add("$indent- [$title](#$anchor)")

                $updatedContent.Add("<a name=""$anchor""></a>")
                $updatedContent.Add('')
            }

            $updatedContent.Add($line)
            $needBlankBeforeNext = $true
        } else {
            if ($line -eq '' -and $updatedContent.Count -gt 0 -and $updatedContent[$updatedContent.Count - 1] -eq '') {
                continue
            }
            $updatedContent.Add($line)
        }
    }

    $tocBlock = [System.Collections.Generic.List[string]]::new()
    $tocBlock.Add("## Table of Contents")
    $tocBlock.Add("")
    foreach ($entry in $toc) { $tocBlock.Add($entry) }
    $tocBlock.Add("")

    $finalContent = [System.Collections.Generic.List[string]]::new()
    $inserted     = $false

    foreach ($line in $updatedContent) {
        $finalContent.Add($line)

        if (-not $inserted -and $line -match '^#\s+') {
            $finalContent.Add("")
            foreach ($tocLine in $tocBlock) { $finalContent.Add($tocLine) }
            $inserted = $true
        }
    }

    if (-not $inserted) {
        $prepended = [System.Collections.Generic.List[string]]::new()
        foreach ($tocLine in $tocBlock) { $prepended.Add($tocLine) }
        foreach ($line in $finalContent) { $prepended.Add($line) }
        $finalContent = $prepended
    }

    $collapsed = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $finalContent) {
        if ($l -eq '' -and $collapsed.Count -gt 0 -and $collapsed[$collapsed.Count - 1] -eq '') {
            continue
        }
        $collapsed.Add($l)
    }
    $finalContent = $collapsed

    while ($finalContent.Count -gt 0 -and $finalContent[0] -eq '') {
        $finalContent.RemoveAt(0)
    }
    while ($finalContent.Count -gt 0 -and $finalContent[$finalContent.Count - 1] -eq '') {
        $finalContent.RemoveAt($finalContent.Count - 1)
    }

    $finalWithTop = Set-TopAnchor -Lines $finalContent.ToArray()
    return $finalWithTop
}

# NOTE: This file is dot-sourced (not imported as a module), matching the repo's
# *.Common.ps1 convention, so functions and colour variables are exposed directly
# to the calling script's scope.
