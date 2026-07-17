#
# scripts/Generate-PSDocs.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Auto-generate clean Markdown API reference docs from PowerShell comment-based
# help blocks extracted directly from each source file.
#
# Scans:
#   • src/powershell/Automation/Public/*.ps1 (public functions)
#   • src/powershell/Automation/Private/*.ps1 (private functions)
#   • scripts/*.ps1 (script files with embedded functions)
#
# Output style is deliberately kept clean and consistent:
#   • Front-matter with source / timestamp
#   • # CmdletName
#   • ## Description (prose)
#   • ## Parameters (table)
#   • ## Examples (fenced code blocks)
#   • Raw comment block in a fenced PowerShell block for reference
#
# This makes the powershell/ generated docs look and feel similar.
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

if (-not $ModuleRoot) { $ModuleRoot = Join-Path $repoRoot 'src\powershell\Automation' }
$ModuleRoot = (Get-Item -LiteralPath $ModuleRoot).FullName

if (-not $OutputDir) { $OutputDir = Join-Path $repoRoot 'docs/dynamic-code-docs' }
New-Item -ItemType Directory -Force -Path $OutputDir -ErrorAction Stop | Out-Null

# Clear existing files in output directory for clean generation
Get-ChildItem -Path $OutputDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Output "[Generate-PSDocs] Module root : $ModuleRoot"
Write-Output "[Generate-PSDocs] Output dir  : $OutputDir"

# ─────────────────────────────────────────────────────────────────────────────
#  Robust comment-block extractor (handles PS 5.1 / 7 syntax differences)
# ─────────────────────────────────────────────────────────────────────────────

function Get-FunctionCommentPairs {
    [OutputType([pscustomobject[]])]
    param([string]$Path)

    $content = Get-Content -Raw -LiteralPath $Path
    $pairs   = [System.Collections.Generic.List[pscustomobject]]::new()

    # Real function declarations: 'function <Name> {' (the '{' excludes prose
    # such as "function is NOT part of ...").
    $fnPattern = 'function\s+([A-Za-z0-9_-]+)\s*\{'
    $fnMatches = [regex]::Matches($content, $fnPattern)

    foreach ($m in $fnMatches) {
        $name   = $m.Groups[1].Value
        $openB  = $m.Index + $m.Length          # position just after the '{'
        $comment = $null

        # Find the first <# ... #> block that opens AFTER the function '{'
        $cOpen = $content.IndexOf('<#', $openB)
        if ($cOpen -ge 0) {
            $cClose = $content.IndexOf('#>', $cOpen + 2)
            if ($cClose -ge 0) {
                $inner = $content.Substring($cOpen + 2, $cClose - $cOpen - 2).Trim()
                if ($inner.Length -gt 0 -and $inner -match '\.SYNOPSIS') {
                    $comment = $inner -split "`n"
                }
            }
        }

        $pairs.Add([pscustomobject]@{
            Name    = $name
            Comment = $comment
        })
    }

    return $pairs
}

# Returns the file-level <# .SYNOPSIS #> block (the first <# ... #> that appears
# BEFORE the first function declaration), or $null.
function Get-FileHeaderComment {
    [OutputType([string[]])]
    param([string]$Path)

    $content = Get-Content -Raw -LiteralPath $Path

    $fnFirst = $content.IndexOf('function', 0)
    # If a function exists, only consider comment blocks that start before it.
    $limit = if ($fnFirst -ge 0) { $fnFirst } else { $content.Length }

    $pos = 0
    while ($pos -lt $limit) {
        $open  = $content.IndexOf('<#', $pos)
        if ($open -lt 0 -or $open -ge $limit) { break }
        $close = $content.IndexOf('#>', $open + 2)
        if ($close -lt 0 -or $close -ge $limit) { break }
        $inner = $content.Substring($open + 2, $close - $open - 2).Trim()
        if ($inner.Length -gt 0 -and $inner -match '\.SYNOPSIS') {
            return ($inner -split "`n")
        }
        $pos = $close + 2
    }
    return $null
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
#  Per-file Markdown rendering (consistent style)
# ─────────────────────────────────────────────────────────────────────────────

function Format-FunctionDoc {
    [OutputType([string])]
    param(
        [string]$CmdName,
        [string]$RelPath,
        [pscustomobject]$Doc
    )

    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'

    $md = @()
$md += '---'
$md += "source:  $RelPath"
$md += "generated: $ts"
$md += 'auto_generated_by: scripts/Generate-PSDocs.ps1'
$md += '---'
$md += ''
    $md += "# $CmdName"
$md += ''

# Description (prefer .DESCRIPTION, fall back to .SYNOPSIS)
$desc = if ($Doc.Description) { $Doc.Description } else { $Doc.Synopsis }
if ($desc) {
    $md += '## Description'
    $md += ''
    $md += $desc
$md += ''
}

# Parameters table (consistent format)
    if ($Doc.Parameters.Count -gt 0) {
    $md += '## Parameters'
    $md += ''
    $md += '| Parameter | Description |'
    $md += '|-----------|-------------|'
    foreach ($p in $Doc.Parameters) {
    $help = ($p.Help -replace "`n", ' ').Trim()
        $md += "| ``-$($p.Name)`` | $help |"
}
    $md += ''
    }

# Examples
if ($Doc.Examples.Count -gt 0) {
    $md += '## Examples'
    $md += ''
    $i = 1
    foreach ($ex in $Doc.Examples) {
        $md += "### Example $i"
        $md += '```powershell'
            $md += $ex.Trim()
        $md += '```'
        $md += ''
        $i++
}
}

# Raw help block (for reference)
if ($Doc.Raw) {
        $md += '## Original Comment-Based Help'
    $md += '```powershell'
    $md += $Doc.Raw
$md += '```'
$md += ''
}

$md += '---'
$md += '*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*'
$md += ''

return ($md -join "`n")
}

# Determine relative path for docs (consistent src/powershell or scripts style)
function Get-RelSourcePath {
[OutputType([string])]
param([string]$FullPath)
$relPath = Resolve-Path -Relative $FullPath
if ($relPath -match '^.+\\src\\powershell\\') {
$relPath = $relPath -replace '^.+\\src\\powershell\\', 'src/powershell/'
} elseif ($relPath -match '^.+\\scripts\\') {
$relPath = $relPath -replace '^.+\\scripts\\', 'scripts/'
}
return $relPath
}

$publicDir = Join-Path $ModuleRoot 'Public'
$privateDir = Join-Path $ModuleRoot 'Private'
$scriptsDir = Join-Path $repoRoot 'scripts'

$files = Get-ChildItem $publicDir -Filter *.ps1 -Recurse | Where-Object { $_.Name -ne '_Validate-Request.ps1' }
$files += Get-ChildItem $privateDir -Filter *.ps1 -Recurse
$files += Get-ChildItem $scriptsDir -Filter *.ps1 -Recurse | Where-Object { $_.FullName -notlike '*modules*' }

$generated = @()
$seenNames = @{}   # guard against duplicate function names across files

foreach ($f in $files) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $relPath = Get-RelSourcePath -FullPath $f.FullName
    $pairs = Get-FunctionCommentPairs -Path $f.FullName

    # Emit a doc for the file-level <# .SYNOPSIS #> header (e.g. script files
    # that are run directly and declare no functions). Named after the file stem.
    $fileHeader = Get-FileHeaderComment -Path $f.FullName
    if ($fileHeader -and -not $seenNames.ContainsKey($stem)) {
        $doc = ConvertFrom-CommentBlock -Lines $fileHeader
        $md  = Format-FunctionDoc -CmdName $stem -RelPath $relPath -Doc $doc
        $outFile = Join-Path $OutputDir "$stem.md"
        [IO.File]::WriteAllText($outFile, $md, [System.Text.UTF8Encoding]::new($false))
        Write-Output "  OK   $stem.md"
        $generated += "$stem.md"
        $seenNames[$stem] = $stem
    }

    if ($pairs.Count -eq 0) {
        if (-not $fileHeader) { Write-Warning "  SKIP  $stem - no function declarations or file header found" }
        continue
    }

    foreach ($pair in $pairs) {
        $cmdName = $pair.Name
        if (-not $pair.Comment) {
            Write-Warning "  SKIP  $cmdName ($stem) - no <# .SYNOPSIS #> help block"
            continue
        }
        if ($seenNames.ContainsKey($cmdName)) {
            Write-Warning "  DUP   $cmdName already documented from $($seenNames[$cmdName]); skipping $stem"
            continue
        }

        $doc = ConvertFrom-CommentBlock -Lines $pair.Comment
        $md  = Format-FunctionDoc -CmdName $cmdName -RelPath $relPath -Doc $doc

        $outFile = Join-Path $OutputDir "$cmdName.md"
        [IO.File]::WriteAllText($outFile, $md, [System.Text.UTF8Encoding]::new($false))
        Write-Output "  OK   $cmdName.md"
        $generated += "$cmdName.md"
        $seenNames[$cmdName] = $stem
    }
}

# INDEX.md
$indexPath = Join-Path $OutputDir 'INDEX.md'
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'
$idx = @(
    '# PowerShell Module - Generated API Reference',
    '',
    '> Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.',
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
Write-Output "  OK   INDEX.md"

Write-Output ""
Write-Output "[Generate-PSDocs] Done. $($generated.Count) file(s) written to $OutputDir"
