#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Updates test plan documents with today's test execution progress.

.DESCRIPTION
    Extracts test summary from the latest automation test log, prompts for
    test run details, and updates the Execution Evidence tables in both
    AUTOMATION_TEST_PLAN.md and ONEVIEW_TEST_PLAN.md. Then regenerates HTML.

.PARAMETER LogPath
    Path to the test log file. If not specified, uses the latest log.

.PARAMETER TestPlanPath
    Path to AUTOMATION_TEST_PLAN.md. Defaults to docs/Automation/AUTOMATION_TEST_PLAN.md.

.PARAMETER OneViewTestPlanPath
    Path to ONEVIEW_TEST_PLAN.md. Defaults to docs/Automation/ONEVIEW_TEST_PLAN.md.

.EXAMPLE
    ./scripts/Update-TestProgress.ps1
    Prompts for test run details and updates both test plans.

.EXAMPLE
    ./scripts/Update-TestProgress.ps1 -LogPath "generated/logs/automation/automated-mode-test_2026-07-22T22-04-27Z.log"
    Uses specific log file.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [string]$TestPlanPath = "docs/Automation/AUTOMATION_TEST_PLAN.md",

    [Parameter()]
    [string]$OneViewTestPlanPath = "docs/Automation/ONEVIEW_TEST_PLAN.md",

    [Parameter()]
    [string]$Reason,

    [Parameter()]
    [string]$CommandSuite,

    [Parameter()]
    [string]$Environment,

    [Parameter()]
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

# Find latest log if not specified
if (-not $LogPath) {
    $logDir = "generated/logs/automation"
    if (-not (Test-Path $logDir)) {
        Write-Error "Log directory not found: $logDir"
        exit 1
    }
    
    $latestLog = Get-ChildItem -Path $logDir -Filter "automated-mode-test_*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    
    if (-not $latestLog) {
        Write-Error "No test logs found in $logDir"
        exit 1
    }
    
    $LogPath = $latestLog.FullName
    Write-Host "[test-progress] Using latest log: $($latestLog.Name)" -ForegroundColor Cyan
}

if (-not (Test-Path $LogPath)) {
    Write-Error "Log file not found: $LogPath"
    exit 1
}

# Extract test summary from log
Write-Host "[test-progress] Extracting test summary from log..." -ForegroundColor Cyan
$logContent = Get-Content $LogPath -Raw

# Parse the TEST SUMMARY BLOCK
if ($logContent -match 'TEST SUMMARY BLOCK[\s\S]*?Total Tests\s*:\s*(\d+)[\s\S]*?Passed\s*:\s*(\d+)[\s\S]*?Failed\s*:\s*(\d+)[\s\S]*?Skipped\s*:\s*(\d+)[\s\S]*?Duration\s*:\s*([\d.]+s)') {
    $totalTests = $Matches[1]
    $passedTests = $Matches[2]
    $failedTests = $Matches[3]
    $skippedTests = $Matches[4]
    $duration = $Matches[5]
    
    Write-Host "[test-progress] Test Summary:" -ForegroundColor Green
    Write-Host "  Total: $totalTests | Passed: $passedTests | Failed: $failedTests | Skipped: $skippedTests | Duration: $duration"
} else {
    Write-Warning "Could not parse test summary from log. Using fallback values."
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    $skippedTests = 0
    $duration = "N/A"
}

# Determine result
if ([int]$failedTests -eq 0 -and [int]$passedTests -eq [int]$totalTests) {
    $result = "Passed ($passedTests/$totalTests)"
} else {
    $result = "Failed ($passedTests/$totalTests passed, $failedTests failed)"
}

# Get current date and time
$testDate = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

# Prompt for test run details (or use parameters if provided)
Write-Host "`n[test-progress] Please provide details for the test run record:" -ForegroundColor Yellow

if (-not $Reason) {
    if ($NonInteractive) {
        $Reason = "Regular test execution"
    } else {
        Write-Host "Reason for full testing rerun (e.g., 'Fixed logging issues and OneView connectivity'): " -ForegroundColor Yellow -NoNewline
        $Reason = [System.Console]::ReadLine()
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = "Regular test execution"
        }
    }
}

if (-not $CommandSuite) {
    if ($NonInteractive) {
        $CommandSuite = "Full Automation suite — ``make test`` + ``make automation-mode-tests`` (all $totalTests automated regression unit test scenarios above)"
    } else {
        Write-Host "Command/Suite executed (default: 'Full Automation suite — make test + make automation-mode-tests'): " -ForegroundColor Yellow -NoNewline
        $CommandSuite = [System.Console]::ReadLine()
        if ([string]::IsNullOrWhiteSpace($CommandSuite)) {
            $CommandSuite = "Full Automation suite — ``make test`` + ``make automation-mode-tests`` (all $totalTests automated regression unit test scenarios above)"
        }
    }
}

if (-not $Environment) {
    if ($NonInteractive) {
        $Environment = "Ran manually on terminal"
    } else {
        Write-Host "Environment (default: 'Ran manually on terminal'): " -ForegroundColor Yellow -NoNewline
        $Environment = [System.Console]::ReadLine()
        if ([string]::IsNullOrWhiteSpace($Environment)) {
            $Environment = "Ran manually on terminal"
        }
    }
}

$logRef = "see run log below"

# Read current test plan
if (-not (Test-Path $TestPlanPath)) {
    Write-Error "Test plan not found: $TestPlanPath"
    exit 1
}

$testPlanContent = Get-Content $TestPlanPath -Raw

# Find the Execution Evidence table
# Pattern: | Run # | Date/Time | ... | Reason for full testing rerun |
# Use flexible separator pattern that matches any number of dashes
$pattern = '(?s)(\| Run # \| Date/Time \| Command / Suite \| Environment \| Result \| CI Job / Log Ref \| Reason for full testing rerun \|[\s\S]*?\|[-]+\|[-]+\|[-]+\|[-]+\|[-]+\|[-]+\|[-]+\|)([\s\S]*?)(\n\n|\n<a name="run-log">)'

if ($testPlanContent -match $pattern) {
    $tableHeader = $Matches[1]
    $existingRows = $Matches[2]
    $afterTable = $Matches[3]
    
    # Count existing rows to determine next run number
    $rowMatches = [regex]::Matches($existingRows, '\|\s*(\d+)\s*\|')
    $nextRunNumber = 1
    if ($rowMatches.Count -gt 0) {
        $lastRunNumber = [int]($rowMatches | Select-Object -Last 1).Groups[1].Value
        $nextRunNumber = $lastRunNumber + 1
    }
    
    # Create new row
    $newRow = "| $nextRunNumber | $testDate | $CommandSuite | $Environment | $result | $logRef | $Reason |`n"
    
    # Insert new row
    $updatedRows = $existingRows.TrimEnd() + "`n$newRow"
    $updatedContent = $testPlanContent -replace $pattern, "$tableHeader$updatedRows$afterTable"
    
    # Write updated test plan
    Set-Content -Path $TestPlanPath -Value $updatedContent -NoNewline
    Write-Host "[test-progress] Updated $TestPlanPath with run #$nextRunNumber" -ForegroundColor Green
} else {
    Write-Warning "Could not find Execution Evidence table in $TestPlanPath"
    Write-Host "Table pattern may have changed. Manual update required." -ForegroundColor Yellow
}

# Update ONEVIEW_TEST_PLAN.md (Phase 11 table)
if (Test-Path $OneViewTestPlanPath) {
    Write-Host "[test-progress] Updating $OneViewTestPlanPath..." -ForegroundColor Cyan
    
    $oneViewContent = Get-Content $OneViewTestPlanPath -Raw
    
    # Find Phase 11 table
    $ovPattern = '(?s)(\| Run # \| Date/Time \| Phase\(s\) \| Tester \| Appliance \| Result \| Log/Job Ref \| Signed off \|[\s\S]*?\|---\|---\|---\|---\|---\|---\|---\|---\|)([\s\S]*?)(\n\n|\n<a name="phase-12)'
    
    if ($oneViewContent -match $ovPattern) {
        $ovHeader = $Matches[1]
        $ovExistingRows = $Matches[2]
        $ovAfterTable = $Matches[3]
        
        # For OneView test plan, we'll add a placeholder row since live tests haven't run yet
        # Only add if table is empty (just header)
        if ($ovExistingRows.Trim() -eq '|' -or $ovExistingRows.Trim() -eq '') {
            $ovNewRow = "| 1 | $testDate | Phases 1-10 (pending) | <tester> | HPEOpenview.1000 | Pending | <log ref> | <delivery lead> |`n"
            $ovUpdatedRows = $ovNewRow
            $ovUpdatedContent = $oneViewContent -replace $ovPattern, "$ovHeader$ovUpdatedRows$ovAfterTable"
            
            Set-Content -Path $OneViewTestPlanPath -Value $ovUpdatedContent -NoNewline
            Write-Host "[test-progress] Updated $OneViewTestPlanPath" -ForegroundColor Green
        } else {
            Write-Host "[test-progress] OneView test plan already has execution evidence. Skipping update." -ForegroundColor Yellow
        }
    } else {
        Write-Warning "Could not find Phase 11 table in $OneViewTestPlanPath"
    }
}

# Regenerate HTML files with timestamp suffix
Write-Host "`n[test-progress] Regenerating HTML files..." -ForegroundColor Cyan

$converterScript = "scripts/MD_to_HTML_Converter.py"
$reportsDir = "docs/Automation/Testing_Reports"

# Ensure reports directory exists
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
    Write-Host "[test-progress] Created reports directory: $reportsDir" -ForegroundColor Cyan
}

# Generate ISO timestamp (same format as logging: yyyy-MM-ddTHH-mm-ssZ)
$timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ssZ')

if (-not (Test-Path $converterScript)) {
    Write-Warning "HTML converter not found: $converterScript"
    Write-Host "Skipping HTML generation. Run manually with:" -ForegroundColor Yellow
    Write-Host "  python3 scripts/MD_to_HTML_Converter.py $TestPlanPath $reportsDir/AUTOMATION_TEST_PLAN_$timestamp.html"
    Write-Host "  python3 scripts/MD_to_HTML_Converter.py $OneViewTestPlanPath $reportsDir/ONEVIEW_TEST_PLAN_$timestamp.html"
} else {
    try {
        $automationHtml = "$reportsDir/AUTOMATION_TEST_PLAN_$timestamp.html"
        $oneviewHtml = "$reportsDir/ONEVIEW_TEST_PLAN_$timestamp.html"
        
        python3 $converterScript $TestPlanPath $automationHtml
        python3 $converterScript $OneViewTestPlanPath $oneviewHtml
        
        Write-Host "[test-progress] HTML files generated with timestamp $timestamp" -ForegroundColor Green
        Write-Host "  - $automationHtml" -ForegroundColor Gray
        Write-Host "  - $oneviewHtml" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to regenerate HTML: $_"
        Write-Host "You can regenerate manually with:" -ForegroundColor Yellow
        Write-Host "  python3 scripts/MD_to_HTML_Converter.py $TestPlanPath $reportsDir/AUTOMATION_TEST_PLAN_$timestamp.html"
        Write-Host "  python3 scripts/MD_to_HTML_Converter.py $OneViewTestPlanPath $reportsDir/ONEVIEW_TEST_PLAN_$timestamp.html"
    }
}

Write-Host "`n[test-progress] Test progress update complete!" -ForegroundColor Green
Write-Host "Please review the updated test plans and commit the changes." -ForegroundColor Cyan
