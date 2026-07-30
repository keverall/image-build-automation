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

# NOTE: This file is dot-sourced (not imported as a module), matching the repo's
# *.Common.ps1 convention, so functions and colour variables are exposed directly
# to the calling script's scope.
