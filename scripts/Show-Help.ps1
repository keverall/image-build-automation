param()

<#
.SYNOPSIS
    Display available Makefile commands and targets.

.DESCRIPTION
    Parses Makefile for documented targets and displays them in a formatted table.
    Shows all available 'make' commands with their descriptions from inline comments.

    Uses Write-Output with ANSI escape codes (not Write-Host) so that the
    PSScriptAnalyzer AvoidUsingWriteHost rule is not triggered, while still
    rendering colored output in a supporting terminal.

.EXAMPLE
    pwsh -File scripts/Show-Help.ps1
    
.EXAMPLE
    ./scripts/Show-Help.ps1
#>

# ANSI color escape codes (safe with Write-Output; avoids AvoidUsingWriteHost)
$Cyan = "$([char]27)[36m"
$Yellow = "$([char]27)[33m"
$Magenta = "$([char]27)[35m"
$Bold = "$([char]27)[1m"
$Reset = "$([char]27)[0m"

# Inner width of the funky box (matches the ═ border: 60 dashes + 2 walls = 62 cols)
$BoxW = 62

function Get-DisplayWidth {
    # Counts terminal cells using UTF-32 codepoints: ANSI escapes = 0,
    # wide chars (CJK / emoji) = 2, else 1. Handles surrogate pairs safely.
    param([string]$Text)
    $clean = $Text -replace "\e\[[0-9;]*m", ''
    $w = 0
    $enum = [System.Globalization.StringInfo]::GetTextElementEnumerator($clean)
    while ($enum.MoveNext()) {
        $elem = $enum.GetTextElement()
        $cp = [System.Char]::ConvertToUtf32($elem, 0)
        if ($cp -ge 0x1100 -and (
            ($cp -le 0x115F) -or ($cp -ge 0x2E80 -and $cp -le 0x303E) -or
            ($cp -ge 0x3041 -and $cp -le 0x33FF) -or ($cp -ge 0x3400 -and $cp -le 0x4DBF) -or
            ($cp -ge 0x4E00 -and $cp -le 0x9FFF) -or ($cp -ge 0xA000 -and $cp -le 0xA4CF) -or
            ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
            ($cp -ge 0xFE30 -and $cp -le 0xFE4F) -or ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or
            ($cp -ge 0xFFE0 -and $cp -le 0xFFE6) -or ($cp -ge 0x1F300 -and $cp -le 0x1FAFF) -or
            ($cp -ge 0x20000 -and $cp -le 0x3FFFD))) { $w += 2 } else { $w += 1 }
    }
    return $w
}

function Format-BoxLine {
    param([string]$Text, [string]$Color)
    $contentW = (Get-DisplayWidth -Text $Text) + 2   # +2 for the single spaces inside each wall
    $pad = [Math]::Max(0, $BoxW - $contentW)
    Write-Output ("$Color║${Reset} $Text" + (' ' * $pad) + " $Color║${Reset}")
}

Write-Output ''
Write-Output "${Cyan}╔══════════════════════════════════════════════════════════╗${Reset}"
Write-Output "${Cyan}║  HPE ProLiant ISO Automation - Available Commands         ║${Reset}"
Write-Output "${Cyan}╚══════════════════════════════════════════════════════════╝${Reset}"
Write-Output ''

$makefile = Join-Path $PSScriptRoot '..' 'Makefile'
Select-String -Path $makefile -Pattern '^[a-zA-Z_-]+:.*?## .*$' | ForEach-Object {
    $parts = $_.Line -split ':.*?## '
    Write-Output ("${Green}  {0,-15} {1}${Reset}" -f $parts[0].Trim(), $parts[1].Trim())
}

Write-Output ''

# ── Funky boxed footer with a random maintenance tip ──────────────────────────
$Tips = @(
    'OneView targets servers by serial number - clusters are a SCOM thing.',
    'Run `make docs` to keep the API reference & anchors in sync.',
    'Prune logs with `make prune-logs` before a big build run.',
    'Check connectivity early: `make test-maintenance-connection`.',
    'Dry-run doc link fixes with `make fix-docs-dryrun` first.',
    'Golden retrievers and Labradors are secretly judging your uptime.',
    'A clean `make lint` today keeps the PSScriptAnalyzer away.',
    'Serial numbers beat hostnames when iLO is feeling shy.',
    'Tag your ISO builds so rollbacks do not become archaeology.',
    'Coffee: optional. Backups: non-negotiable.'
)
$Tip = $Tips[(Get-Random -Minimum 0 -Maximum $Tips.Count)]

Write-Output "${Magenta}╔══════════════════════════════════════════════════════════╗${Reset}"
Format-BoxLine -Text "${Bold}💡 Maintenance Tip${Reset}" -Color $Magenta
Write-Output "${Magenta}╟──────────────────────────────────────────────────────────────╢${Reset}"
Format-BoxLine -Text $Tip -Color $Yellow
Write-Output "${Magenta}╚══════════════════════════════════════════════════════════╝${Reset}"
Write-Output ''
