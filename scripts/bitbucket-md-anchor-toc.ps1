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

# Shared logging + canonical top-anchor placement come from Docs.Common.ps1 so this
# script cannot drift from validate-docs-links.ps1 (the other half of `make fix-docs`).
. (Join-Path $PSScriptRoot 'Docs.Common.ps1')

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


    # Anchor algorithm + Build-CanonicalContent now live in the shared
    # Docs.Common.ps1 (dot-sourced above) so this script cannot drift from
    # Generate-PSDocs.ps1. They are referenced directly below.


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
                $expectedTag    = "<a id=""$expectedAnchor""></a>"

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
            Write-Status $Green "PASS: $filePath"
            return $true
        }

        if ($DryRun) {
            Write-Status $Red "FAIL: $filePath"
            $issues = Test-TocValidity $originalLines
            foreach ($issue in $issues) {
                Write-Status $Yellow "  - $issue"
            }
            return $false
        }

        $canonicalText | Set-Content $filePath -Encoding utf8
        Write-Status $Cyan "FIXED: $filePath"
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
    Set-DocsStatusLog -Path $script:LogFile
    Add-Content -Path $script:LogFile -Value "=== TOC/Anchor Log Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Encoding UTF8
    Add-Content -Path $script:LogFile -Value "Repository root : $repoRoot" -Encoding UTF8
    Add-Content -Path $script:LogFile -Value "DryRun         : $DryRun" -Encoding UTF8

    Write-Status $Cyan "Scanning repository for markdown files..."

    if ($All) {
        $files = Get-ChildItem -Path $repoRoot -Filter *.md -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '(^|[\\/])\.git([\\/]|$)' -and
                $_.FullName -notmatch '(^|[\\/])generated([\\/]|$)' -and
                $_.FullName -notmatch '(^|[\\/])dynamic-code-docs([\\/]|$)' -and
                $_.FullName -notmatch '(^|[\\/])(scripts|vendor)[\\/]modules([\\/]|$)'
            } |
            Sort-Object FullName

        $passCount = 0
        $failCount = 0

        if ($files.Count -eq 0) {
            Write-Status $Yellow "No .md files found in repository: $repoRoot"
            return
        }

        Write-Status $Green "Found $($files.Count) markdown file(s) to process"

        foreach ($file in $files) {
            $ok = Invoke-FileProcess -filePath $file.FullName -DryRun:$DryRun
            if ($ok) { $passCount++ } else { $failCount++ }
        }

        Write-Output ""
        Write-Status $Cyan "=== Summary ==="
        Write-Status $Green "Files  : $($files.Count)"
        Write-Status $Green "Passed : $passCount"
        if ($failCount -gt 0) {
            Write-Status $Red "Failed : $failCount"
        } else {
            Write-Status $Green "Failed : $failCount"
        }
        Write-Status $Cyan "Log    : $($script:LogFile)"
    }
    elseif ($InputFileName) {
        $filePath = Join-Path $repoRoot $InputFileName
        if (-not (Test-Path $filePath)) {
            Write-Error "File not found (relative to repo root): $InputFileName"
            return
        }
        $filePath = (Resolve-Path $filePath).Path
        $null = Invoke-FileProcess -filePath $filePath -DryRun:$DryRun
        Write-Status $Cyan "Log: $($script:LogFile)"
    }
    else {
        Write-Error "Specify -InputFileName <relative-path> or -All. Use -DryRun to validate without writing."
    }
}

# Auto-invoke when the script is executed directly (not when dot-sourced for just the function)
if ($MyInvocation.InvocationName -ne '.') {
    Add-BitbucketMdToc -InputFileName $InputFileName -All:$All -DryRun:$DryRun
}
