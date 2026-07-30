<#
.SYNOPSIS
    Adds Bitbucket/GitStash compatible anchors to markdown headings and generates a Table of Contents (TOC).

.DESCRIPTION
    Processes markdown files across the entire repository, ensuring each file has a valid TOC
    and matching anchor tags above every H2/H3 heading. Files already in canonical form are left
    untouched. Scans all folders recursively (including docs/, configs/, src/, and root README.md).
    Results are logged to generated/logs/toc-anchor/.

.PARAMETER InputFileName
    Relative path to a markdown file inside the repository (e.g. "docs/Generic/testing.md").

.PARAMETER All
    Recursively scan all .md files across the entire repository and fix or validate each one.

.PARAMETER DryRun
    Validate without writing changes. Reports pass/fail for every file processed.

.EXAMPLE
    .\bitbucket-md-anchor-toc.ps1 -InputFileName "docs/Generic/testing.md"
    Fixes a single file (writes changes in-place).

.EXAMPLE
    .\bitbucket-md-anchor-toc.ps1 -InputFileName "configs/README.md" -DryRun
    Validates a file without making changes.

.EXAMPLE
    .\bitbucket-md-anchor-toc.ps1 -All
    Fixes every .md file in the entire repository in-place.

.EXAMPLE
    .\bitbucket-md-anchor-toc.ps1 -All -DryRun
    Validates every .md file in the entire repository without making changes.

.EXAMPLE
    . .\bitbucket-md-anchor-toc.ps1      # dot-source to just define the function
    Add-BitbucketMdToc -All -DryRun       # then call it manually
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InputFileName,

    [switch]$All,

    [switch]$DryRun
)

$script:ScriptDir = $PSScriptRoot
$script:RepoRoot  = Split-Path -Parent $script:ScriptDir
$script:LogDir    = Join-Path $script:RepoRoot "generated/logs/toc-anchor"
$script:LogFile   = $null

function Write-Status {
    <#
    .SYNOPSIS
        Writes status.
    #>

    param([string]$Color, [string]$Message)
    $cleanMessage = $Message -replace '\x1b\[[0-9;]*m', ''
    Write-Output "${Color}${Message}${script:Reset}"
    if ($script:LogFile) {
        $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $cleanMessage"
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
    }
}

$script:Green  = "`e[0;32m"
$script:Yellow = "`e[1;33m"
$script:Red    = "`e[0;31m"
$script:Cyan   = "`e[0;36m"
$script:Reset  = "`e[0m"

function Add-BitbucketMdToc {
    <#
    .SYNOPSIS
        Adds bitbucket md toc.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InputFileName,

        [switch]$All,

        [switch]$DryRun
    )

    # ------------------------------------------------------------------
    # Anchor algorithm (preserved from original script)
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

    # ------------------------------------------------------------------
    # Helpers: strip existing TOC and anchors so regeneration is idempotent
    # ------------------------------------------------------------------
    function Remove-ExistingToc([string[]]$lines) {
        $result  = [System.Collections.Generic.List[string]]::new()
        $skipToc = $false

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($skipToc) {
                # Within the TOC zone: keep skipping blank lines and TOC entry lines.
                # Stop skipping as soon as we encounter a non-blank, non-TOC-entry line.
                $isBlank      = $lines[$i] -match '^\s*$'
                $isTocEntry   = $lines[$i] -match '^\s*- \[[^\]]+\]\(#[^)]+\)$'
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
            # The "top" anchor is owned by this builder: always strip any existing
            # one so it can be re-inserted in the canonical position (right after
            # the H1, above the TOC) by Build-CanonicalContent.
            if ($lines[$i] -match '^<a\s+id="top"\s*></a>\s*$') {
                continue
            }

            $isAnchorLine = $lines[$i] -match '^<a name="[^"]*"></a>$'
            if ($isAnchorLine) {
                # Allow a blank line between the anchor and the heading it precedes
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

    # ------------------------------------------------------------------
    # Generate canonical content (anchors + TOC) from raw file lines
    # ------------------------------------------------------------------
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
                    # H1 stays at the top; the TOC is inserted right after it
                    # (which supplies the required blank line below it).
                    $updatedContent.Add($line)
                    continue
                }

                # MD022: every heading must be surrounded by blank lines. This
                # also fixes the common case where a heading directly follows a
                # list (ordered/unordered) with no blank gap.
                Ensure-BlankBefore $updatedContent

                if ($level -le 3) {
                    $anchor = Get-Anchor $title ([ref]$anchorsSeen)
                    $indent = '  ' * ($level - 2)
                    $toc.Add("$indent- [$title](#$anchor)")

                    # Separate the anchor from any preceding block (e.g. lists)
                    # with a blank line, and put a blank line between the anchor
                    # and the heading it targets.
                    $updatedContent.Add("<a name=""$anchor""></a>")
                    $updatedContent.Add('')
                }

                $updatedContent.Add($line)
                $needBlankBeforeNext = $true
            } else {
                # Collapse runs of consecutive blank lines into a single blank
                # line so the generated doc stays MD012-compliant (a single gap,
                # never multiple).
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
                # Anchor the top of the document immediately below the H1, then the
                # TOC follows. This keeps "#top" links working and the anchor above
                # the TOC (where it belongs).
                $finalContent.Add("")
                $finalContent.Add('<a id="top"></a>')
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

        # Collapse any remaining runs of consecutive blank lines (e.g. the TOC
        # block's trailing blank combined with the blank after H1) into a single
        # blank line, then trim leading/trailing blanks.
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

        return $finalContent.ToArray()
    }

    # ------------------------------------------------------------------
    # Structural validation (detailed per-issue messages)
    # ------------------------------------------------------------------
    function Test-TocValidity([string[]]$lines) {
        $issues = [System.Collections.Generic.List[string]]::new()

        if ($lines.Count -eq 0 -or $lines[0] -notmatch '^#\s+') {
            $issues.Add("Missing H1 title at document start")
            return $issues.ToArray()
        }

        $tocStartIndex = -1
        $searchLimit   = [Math]::Min($lines.Count, 40)
        for ($i = 1; $i -lt $searchLimit; $i++) {
            if ($lines[$i] -match '^## Table of Contents$') {
                $tocStartIndex = $i
                break
            }
        }

        if ($tocStartIndex -eq -1) {
            $issues.Add("Missing '## Table of Contents' section after H1")
            return $issues.ToArray()
        }

        $tocEntries = @{}
        $entryStart = $tocStartIndex + 1
        # Skip any blank lines between the TOC heading and the first entry
        while ($entryStart -lt $lines.Count -and $lines[$entryStart] -match '^\s*$') {
            $entryStart++
        }
        for ($i = $entryStart; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*- \[([^\]]+)\]\(#([^)]+)\)$') {
                $tocEntries[$matches[2]] = $true
            } elseif ($lines[$i] -match '^\s*$') {
                break
            } else {
                $issues.Add("Invalid TOC entry format: ""$($lines[$i])""")
            }
        }

        if ($tocEntries.Count -eq 0) {
            $issues.Add("TOC contains no entries; cannot validate heading anchors")
        }

        $anchorsSeen = @{}
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq '## Table of Contents') {
                continue
            }
            if ($lines[$i] -match '^(#{2,3})\s+(.+)$') {
                $headingTitle   = $matches[2]
                $expectedAnchor = Get-Anchor $headingTitle ([ref]$anchorsSeen)
                $expectedTag    = "<a name=""$expectedAnchor""></a>"

                if ($i -eq 0) {
                    $issues.Add("Heading '$headingTitle' on line 1 has no preceding line for anchor tag")
                } else {
                    # A blank line must separate the heading from the previous
                    # block, and the anchor must sit one line above the heading
                    # (with a blank line between) for MD022 compliance.
                    $anchorAbove =
                        ($lines[$i - 1] -eq $expectedTag) -or
                        ($i -ge 2 -and $lines[$i - 1] -eq '' -and $lines[$i - 2] -eq $expectedTag)

                    if (-not $anchorAbove) {
                        $issues.Add("Heading '$headingTitle' missing/incorrect anchor above: expected '$expectedTag', found '$($lines[$i-1])'")
                    }
                    # MD022: a blank line must separate the heading from the
                    # previous block (the anchor sits one line above, with a blank
                    # line between).
                    if ($lines[$i - 1] -ne '' -and $lines[$i - 1] -ne $expectedTag) {
                        $issues.Add("Heading '$headingTitle' is not separated from the previous block by a blank line (MD022)")
                    }
                }

                if ($tocEntries.Count -gt 0 -and -not $tocEntries.ContainsKey($expectedAnchor)) {
                    $issues.Add("Heading '$headingTitle' anchor '#$expectedAnchor' not present in TOC")
                }
            }
        }

        foreach ($entry in $tocEntries.Keys) {
            $found      = $false
            $checkSeen  = @{}
            for ($ci = 0; $ci -lt $lines.Count; $ci++) {
                if ($lines[$ci] -eq '## Table of Contents') { continue }
                if ($lines[$ci] -match '^(#{2,3})\s+(.+)$') {
                    $ta = Get-Anchor $matches[2] ([ref]$checkSeen)
                    if ($ta -eq $entry) { $found = $true; break }
                }
            }
            if (-not $found) {
                $issues.Add("TOC entry '#$entry' has no matching heading in the document (stale link)")
            }
        }

        return $issues.ToArray()
    }

    # ------------------------------------------------------------------
    # Single-file processing: generate canonical form, compare, fix/validate
    # ------------------------------------------------------------------
    function Invoke-FileProcess([string]$filePath, [switch]$DryRun) {
        $originalLines  = Get-Content $filePath
        $canonicalLines = Build-CanonicalContent $originalLines

        $originalText  = $originalLines  -join "`n"
        $canonicalText = $canonicalLines -join "`n"

        if ($originalText -eq $canonicalText) {
            Write-Status $script:Green "PASS: $filePath"
            return $true
        }

        if ($DryRun) {
            Write-Status $script:Red "FAIL: $filePath"
            $issues = Test-TocValidity $originalLines
            foreach ($issue in $issues) {
                Write-Status $script:Yellow "  - $issue"
            }
            return $false
        }

        $canonicalText | Set-Content $filePath -Encoding utf8
        Write-Status $script:Cyan "FIXED: $filePath"
        return $false
    }

    # ==================================================================
    # Dispatch: -All or single file via -InputFileName
    # ==================================================================
    $repoRoot = $script:RepoRoot

    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }
    $logTimestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $script:LogFile = Join-Path $script:LogDir "toc-anchor-$logTimestamp.log"
    Add-Content -Path $script:LogFile -Value "=== TOC/Anchor Log Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Encoding UTF8
    Add-Content -Path $script:LogFile -Value "Repository root : $repoRoot" -Encoding UTF8
    Add-Content -Path $script:LogFile -Value "DryRun         : $DryRun" -Encoding UTF8

    Write-Status $script:Cyan "Scanning repository for markdown files..."

    if ($All) {
        $files = Get-ChildItem -Path $repoRoot -Filter *.md -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '(^|[\\/])\.git([\\/]|$)' -and
                $_.FullName -notmatch '(^|[\\/])generated([\\/]|$)' -and
                $_.FullName -notmatch '(^|[\\/])(scripts|vendor)[\\/]modules([\\/]|$)'
            } |
            Sort-Object FullName

        $passCount = 0
        $failCount = 0

        if ($files.Count -eq 0) {
            Write-Status $script:Yellow "No .md files found in repository: $repoRoot"
            return
        }

        Write-Status $script:Green "Found $($files.Count) markdown file(s) to process"

        foreach ($file in $files) {
            $ok = Invoke-FileProcess -filePath $file.FullName -DryRun:$DryRun
            if ($ok) { $passCount++ } else { $failCount++ }
        }

        Write-Output ""
        Write-Status $script:Cyan "=== Summary ==="
        Write-Status $script:Green "Files  : $($files.Count)"
        Write-Status $script:Green "Passed : $passCount"
        if ($failCount -gt 0) {
            Write-Status $script:Red "Failed : $failCount"
        } else {
            Write-Status $script:Green "Failed : $failCount"
        }
        Write-Status $script:Cyan "Log    : $($script:LogFile)"
    }
    elseif ($InputFileName) {
        $filePath = Join-Path $repoRoot $InputFileName
        if (-not (Test-Path $filePath)) {
            Write-Error "File not found (relative to repo root): $InputFileName"
            return
        }
        $filePath = (Resolve-Path $filePath).Path
        $null = Invoke-FileProcess -filePath $filePath -DryRun:$DryRun
        Write-Status $script:Cyan "Log: $($script:LogFile)"
    }
    else {
        Write-Error "Specify -InputFileName <relative-path> or -All. Use -DryRun to validate without writing."
    }
}

# Auto-invoke when the script is executed directly (not when dot-sourced for just the function)
if ($MyInvocation.InvocationName -ne '.') {
    Add-BitbucketMdToc -InputFileName $InputFileName -All:$All -DryRun:$DryRun
}
