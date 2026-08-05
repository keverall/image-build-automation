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
    Appliance name for new OneView row (default: "va-oneviewt-ap").

.PARAMETER OvResult
    Result for new OneView row (default: "Pending").

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
    [switch]$AddAutomationRow,

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
    [string]$ReportsDir = "docs/Automation/Testing_Reports",

    [Parameter()]
    [switch]$SkipHtml
)

$ErrorActionPreference = 'Stop'

# Pure, testable string-transformation helpers.
. (Join-Path $PSScriptRoot 'TestProgress.Common.ps1')

function _PromptOrDefault {
    <#
    .SYNOPSIS
        Resolve a script parameter interactively: keep the supplied value when
        set; otherwise prompt (or fall back to the default in NonInteractive
        mode). Blank/whitespace input accepts the default.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$CurrentValue,
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Default,
        [switch]$NonInteractive
    )
    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) { return $CurrentValue }
    if ($NonInteractive) { return $Default }
    Write-Host "$Prompt (default: '$Default'): " -ForegroundColor Yellow -NoNewline
    $val = [System.Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val
}

# Find latest log if not specified
if (-not $LogPath) {
    $logDir = "generated/logs/automation"
    if (-not (Test-Path $logDir)) {
        Write-Error "Log directory not found: $logDir"
        exit 1
    }
    
    $latestLog = Get-ChildItem -Path $logDir -Filter "automated-mode-test_*.log" |
        Sort-Object Name -Descending |
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

# Get current date and time. All timestamps are UTC and marked as UTC so the
# top run-date, the section-7 evidence rows, and the OneView phase-11 rows
# stay consistent (no local/UTC drift).
$testDate = [DateTime]::UtcNow.ToString('dd/MM/yyyy HH:mm:ss') + ' UTC'
$runDate = [DateTime]::UtcNow.ToString('dd/MM/yyyy HH:mm') + ' UTC'

# Prompt for test run details (or use parameters if provided)
Write-Host "`n[test-progress] Please provide details for the test run record:" -ForegroundColor Yellow

$Reason = _PromptOrDefault -CurrentValue $Reason `
    -Prompt "Reason for full testing rerun (e.g., 'Fixed logging issues and OneView connectivity')" `
    -Default 'Regular test execution' -NonInteractive:$NonInteractive

$defaultCommandSuite = "Full Automation suite — ``make automation-mode-tests`` (all $totalTests automated regression unit test scenarios above)"
$CommandSuite = _PromptOrDefault -CurrentValue $CommandSuite `
    -Prompt 'Command/Suite executed' -Default $defaultCommandSuite -NonInteractive:$NonInteractive

$Environment = _PromptOrDefault -CurrentValue $Environment `
    -Prompt 'Environment' -Default 'Ran manually on terminal' -NonInteractive:$NonInteractive

$addAutoRow = $false
if ($AddAutomationRow) {
    $addAutoRow = $true
} elseif (-not $NonInteractive) {
    Write-Host "Add a new Automation section 7 execution row? (y/N): " -ForegroundColor Yellow -NoNewline
    $answer = [System.Console]::ReadLine()
    $addAutoRow = $answer -match '^[Yy]'
}

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
    $OvPhases = _PromptOrDefault -CurrentValue $OvPhases `
        -Prompt 'Phase(s)' -Default 'Phases 1-10' -NonInteractive:$NonInteractive

    $OvTester = _PromptOrDefault -CurrentValue $OvTester `
        -Prompt 'Tester' -Default '' -NonInteractive:$NonInteractive

    $OvAppliance = _PromptOrDefault -CurrentValue $OvAppliance `
        -Prompt 'Appliance' -Default 'va-oneviewt-ap' -NonInteractive:$NonInteractive

    $OvResult = _PromptOrDefault -CurrentValue $OvResult `
        -Prompt 'Result' -Default 'Pending' -NonInteractive:$NonInteractive
}

# Read current test plan
if (-not (Test-Path $TestPlanPath)) {
    Write-Error "Test plan not found: $TestPlanPath"
    exit 1
}

$content = Get-Content $TestPlanPath -Raw

# Repair any accidentally duplicated marker lines before editing blocks
$content = Repair-DuplicateBlockMarker -Content $content

# Update run-date
$content = Update-RunDateBlock -Content $content -RunDate $runDate

# Update section-7 rows
if ($null -ne (Get-Block -Content $content -Key 'automation-evidence-rows')) {
    $auto = Update-AutomationEvidenceBlock -Content $content -DateTime $testDate `
        -AddRow:$addAutoRow -CommandSuite $CommandSuite -Environment $Environment `
        -Result $result -Reason $Reason
    $content = $auto.Content

    Set-Content -Path $TestPlanPath -Value $content -NoNewline
    if ($auto.Added) {
        Write-Host "[test-progress] Added Automation section 7 row #$($auto.RunNumber)" -ForegroundColor Green
    } else {
        Write-Host "[test-progress] Updated Automation section 7 last row date" -ForegroundColor Green
    }
} else {
    Write-Warning "Could not find automation-evidence-rows block in $TestPlanPath"
    Write-Host "Table pattern may have changed. Manual update required." -ForegroundColor Yellow
}

# Update ONEVIEW_TEST_PLAN.md (Phase 11 table)
if (Test-Path $OneViewTestPlanPath) {
    Write-Host "[test-progress] Updating $OneViewTestPlanPath..." -ForegroundColor Cyan

    $oneViewContent = Get-Content $OneViewTestPlanPath -Raw

    # Repair any accidentally duplicated marker lines before editing blocks
    $oneViewContent = Repair-DuplicateBlockMarker -Content $oneViewContent

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
            -Result $OvResult
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
