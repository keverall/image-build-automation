param()

<#
.DESCRIPTION
    Parses docs/Automation/automation_commands.md to determine which commands
    are documented, intersects that set with the real functions declared under
    src/powershell/Automation/Public, and prints a bordered table of each
    command with its synopsis.

    This is the companion to `Get-CommandHelp` / the per-command `-Help`
    switch: it gives a quick inventory of "what commands exist", while
    `Get-CommandHelp <Name>` (or `<Name> -Help`) shows the detailed man-page
    reference for one command.

    Sources-of-truth:
      * docs/Automation/automation_commands.md — the allowlist of commands.
        SCOM-only helpers (New-ScomConnection, New-ScomMaintenanceScript,
        Test-ScomMaintenanceConnectivity, ...) are intentionally absent from
        the doc and therefore excluded from this table automatically.
      * src/powershell/Automation/Public/*.ps1  — the real function definitions.

    Uses Write-Output with ANSI escape codes (not Write-Host) so that the
    PSScriptAnalyzer AvoidUsingWriteHost rule is not triggered, while still
    rendering colored output in a supporting terminal.

.EXAMPLE
    pwsh -File scripts/list-commands.ps1
#>

# Resolve paths relative to the repository root (parent of scripts/).
$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path $scriptDir -Parent
$publicDir = Join-Path $repoRoot 'src/powershell/Automation/Public'
$docPath   = Join-Path $repoRoot 'docs/Automation/automation_commands.md'

# ── ANSI palette ────────────────────────────────────────────────────────────────
$Cyan   = "$([char]27)[36m"
$Yellow = "$([char]27)[33m"
$Green  = "$([char]27)[32m"
$Bold   = "$([char]27)[1m"
$Reset  = "$([char]27)[0m"

function Get-DisplayWidth {
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

function Get-SynopsisForFunction {
    param([string]$Content, [string]$FunctionName)
    # Locate this function's own declaration, then read the .SYNOPSIS that
    # belongs to its (inline) comment-based help block.
    $mFn = [regex]::Match($Content, "(?m)^\s*function\s+$([regex]::Escape($FunctionName))\b")
    if (-not $mFn.Success) { return '' }
    $rest = $Content.Substring($mFn.Index)
    $m = [regex]::Match($rest, '(?s)\.SYNOPSIS\s*\r?\n(.*?)(?=\.\w+\s|#>)')
    if (-not $m.Success) { return '' }
    $lines = $m.Groups[1].Value -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^\.' }
    if ($lines.Count -eq 0) { return '' }
    return (($lines | Select-Object -First 1) -join ' ').Trim()
}

# ── Build the allowlist from the documentation ─────────────────────────────────
# docs/Automation/automation_commands.md is the single source of truth for which
# commands are surfaced by `make list-commands`. Only Verb-Noun tokens that also
# exist as real functions under Public/ are included, so the doc's occasional
# references to external library cmdlets (e.g. Connect-OVMgmt, Enable-OVMgmt,
# Get-Help) are filtered out. SCOM-only commands are absent from the doc, so they
# are excluded automatically.
$documented = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path $docPath) {
    $docText = Get-Content $docPath -Raw
    foreach ($m in [regex]::Matches($docText, '(?<![\w-])[A-Z][a-z]+-[A-Z][a-zA-Z0-9-]+(?![\w-])')) {
        [void]$documented.Add($m.Value)
    }
}

# ── Map every non-internal function declared in Public/ to its source content ────
$allPublicFunctions = @{}
if (Test-Path $publicDir) {
    Get-ChildItem $publicDir -Filter '*.ps1' | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        foreach ($m in [regex]::Matches($content, '(?m)^\s*function\s+([A-Za-z][A-Za-z0-9_-]*)')) {
            $fn = $m.Groups[1].Value
            if ($fn -and -not $fn.StartsWith('_') -and -not $allPublicFunctions.ContainsKey($fn)) {
                $allPublicFunctions[$fn] = $content
            }
        }
    }
}

# ── Collect commands ──────────────────────────────────────────────────────────
$entries = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($name in $documented) {
    if ($allPublicFunctions.ContainsKey($name)) {
        $entries.Add([PSCustomObject]@{
            Name = $name
            Desc = Get-SynopsisForFunction -Content $allPublicFunctions[$name] -FunctionName $name
        })
    }
}

# Sort by command name for a stable, predictable table.
$sortedEntries = $entries | Sort-Object Name
$entries = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($e in $sortedEntries) { $entries.Add($e) }

if ($entries.Count -eq 0) {
    Write-Output "${Yellow}No documented commands found in $publicDir (doc: $docPath)${Reset}"
    exit 0
}

# ── Column widths ───────────────────────────────────────────────────────────────
$nameW  = ($entries | ForEach-Object { Get-DisplayWidth -Text $_.Name } | Measure-Object -Maximum).Maximum
$descMax = ($entries | ForEach-Object { Get-DisplayWidth -Text $_.Desc } | Measure-Object -Maximum).Maximum

try { $termW = $Host.UI.RawUI.WindowSize.Width } catch { $termW = 0 }
if ($termW -lt 60) { $termW = 100 }
$descW = [Math]::Min($descMax, ($termW - $nameW - 7))
if ($descW -lt 40) { $descW = 40 }

function Format-TableRow {
    param([string]$Name, [string]$Desc, [string]$LeftBorder, [string]$Sep, [string]$RightBorder, [string]$NameColor)
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

# Dynamic banner width: 2 (borders) + nameW + 3 (sep+pad) + descW + 2 (pad+border).
$bannerW = $innerName + $innerDesc + 6
$bannerLine = '═' * [Math]::Max($bannerW, 80)
$countStr = $entries.Count.ToString()
$label    = "HPE ProLiant ISO Automation - Available Commands ($countStr)"
$padCount = [Math]::Max(0, $bannerW - 2 - $label.Length)

Write-Output ''
Write-Output "${Cyan}╔${bannerLine}╗${Reset}"
Write-Output "${Cyan}║  ${label}$(' ' * $padCount)║${Reset}"
Write-Output "${Cyan}╚${bannerLine}╝${Reset}"
Write-Output ''

Write-Output $top
Format-TableRow -Name 'Command' -Desc 'Synopsis' -LeftBorder '║' -Sep '║' -RightBorder '║' -NameColor $Bold | ForEach-Object { Write-Output $_ }
Write-Output $header
foreach ($e in $entries) {
    Format-TableRow -Name $e.Name -Desc $e.Desc -LeftBorder '║' -Sep '║' -RightBorder '║' -NameColor $Green | ForEach-Object { Write-Output $_ }
}
Write-Output $bottom
Write-Output ''
Write-Output "${Green}Tip:${Reset} run ${Bold}<CommandName> -Help${Reset} (or ${Bold}Get-CommandHelp <CommandName>${Reset}) for the full man-page reference."
Write-Output ''
