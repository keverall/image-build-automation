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

.PARAMETER Reason
    Reason for full testing rerun (Automation section 7).

.PARAMETER CommandSuite
    Command/Suite executed (Automation section 7).

.PARAMETER Environment
    Environment where tests ran (Automation section 7).

.PARAMETER NonInteractive
    Skip interactive prompts and use defaults/parameters only.

.PARAMETER OneViewStatusSummary
    New OneView status/progress summary bullet text (replaces existing).

.PARAMETER AddOneViewRow
    Add a new Phase 11 execution evidence row to OneView test plan.

.PARAMETER OvPhases
    Phase(s) for new OneView row (default: "Phases 1-10").

.PARAMETER OvTester
    Tester name for new OneView row (default: "<tester>").

.PARAMETER OvAppliance
    Appliance name for new OneView row (default: "HPEOpenview.1000").

.PARAMETER OvResult
    Result for new OneView row (default: "Pending").

.PARAMETER OvLogRef
    Log/Job reference for new OneView row (default: "<log ref>").

.PARAMETER OvSignedOff
    Signed off by for new OneView row (default: "<delivery lead>").

.PARAMETER ReportsDir
    Output directory for generated HTML reports (default: docs/Automation/Testing_Reports).

.PARAMETER SkipHtml
    Skip HTML regeneration (used by tests to keep runs hermetic).

.EXAMPLE
    ./scripts/Update-TestProgress.ps1
    Prompts for test run details and updates both test plans.

.EXAMPLE
    ./scripts/Update-TestProgress.ps1 -LogPath "generated/logs/automation/automated-mode-test_2026-07-22T22-04-27Z.log"
    Uses specific log file.

.EXAMPLE
    ./scripts/Update-TestProgress.ps1 -NonInteractive -Reason "CI run" -CommandSuite "make test" -Environment "GitLab CI"
    Non-interactive mode with explicit parameters.
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
    [switch]$NonInteractive,

    [Parameter()]
    [string]$OneViewStatusSummary,

    [Parameter()]
    [switch]$AddOneViewRow,

    [Parameter()]
    [string]$OvPhases,

    [Parameter()]
    [string]$OvTester,

    [Parameter()]
    [string]$OvAppliance,

    [Parameter()]
    [string]$OvResult,

    [Parameter()]
    [string]$OvLogRef,

    [Parameter()]
    [string]$OvSignedOff,

    [Parameter()]
    [string]$ReportsDir = "docs/Automation/Testing_Reports",

    [Parameter()]
    [switch]$SkipHtml
)

$ErrorActionPreference = 'Stop'

# Pure, testable string-transformation helpers.
. (Join-Path $PSScriptRoot 'TestProgress.Common.ps1')

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
        Write-Error "No test log found in $logDir"
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
$summary = Get-TestResultFromLog -LogContent $logContent
$totalTests = $summary.Total
$passedTests = $summary.Passed
$failedTests = $summary.Failed
$skippedTests = $summary.Skipped
$duration = $summary.Duration
$result = $summary.Result

if ($summary.Parsed) {
    Write-Host "[test-progress] Test Summary:" -ForegroundColor Green
    Write-Host "  Total: $totalTests | Passed: $passedTests | Failed: $failedTests | Skipped: $skippedTests | Duration: $duration"
} else {
    Write-Warning "Could not parse test summary from log. Using fallback values."
}

# Get current date and time
$testDate = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$runDate = [DateTime]::UtcNow.ToString('dd/MM/yyyy HH:mm')

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

# OneView prompts
if (-not $OneViewStatusSummary) {
    if (-not $NonInteractive) {
        Write-Host "`nNew OneView status/progress summary (leave blank to keep current): " -ForegroundColor Yellow -NoNewline
        $OneViewStatusSummary = [System.Console]::ReadLine()
    }
}

$addOvRow = $false
if ($AddOneViewRow) {
    $addOvRow = $true
} elseif (-not $NonInteractive) {
    Write-Host "Add a new OneView Phase 11 execution row? (y/N): " -ForegroundColor Yellow -NoNewline
    $answer = [System.Console]::ReadLine()
    $addOvRow = $answer -match '^[Yy]'
}

if ($addOvRow) {
    if (-not $OvPhases) {
        if ($NonInteractive) {
            $OvPhases = "Phases 1-10"
        } else {
            Write-Host "Phase(s) (default: 'Phases 1-10'): " -ForegroundColor Yellow -NoNewline
            $OvPhases = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvPhases)) {
                $OvPhases = "Phases 1-10"
            }
        }
    }
    
    if (-not $OvTester) {
        if ($NonInteractive) {
            $OvTester = "<tester>"
        } else {
            Write-Host "Tester (default: '<tester>'): " -ForegroundColor Yellow -NoNewline
            $OvTester = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvTester)) {
                $OvTester = "<tester>"
            }
        }
    }
    
    if (-not $OvAppliance) {
        if ($NonInteractive) {
            $OvAppliance = "HPEOpenview.1000"
        } else {
            Write-Host "Appliance (default: 'HPEOpenview.1000'): " -ForegroundColor Yellow -NoNewline
            $OvAppliance = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvAppliance)) {
                $OvAppliance = "HPEOpenview.1000"
            }
        }
    }
    
    if (-not $OvResult) {
        if ($NonInteractive) {
            $OvResult = "Pending"
        } else {
            Write-Host "Result (default: 'Pending'): " -ForegroundColor Yellow -NoNewline
            $OvResult = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvResult)) {
                $OvResult = "Pending"
            }
        }
    }
    
    if (-not $OvLogRef) {
        if ($NonInteractive) {
            $OvLogRef = "<log ref>"
        } else {
            Write-Host "Log/Job Ref (default: '<log ref>'): " -ForegroundColor Yellow -NoNewline
            $OvLogRef = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvLogRef)) {
                $OvLogRef = "<log ref>"
            }
        }
    }
    
    if (-not $OvSignedOff) {
        if ($NonInteractive) {
            $OvSignedOff = "<delivery lead>"
        } else {
            Write-Host "Signed off by (default: '<delivery lead>'): " -ForegroundColor Yellow -NoNewline
            $OvSignedOff = [System.Console]::ReadLine()
            if ([string]::IsNullOrWhiteSpace($OvSignedOff)) {
                $OvSignedOff = "<delivery lead>"
            }
        }
    }
}

# Read current test plan
if (-not (Test-Path $TestPlanPath)) {
    Write-Error "Test plan not found: $TestPlanPath"
    exit 1
}

$content = Get-Content $TestPlanPath -Raw

# Update run-date
$content = Update-RunDateBlock -Content $content -RunDate $runDate

# Update section-7 rows
if ($null -ne (Get-Block -Content $content -Key 'automation-evidence-rows')) {
    $auto = Add-AutomationEvidenceRow -Content $content -DateTime $testDate `
        -CommandSuite $CommandSuite -Environment $Environment -Result $result `
        -LogRef $logRef -Reason $Reason
    $content = $auto.Content

    Set-Content -Path $TestPlanPath -Value $content -NoNewline
    Write-Host "[test-progress] Updated $TestPlanPath with run #$($auto.RunNumber)" -ForegroundColor Green
} else {
    Write-Warning "Could not find automation-evidence-rows block in $TestPlanPath"
    Write-Host "Table pattern may have changed. Manual update required." -ForegroundColor Yellow
}

# Update ONEVIEW_TEST_PLAN.md (Phase 11 table)
if (Test-Path $OneViewTestPlanPath) {
    Write-Host "[test-progress] Updating $OneViewTestPlanPath..." -ForegroundColor Cyan

    $oneViewContent = Get-Content $OneViewTestPlanPath -Raw

    # Update run-date
    $oneViewContent = Update-RunDateBlock -Content $oneViewContent -RunDate $runDate

    # Update summary bullet (only when replacement text supplied)
    if (-not [string]::IsNullOrWhiteSpace($OneViewStatusSummary)) {
        $oneViewContent = Set-OneViewStatusSummary -Content $oneViewContent -SummaryText $OneViewStatusSummary
        Write-Host "[test-progress] Updated OneView status summary" -ForegroundColor Green
    }

    # Update Phase 11 rows (always refresh last row's date; optionally add a row)
    if ($null -ne (Get-Block -Content $oneViewContent -Key 'phase11-rows')) {
        $phase11 = Update-Phase11Block -Content $oneViewContent -DateTime $runDate `
            -AddRow:$addOvRow -Phases $OvPhases -Tester $OvTester -Appliance $OvAppliance `
            -Result $OvResult -LogRef $OvLogRef -SignedOff $OvSignedOff
        $oneViewContent = $phase11.Content

        if ($phase11.Added) {
            Write-Host "[test-progress] Added OneView Phase 11 row #$($phase11.RunNumber)" -ForegroundColor Green
        }

        Set-Content -Path $OneViewTestPlanPath -Value $oneViewContent -NoNewline
        Write-Host "[test-progress] Updated $OneViewTestPlanPath" -ForegroundColor Green
    } else {
        Write-Warning "Could not find phase11-rows block in $OneViewTestPlanPath"
    }
}

# Regenerate HTML files with timestamp suffix
if ($SkipHtml) {
    Write-Host "`n[test-progress] -SkipHtml supplied; skipping HTML regeneration." -ForegroundColor Yellow
    Write-Host "`n[test-progress] Test progress update complete!" -ForegroundColor Green
    Write-Host "Please review the updated test plans and commit the changes." -ForegroundColor Cyan
    return
}

Write-Host "`n[test-progress] Regenerating HTML files..." -ForegroundColor Cyan

$converterScript = "scripts/MD_to_HTML_Converter.py"
$reportsDir = $ReportsDir

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
