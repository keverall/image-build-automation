param()

<#
.SYNOPSIS
    Display available Makefile commands and targets.

.DESCRIPTION
    Parses Makefile for documented targets and displays them in a formatted
    bordered table with a header row. Descriptions that are longer than the
    available terminal width are wrapped onto multiple lines.

    Uses Write-Output with ANSI escape codes (not Write-Host) so that the
    PSScriptAnalyzer AvoidUsingWriteHost rule is not triggered, while still
    rendering colored output in a supporting terminal.

.EXAMPLE
    pwsh -File scripts/Show-Help.ps1
#>

# ANSI color escape codes (safe with Write-Output; avoids AvoidUsingWriteHost)
$Cyan   = "$([char]27)[36m"
$Yellow = "$([char]27)[33m"
$Magenta = "$([char]27)[35m"
$Green  = "$([char]27)[32m"
$Bold   = "$([char]27)[1m"
$Reset  = "$([char]27)[0m"

function Get-DisplayWidth {
    # Counts terminal cells: ANSI escapes = 0, wide chars (CJK / emoji) = 2, else 1.
    param([string]$Text)
    $clean = $Text -replace "\x1b\[[0-9;]*m", ''
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

function Wrap-Text {
    # Wraps $Text to $Width display columns, word-aware, hard-splitting words
    # that exceed the width.
    param([string]$Text, [int]$Width)
    if ([string]::IsNullOrEmpty($Text)) { return @('') }
    $lines = [System.Collections.Generic.List[string]]::new()
    $words = $Text -split '\s+'
    $cur = ''
    foreach ($word in $words) {
        while ((Get-DisplayWidth -Text $word) -gt $Width) {
            $lines.Add($word.Substring(0, $Width))
            $word = $word.Substring($Width)
        }
        $test = if ($cur.Length -eq 0) { $word } else { "$cur $word" }
        if ((Get-DisplayWidth -Text $test) -gt $Width) {
            if ($cur.Length -gt 0) { $lines.Add($cur) }
            $cur = $word
        } else {
            $cur = $test
        }
    }
    if ($cur.Length -gt 0) { $lines.Add($cur) }
    return $lines.ToArray()
}

# ── Parse documented Makefile targets ──────────────────────────────────────────
$makefile = Join-Path $PSScriptRoot '..' 'Makefile'
$entries = [System.Collections.Generic.List[PSCustomObject]]::new()
Select-String -Path $makefile -Pattern '^[a-zA-Z_-]+:.*?## .*$' | ForEach-Object {
    $parts = $_.Line -split ':.*?## '
    $entries.Add([PSCustomObject]@{
        Name = $parts[0].Trim()
        Desc = $parts[1].Trim()
    })
}

# ── Column widths ──────────────────────────────────────────────────────────────
$nameW = ($entries | ForEach-Object { Get-DisplayWidth -Text $_.Name } | Measure-Object -Maximum).Maximum
$descMax = ($entries | ForEach-Object { Get-DisplayWidth -Text $_.Desc } | Measure-Object -Maximum).Maximum

try { $termW = $Host.UI.RawUI.WindowSize.Width } catch { $termW = 0 }
if ($termW -lt 60) { $termW = 100 }
$descW = [Math]::Min($descMax, ($termW - $nameW - 7))
if ($descW -lt 40) { $descW = 40 }

function Format-TableRow {
    param(
        [string]$Name,
        [string]$Desc,
        [string]$LeftBorder,
        [string]$Sep,
        [string]$RightBorder,
        [string]$NameColor
    )
    # @(...) guards against PowerShell unrolling a single-line result into a scalar.
    $wrapped = @(Wrap-Text -Text $Desc -Width $descW)
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $wrapped.Count; $i++) {
        $n = if ($i -eq 0) { $Name } else { '' }
        $npad = [Math]::Max(0, $nameW - (Get-DisplayWidth -Text $n))
        $dpad = [Math]::Max(0, $descW - (Get-DisplayWidth -Text $wrapped[$i]))
        $row = $Cyan + $LeftBorder + $Reset + ' ' + $NameColor + $n + (' ' * $npad) + $Reset + `
            ' ' + $Cyan + $Sep + $Reset + ' ' + $wrapped[$i] + (' ' * $dpad) + ' ' + $Cyan + $RightBorder + $Reset
        $out.Add($row)
    }
    return $out.ToArray()
}

$innerName = $nameW + 2
$innerDesc = $descW + 2
$top    = "$Cyan╔$('═' * $innerName)╦$('═' * $innerDesc)╗$Reset"
$header = "$Cyan╠$('═' * $innerName)╬$('═' * $innerDesc)╣$Reset"
$bottom = "$Cyan╚$('═' * $innerName)╩$('═' * $innerDesc)╝$Reset"

# ── Title ──────────────────────────────────────────────────────────────────────
Write-Output ''
Write-Output "${Cyan}╔══════════════════════════════════════════════════════════╗${Reset}"
Write-Output "${Cyan}║  HPE ProLiant ISO Automation - Available Commands         ║${Reset}"
Write-Output "${Cyan}╚══════════════════════════════════════════════════════════╝${Reset}"
Write-Output ''

# ── Command table ──────────────────────────────────────────────────────────────
Write-Output $top
Format-TableRow -Name 'Command' -Desc 'Description' -LeftBorder '║' -Sep '║' -RightBorder '║' -NameColor $Bold | ForEach-Object { Write-Output $_ }
Write-Output $header
foreach ($e in $entries) {
    Format-TableRow -Name $e.Name -Desc $e.Desc -LeftBorder '║' -Sep '║' -RightBorder '║' -NameColor $Green | ForEach-Object { Write-Output $_ }
}
Write-Output $bottom
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

$titleLine = "${Bold}💡 Maintenance Tip${Reset}"
$contentLines = @(
    $titleLine,
    $Tip,
    "Ispeci pa reci, Pomalo, Kad na vrbi rodi grožđe.",
    "Tko vino večera, vodu doručkuje."
)
$innerW = ($contentLines | ForEach-Object { Get-DisplayWidth -Text $_ } | Measure-Object -Maximum).Maximum + 2

$topBorder = "${Magenta}╔$('═' * $innerW)╗${Reset}"
$sepBorder = "${Magenta}╟$('─' * $innerW)╢${Reset}"
$botBorder = "${Magenta}╚$('═' * $innerW)╝${Reset}"

function Format-BoxLine {
    param([string]$Text, [string]$Color, [int]$InnerWidth)
    $displayWidth = Get-DisplayWidth -Text $Text
    $pad = [Math]::Max(0, $InnerWidth - $displayWidth - 2)
    Write-Output ("$Color║${Reset} $Text" + (' ' * $pad) + " $Color║${Reset}")
}

Write-Output $topBorder
Format-BoxLine -Text $titleLine -Color $Magenta -InnerWidth $innerW
Write-Output $sepBorder
Format-BoxLine -Text $Tip -Color $Yellow -InnerWidth $innerW
Format-BoxLine -Text "Ispeci pa reci, Pomalo, Kad na vrbi rodi grožđe." -Color $Cyan -InnerWidth $innerW
Format-BoxLine -Text "Tko vino večera, vodu doručkuje." -Color $Cyan -InnerWidth $innerW
Write-Output $botBorder
Write-Output ''
