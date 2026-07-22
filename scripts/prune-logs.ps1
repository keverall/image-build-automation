# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Log Pruning
# =============================================================================
# Prunes log files in the generated/logs directory that are older than a
# specified standard age.

<#
.SYNOPSIS
    Prune old log files to maintain maximum count per type.

.DESCRIPTION
    Scans generated/logs and generated/output directories for log files.
    Groups logs by type (based on filename pattern) and removes excess files
    beyond the configured maximum (default: 10 per type).
    
    Also removes legacy redundant log files (pester-log.txt, pester.log).
    Skips coverage report files and .gitkeep files.

.PARAMETER MaxLogsToKeep
        Maximum number of log files to keep per type (default: 10)

.EXAMPLE
    pwsh -File scripts/prune-logs.ps1
    
.EXAMPLE
    ./scripts/prune-logs.ps1 -MaxLogsToKeep 5
#>

# Usage: pwsh -File scripts/prune-logs.ps1 [-DaysToKeep 30]
# =============================================================================

param(
    [int]$MaxLogsToKeep = 10
)

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

$searchDirs = @(
    (Join-Path $PROJECT_ROOT 'generated/logs'),
    (Join-Path $PROJECT_ROOT 'generated/output')
) | Where-Object { Test-Path $_ }

if ($searchDirs.Count -eq 0) {
    Write-Output "No generated logs or output directories found, nothing to prune."
    exit 0
}

Write-Host "[prune-logs] Pruning logs to keep maximum $MaxLogsToKeep per type..." -ForegroundColor Cyan

$count = 0

$legacyLogs = @()
foreach ($dir in $searchDirs) {
    $legacyLogs += Get-ChildItem -Path $dir -Recurse -File -Include pester-log.txt, pester.log -ErrorAction SilentlyContinue
}

$legacyLogs = $legacyLogs | Select-Object -Unique FullName

if ($null -ne $legacyLogs -and $legacyLogs.Count -gt 0) {
    foreach ($log in $legacyLogs) {
        if (Test-Path $log.FullName) {
            Remove-Item -Path $log.FullName -Force
            Write-Output "Removed legacy redundant log: $($log.FullName)"
            $count++
        }
    }
}

$allLogs = @()
foreach ($dir in $searchDirs) {
    $allLogs += Get-ChildItem -Path $dir -Recurse -File -Include *.log, *.json, *.txt -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.gitkeep' -and $_.Name -notmatch 'coverage-report' }
}

# De-duplicate by full path WITHOUT flattening the FileInfo objects: using
# Select-Object -Unique FullName would discard DirectoryName/Name, which the
# grouping below relies on. Sort-Object -Unique keeps the rich objects intact.
$allLogs = $allLogs | Sort-Object FullName -Unique

function Get-LogType ($filename) {
    # Reduce a log filename to its stable "prefix" (the command/test that owns
    # it) so every log belonging to the same command/test groups together and is
    # capped at MaxLogsToKeep. Log filenames look like:
    #   <Prefix>_<ISO-timestamp>_<LEVEL>.log      e.g. monitoring_2026-07-22T19-54-50Z_INFO
    #   <Prefix>_<ISO-timestamp>.log              e.g. automated-mode-test_2026-07-22T21-05-45Z
    #   <Prefix>_<epoch>.log / <Prefix>_<yyyyMMdd_HHmmss>.log
    # The level suffix and timestamp(s) must be removed wherever they appear, not
    # only when anchored at the end, otherwise level-suffixed per-command logs
    # each become a unique "prefix" and are never pruned.
    $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    $base = $base -replace '_(INFO|DEBUG|WARNING|ERROR)$', ''   # trailing level
    $base = $base -replace '_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z', '' # ISO timestamp
    $base = $base -replace '_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}', ''    # alt ISO
    $base = $base -replace '-\d{8}-\d{6}', ''                          # yyyymmdd-HHmmss
    $base = $base -replace '_\d{8}_\d{6}', ''                           # yyyymmdd_HHmmss
    $base = $base -replace '_\d{4}-\d{2}-\d{2}', ''                     # bare date
    $base = $base -replace '_\d{10,}', ''                               # UNIX epoch
    # Collapse separators left dangling by the removals above.
    $base = $base -replace '_+', '_' -replace '_$', '' -replace '^_', ''
    return $base
}

if ($null -ne $allLogs -and $allLogs.Count -gt 0) {
    $groupedLogs = $allLogs | Group-Object { $_.DirectoryName + "\" + (Get-LogType $_.Name) }

    foreach ($group in $groupedLogs) {
        $sorted = $group.Group | Sort-Object LastWriteTime -Descending
        
        if ($sorted.Count -gt $MaxLogsToKeep) {
            $toPrune = $sorted | Select-Object -Skip $MaxLogsToKeep
            foreach ($log in $toPrune) {
                if (Test-Path $log.FullName) {
                    Remove-Item -Path $log.FullName -Force
                    Write-Output "Removed excess log: $($log.FullName)"
                    $count++
                }
            }
        }
    }
}

Write-Host "[prune-logs] Pruned $count excess log files." -ForegroundColor Green
exit 0
