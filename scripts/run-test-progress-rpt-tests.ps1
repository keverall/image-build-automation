#!/usr/bin/env pwsh
# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Test Progress Report Tests
# =============================================================================
# Runs Pester tests covering the test-plan progress generator:
# - TestProgress.Common.ps1 (pure string-transformation helpers)
# - Update-TestProgress.ps1 (end-to-end script tests)
# - MD_to_HTML_Converter.py (HTML comment stripping)

<#
.SYNOPSIS
    Run test progress report generator tests.

.DESCRIPTION
    Executes Pester tests for the test-plan progress update pipeline:
    - Update-TestProgress.Unit.Tests.ps1 (all helper functions + E2E + HTML)

    Displays detailed test summary with pass/fail/skip counts and duration.
    Logs detailed output to generated/logs/testing/test_progress_rpt_tests_*.log

    Exits with code 1 if any tests fail.

.EXAMPLE
    pwsh -File scripts/run-test-progress-rpt-tests.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "test_progress_rpt_tests_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running test progress report generator tests..." -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $testPath 'Update-TestProgress.Unit.Tests.ps1')
)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = 'Auto'

if ($PSVersionTable.PSVersion.Major -ge 7) { $PSStyle.OutputRendering = 'Ansi' }

Start-Transcript -Path $pesterLogPath -Append:$false | Out-Null
try {
    $results = Invoke-Pester -Configuration $config
}
finally {
    Stop-Transcript | Out-Null
}

# Jest/Pytest-style summary block
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                           TEST SUMMARY BLOCK                                   " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Total Tests   : $($results.TotalCount)" -ForegroundColor White
Write-Output " Passed        : $($results.PassedCount) " -NoNewline
if ($results.PassedCount -eq $results.TotalCount) { Write-Host "✔" -ForegroundColor Green } else { Write-Host "✔" -ForegroundColor Green }

if ($results.FailedCount -gt 0) {
    Write-Output " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "✖ (CRITICAL)" -ForegroundColor Red
} else {
    Write-Output " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "✔" -ForegroundColor Green
}

Write-Host " Skipped       : $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host " Duration      : $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# Persist the summary to the log file
$summaryLines = @(
    '',
    '================================================================================',
    '                           TEST SUMMARY BLOCK',
    '================================================================================',
    " Total Tests   : $($results.TotalCount)",
    " Passed        : $($results.PassedCount)",
    " Failed        : $($results.FailedCount)$(if ($results.FailedCount -gt 0) { ' (CRITICAL)' } else { '' })",
    " Skipped       : $($results.SkippedCount)",
    " Duration      : $($results.Duration.TotalSeconds.ToString('0.00'))s",
    '================================================================================'
)
Add-Content -Path $pesterLogPath -Value $summaryLines -Encoding utf8

exit ([int]($results.FailedCount -gt 0))
