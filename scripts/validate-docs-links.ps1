#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate markdown file links in configs/, docs/, and root directories.

.DESCRIPTION
    Scans all .md files for markdown links pointing to source files and validates
    that they exist. Fixes broken links by searching for the target file and
    correcting the path. Reports errors for links that cannot be resolved.

.PARAMETER WhatIf
    Preview changes without modifying files (dry-run mode).

.EXAMPLE
    pwsh -File scripts/validate-docs-links.ps1
    pwsh -File scripts/validate-docs-links.ps1 -WhatIf
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Shared helpers (logging + canonical top-anchor placement) live in Docs.Common.ps1 so
# that `make docs` and `make fix-docs` cannot drift apart.
. (Join-Path $PSScriptRoot 'Docs.Common.ps1')

$RepoRoot = Split-Path -Parent $PSScriptRoot

# Setup logging
$LogTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogDir = Join-Path $RepoRoot "generated/logs/fix-docs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "fix-docs-$LogTimestamp.log"
Set-DocsStatusLog -Path $LogFile

# Log script start
Add-Content -Path $LogFile -Value "=== Fix Docs Log Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Encoding UTF8

function Find-TargetFile {
    <#
    .SYNOPSIS
        Finds target file.
    #>

    param([string]$TargetFilename)
    $files = Get-ChildItem -Path $RepoRoot -Filter $TargetFilename -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\.git|generated/|dynamic-code-docs' }
    
    if ($files.Count -eq 0) { return $null }
    if ($files.Count -eq 1) {
        return $files[0].FullName.Replace($RepoRoot, '').TrimStart('/')
    }
    $preferred = $files | Where-Object { $_.FullName -match 'src/powershell/Automation' } | Sort-Object FullName
    if ($preferred) {
        return $preferred[0].FullName.Replace($RepoRoot, '').TrimStart('/')
    }
    return $files[0].FullName.Replace($RepoRoot, '').TrimStart('/')
}

function Get-RelativeLink {
    <#
    .SYNOPSIS
        Gets relative link.
    #>

    param([string]$SourceFile, [string]$TargetPath)
    $sourceDir = Split-Path $SourceFile -Parent
    $targetFullPath = Join-Path $RepoRoot $TargetPath.TrimStart('/')
    $relativePath = [System.IO.Path]::GetRelativePath($sourceDir, $targetFullPath) -replace '\\', '/'
    return $relativePath
}

function Get-Anchor {
    <#
    .SYNOPSIS
        Gets anchor.
    #>

    param([string]$LinkPath)
    if ($LinkPath -match '#(.+)$') { return '#' + $Matches[1] }
    if ($LinkPath -match '\.md$') { return '#top' }
    return ''
}

function Get-MarkdownFiles {
    <#
    .SYNOPSIS
        Gets markdown files.
    #>

    $files = @()
    $files += Get-ChildItem -Path $RepoRoot -Filter *.md -File -ErrorAction SilentlyContinue
    $configsPath = Join-Path $RepoRoot 'configs'
    if (Test-Path $configsPath) {
        $files += Get-ChildItem -Path $configsPath -Filter *.md -File -ErrorAction SilentlyContinue
    }
    $docsPath = Join-Path $RepoRoot 'docs'
    if (Test-Path $docsPath) {
        $files += Get-ChildItem -Path $docsPath -Filter *.md -Recurse -File -ErrorAction SilentlyContinue
    }
    return $files | Where-Object { $_.FullName -notmatch '\.git|dynamic-code-docs' }
}

Write-Status $Cyan "Scanning markdown files for validation..."
$mdFiles = Get-MarkdownFiles
Write-Status $Green "Found $($mdFiles.Count) markdown files to check"

$results = @{
    Valid = 0
    Invalid = 0
    Fixed = 0
    WouldFix = 0
    Unresolved = @()
}

foreach ($mdFile in $mdFiles) {
    # Ensure every markdown file has a top anchor below its H1 (canonical placement)
    Set-TopAnchor -File $mdFile

    $content = Get-Content $mdFile.FullName -Raw
    $matches = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
    $fileModified = $false
    
    foreach ($match in $matches) {
        $fullMatch = $match.Value
        $linkText = $match.Groups[1].Value
        $linkPath = $match.Groups[2].Value
        $originalPath = $linkPath
        
        if ($linkPath -match '^https?://') { continue }
        if ($linkPath -match '^mailto:') { continue }
        
        # Same-file anchor links need no file path changes
        if ($linkPath -match '^\#') { continue }

        # Normalize backslash paths to forward slash (markdown requires /)
        $linkPath = $linkPath -replace '\\', '/'
        $pathChanged = ($linkPath -ne $originalPath)
        
        # Compute the correct anchor for this link
        $hasOriginalAnchor = ($linkPath -match '#(.+)$')
        if ($hasOriginalAnchor) {
            $lineSuffix = '#' + $Matches[1]
        } elseif ($linkPath -match '\.md') {
            $lineSuffix = '#top'
        } else {
            $lineSuffix = ''
        }
        
        $targetFile = $linkPath -replace '#.*$', ''
        $targetFilename = [System.IO.Path]::GetFileName($targetFile)
        
        $sourceDir = Split-Path $mdFile.FullName -Parent
        if ($linkPath -match '^/') {
            $resolvedPath = Join-Path $RepoRoot $targetFile.TrimStart('/')
        } else {
            $resolvedPath = Join-Path $sourceDir $targetFile
        }
        if (-not (Test-Path $resolvedPath)) {
            $results.Invalid++
            $sourceRelative = $mdFile.FullName.Replace($RepoRoot, '').TrimStart('/')
            Write-Status $Red "BROKEN: '$originalPath' in $sourceRelative"
            
            $newPath = Find-TargetFile -TargetFilename $targetFilename
            
            if ($newPath) {
                Write-Status $Yellow "  FOUND: $targetFilename at $newPath"
                
                $newRelative = Get-RelativeLink -SourceFile $mdFile.FullName -TargetPath $newPath
                $replacement = "[$linkText]($newRelative$lineSuffix)"
                
 if ($WhatIf) {
     Write-Status $Yellow "  WOULD REPLACE: '$fullMatch' -> '$replacement'"
     $results.WouldFix++
 } else {
     $content = $content.Replace($fullMatch, $replacement)
     $fileModified = $true
     $results.Fixed++
     Write-Status $Green "  FIXED: '$originalPath' -> '$newRelative$lineSuffix'"
 }
            } else {
                Write-Status $Red "  MISSING: $targetFilename not found in repository"
                $results.Unresolved += @{
                    SourceFile = $mdFile.FullName
                    LinkPath = $originalPath
                    TargetFilename = $targetFilename
                }
            }
        } else {
            if ($pathChanged -or ($lineSuffix -and -not $hasOriginalAnchor)) {
                $replacement = "[$linkText]($linkPath$lineSuffix)"
                if ($WhatIf) {
                    $label = if ($pathChanged) { 'NORMALIZED' } else { 'ANCHORED' }
                    Write-Status $Yellow "  $label`: '$originalPath' -> '$linkPath$lineSuffix' in $($mdFile.FullName.Replace($RepoRoot, '').TrimStart('/'))"
                    $results.WouldFix++
                } else {
                    $content = $content.Replace($fullMatch, $replacement)
                    $fileModified = $true
                    $results.Fixed++
                    $label = if ($pathChanged) { 'NORMALIZED' } else { 'ANCHORED' }
                    $sourceRelative = $mdFile.FullName.Replace($RepoRoot, '').TrimStart('/')
                    Write-Status $Yellow "  $label`: '$originalPath' -> '$linkPath$lineSuffix' in $sourceRelative"
                }
            } else {
                $results.Valid++
            }
        }
    }
    
    if ($fileModified -and -not $WhatIf) {
        Set-Content -Path $mdFile.FullName -Value $content -Encoding UTF8
    }
}

Write-Output ""
Write-Status $Green "=== Link Validation Summary ==="
Write-Status $Cyan "Valid links: $($results.Valid)"
Write-Status $Yellow "Invalid links: $($results.Invalid)"
if ($WhatIf) {
    Write-Status $Yellow "Would fix: $($results.WouldFix)"
} else {
    Write-Status $Green "Fixed links: $($results.Fixed)"
}
Write-Status $Cyan "Log file: $LogFile"

if ($results.Unresolved.Count -gt 0) {
    Write-Output ""
    Write-Status $Red "=== Unresolved Files (could not be found) ==="
    foreach ($item in $results.Unresolved) {
        $unresolvedSourceRelative = $item.SourceFile.Replace($RepoRoot, '').TrimStart('/')
        Write-Status $Red "  File: $($item.TargetFilename)"
        Write-Status $Red "    Found in: $unresolvedSourceRelative"
        Write-Status $Red "    Link path: $($item.LinkPath)"
    }
}


