#
# scripts/Generate-PSDocs.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Auto-generate clean Markdown API reference docs from PowerShell comment-based
# help blocks extracted directly from each Public/*.ps1 source file.
#
# Output style is deliberately kept close to the Python generator:
#   • Front-matter with source / timestamp
#   • # CmdletName
#   • ## Description (prose)
#   • ## Parameters (table)
#   • ## Examples (fenced code blocks)
#   • Raw comment block in a fenced PowerShell block for reference
#
# This makes the python/ and powershell/ generated docs look and feel similar.
# ─────────────────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$Force,
    [string]$ModuleRoot,
    [string]$OutputDir
)

$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot  = Resolve-Path (Join-Path $scriptDir '..')

if (-not $ModuleRoot) { $ModuleRoot = Join-Path $repoRoot 'powershell\Automation' }
$ModuleRoot = (Get-Item -LiteralPath $ModuleRoot).FullName

if (-not $OutputDir) { $OutputDir = Join-Path $repoRoot 'docs\powershell\generated' }
New-Item -ItemType Directory -Force -Path $OutputDir -ErrorAction Stop | Out-Null

Write-Host "[Generate-PSDocs] Module root : $ModuleRoot"
Write-Host "[Generate-PSDocs] Output dir  : $OutputDir"

# ─────────────────────────────────────────────────────────────────────────────
#  Robust comment-block extractor (handles PS 5.1 / 7 syntax differences)
# ─────────────────────────────────────────────────────────────────────────────

function Get-LastCommentBlock {
    [OutputType([string[]])]
    param([string]$Path)

    $content = Get-Content -Raw -LiteralPath $Path
    $blocks  = [System.Collections.Generic.List[string]]::new()

    $pos = 0
    while ($pos -lt $content.Length) {
        $open  = $content.IndexOf('<#', $pos)
        if ($open -lt 0) { break }
        $close = $content.IndexOf('#>', $open + 2)
        if ($close -lt 0) { break }

        $inner = $content.Substring($open + 2, $close - $open - 2).Trim()
        if ($inner.Length -gt 0) { $blocks.Add($inner) }
        $pos = $close + 2
    }

    if ($blocks.Count -eq 0) { return $null }

    # Prefer the block that contains .SYNOPSIS (real help)
    for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
        if ($blocks[$i] -match '\.SYNOPSIS') { return ($blocks[$i] -split "`n") }
    }
    return ($blocks[$blocks.Count - 1] -split "`n")
}

function ConvertFrom-CommentBlock {
    [OutputType([pscustomobject])]
    param([string[]]$Lines)

    $result = [pscustomobject]@{
        Synopsis    = ''
        Description = ''
        Parameters  = [System.Collections.Generic.List[pscustomobject]]::new()
        Examples    = [System.Collections.Generic.List[string]]::new()
        Raw         = ($Lines -join "`n").Trim()
    }

    $mode   = 'none'
    $curKey = $null
    $buf    = [System.Text.StringBuilder]::new()

    function _Flush {
        param($r)
        $text = $buf.ToString().Trim()
        if (-not $text) { return }
        switch ($mode) {
            'desc'     { if (-not $r.Description) { $r.Description = $text } else { $r.Description += "`n$text" } }
            'param'    { if ($curKey) { $r.Parameters.Add([pscustomobject]@{Name=$curKey; Help=$text}) } }
            'example'  { $r.Examples.Add($text) }
            'synopsis' { if ($r.Synopsis) { $r.Synopsis += ' ' }; $r.Synopsis += $text }
        }
        $buf.Clear()
    }

    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if ($line -match '^\.SYNOPSIS\b') {
            _Flush $result
            $mode = 'synopsis'
            continue
        }
        elseif ($line -match '^\.DESCRIPTION\b') {
            _Flush $result
            $mode = 'desc'
            continue
        }
        elseif ($line -match '^\.PARAMETER\s+(\S+)') {
            _Flush $result
            $mode = 'param'
            $curKey = $Matches[1]
            continue
        }
        elseif ($line -match '^\.EXAMPLE\b') {
            _Flush $result
            $mode = 'example'
            continue
        }
        elseif ($line -match '^\.(RETURNS|INPUTS|OUTPUTS|NOTES|LINK)\b') {
            _Flush $result
            $mode = 'none'
            continue
        }

        if ($mode -ne 'none' -and $line -and -not $line.StartsWith('.')) {
            if ($buf.Length -gt 0) { [void]$buf.Append(' ') }
            [void]$buf.Append($line)
        }
    }
    _Flush $result
    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
#  Per-file Markdown rendering (style matched to Python generator)
# ─────────────────────────────────────────────────────────────────────────────

$publicDir = Join-Path $ModuleRoot 'Public'
$files = Get-ChildItem $publicDir -Filter *.ps1 -Recurse | Where-Object { $_.Name -ne '_Validate-Request.ps1' }

$generated = @()

foreach ($f in $files) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $lines = Get-LastCommentBlock -Path $f.FullName
    if (-not $lines) {
        Write-Warning "  SKIP  $stem — no <# … #> help block"
        continue
    }

    $doc = ConvertFrom-CommentBlock -Lines $lines

    # Derive display name
    $cmdName = $stem
    if ((Get-Content -Raw $f.FullName) -match 'function\s+([A-Za-z0-9_-]+)') { $cmdName = $Matches[1] }

    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'

    $md = @()
    $md += '---'
    $md += "source:  powershell/Automation/Public/$stem.ps1"
    $md += "generated: $ts"
    $md += "auto_generated_by: scripts/Generate-PSDocs.ps1"
    $md += '---'
    $md += ''
    $md += "# $cmdName"
    $md += ''

    # Description (prefer .DESCRIPTION, fall back to .SYNOPSIS)
    $desc = if ($doc.Description) { $doc.Description } else { $doc.Synopsis }
    if ($desc) {
        $md += '## Description'
        $md += ''
        $md += $desc
        $md += ''
    }

    # Parameters table (matches Python style)
    if ($doc.Parameters.Count -gt 0) {
        $md += '## Parameters'
        $md += ''
        $md += '| Parameter | Description |'
        $md += '|-----------|-------------|'
        foreach ($p in $doc.Parameters) {
            $help = ($p.Help -replace "`n", ' ').Trim()
            $md += "| ``-$($p.Name)`` | $help |"
        }
        $md += ''
    }

    # Examples
    if ($doc.Examples.Count -gt 0) {
        $md += '## Examples'
        $md += ''
        $i = 1
        foreach ($ex in $doc.Examples) {
            $md += "### Example $i"
            $md += '```powershell'
            $md += $ex.Trim()
            $md += '```'
            $md += ''
            $i++
        }
    }

    # Raw help block (for reference, like Python shows argparse --help)
    if ($doc.Raw) {
        $md += '## Original Comment-Based Help'
        $md += '```powershell'
        $md += $doc.Raw
        $md += '```'
        $md += ''
    }

    $md += '---'
    $md += '*Auto-generated by `scripts/Generate-PSDocs.ps1` — do not edit manually.*'
    $md += ''

    $outFile = Join-Path $OutputDir "$cmdName.md"
    [IO.File]::WriteAllText($outFile, ($md -join "`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Host "  OK   $cmdName.md"
    $generated += "$cmdName.md"
}

# INDEX.md
$indexPath = Join-Path $OutputDir 'INDEX.md'
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'
$idx = @(
    '# PowerShell Module — Generated API Reference',
    '',
    '> Auto-generated by `scripts/Generate-PSDocs.ps1` — do not edit manually.',
    '',
    "Generated: $ts",
    '',
    '## Cmdlets',
    ''
)
foreach ($fn in ($generated | Sort-Object)) {
    $name = [IO.Path]::GetFileNameWithoutExtension($fn)
    $idx += "- [$name]($fn)"
}
$idx += @('', '---', '')
[IO.File]::WriteAllText($indexPath, ($idx -join "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "  OK   INDEX.md"

Write-Host ""
Write-Host "[Generate-PSDocs] Done. $($generated.Count) file(s) written to $OutputDir"
