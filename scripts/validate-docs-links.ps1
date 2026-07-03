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

# Colors for output
$Green = "`e[0;32m"
$Yellow = "`e[1;33m"
$Red = "`e[0;31m"
$Cyan = "`e[0;36m"
$Reset = "`e[0m"

$RepoRoot = Split-Path -Parent $PSScriptRoot

# Setup logging
$LogTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogDir = Join-Path $RepoRoot "generated/logs/fix-docs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "fix-docs-$LogTimestamp.log"

function Write-Status {
    param([string]$Color, [string]$Message)
    # Strip ANSI codes for log file
    $cleanMessage = $Message -replace '\x1b\[[0-9;]*m', ''
    # Write to terminal with color
    Write-Host "${Color}${Message}${Reset}"
    # Write to log file without colors
    $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $cleanMessage"
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

# Log script start
Add-Content -Path $LogFile -Value "=== Fix Docs Log Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -Encoding UTF8

function Find-TargetFile {
    param([string]$TargetFilename)
    $files = Get-ChildItem -Path $RepoRoot -Filter $TargetFilename -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\.git|generated/' }
    
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
    param([string]$SourceFile, [string]$TargetPath)
    $sourceDir = Split-Path $SourceFile -Parent
    $sourceRelative = $sourceDir.Replace($RepoRoot, '').TrimStart('/')
    $depth = ($sourceRelative -split '/').Where({ $_ -ne '' }).Count
    
    $relPath = ''
    for ($i = 0; $i -lt $depth; $i++) { $relPath += '../' }
    $relPath += $TargetPath.TrimStart('/')
    $relPath = $relPath -replace '/+', '/'
    return $relPath
}

function Get-MarkdownFiles {
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
    return $files | Where-Object { $_.FullName -notmatch '\.git' }
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
    $content = Get-Content $mdFile.FullName -Raw
    $matches = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
    $fileModified = $false
    
    foreach ($match in $matches) {
        $fullMatch = $match.Value
        $linkText = $match.Groups[1].Value
        $linkPath = $match.Groups[2].Value
        
        if ($linkPath -match '^https?://') { continue }
        if ($linkPath -notmatch '^\.\./') { continue }
        
        $targetFile = $linkPath -replace '#.*$', ''
        $targetFilename = [System.IO.Path]::GetFileName($targetFile)
        
        $sourceDir = Split-Path $mdFile.FullName -Parent
        $resolvedPath = Join-Path $sourceDir $targetFile
        if (-not (Test-Path $resolvedPath)) {
            $results.Invalid++
            Write-Status $Red "BROKEN: '$linkPath' in $(Split-Path $mdFile.FullName -Leaf)"
            
            $newPath = Find-TargetFile -TargetFilename $targetFilename
            
            if ($newPath) {
                Write-Status $Yellow "  FOUND: $targetFilename at $newPath"
                
                $lineSuffix = ''
                if ($linkPath -match '#(.+)$') {
                    $lineSuffix = '#' + $Matches[1]
                }
                
                $newRelative = Get-RelativeLink -SourceFile $mdFile.FullName -TargetPath $newPath
                $replacement = "[$linkText]($newRelative$lineSuffix)"
                
if ($WhatIf) {
    Write-Status $Yellow "  WOULD REPLACE: '$fullMatch' -> '$replacement'"
    $results.WouldFix++
} else {
    $content = $content.Replace($fullMatch, $replacement)
    $fileModified = $true
    $results.Fixed++
    Write-Status $Green "  FIXED: Link updated to $newRelative$lineSuffix"
}
            } else {
                Write-Status $Red "  MISSING: $targetFilename not found in repository"
                $results.Unresolved += @{
                    SourceFile = $mdFile.FullName
                    LinkPath = $linkPath
                    TargetFilename = $targetFilename
                }
            }
        } else {
            $results.Valid++
        }
    }
    
    if ($fileModified -and -not $WhatIf) {
        Set-Content -Path $mdFile.FullName -Value $content -Encoding UTF8
    }
}

Write-Host ""
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
    Write-Host ""
    Write-Status $Red "=== Unresolved Files (could not be found) ==="
    foreach ($item in $results.Unresolved) {
        Write-Status $Red "  File: $($item.TargetFilename)"
        Write-Status $Red "    Found in: $(Split-Path $item.SourceFile -Leaf)"
        Write-Status $Red "    Link path: $($item.LinkPath)"
    }
}


