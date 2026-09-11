#!/usr/bin/env pwsh
# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Help Parameter Test Runner
# =============================================================================
# Runs the data-driven -Help tests for every command in
# scripts/HelpParamTests.txt (help output ownership, section structure, and
# no exceptions) with a Jest/Pytest-style summary block.

<#
.SYNOPSIS
    Run -Help parameter tests for every command in scripts/HelpParamTests.txt.

.DESCRIPTION
    Executes Pester tests covering the -Help switch on every listed command:
    - HelpParamTests.Unit.Tests.ps1 (all commands + matrix completeness guard)

    Displays detailed test summary with pass/fail/skip counts and duration.
    Logs detailed output to generated/logs/testing/help_param_tests_*.log

    Exits with code 1 if any tests fail.

.EXAMPLE
    pwsh -File scripts/run-help-param-tests.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Ensure a working Pester 6.0.1 (with Pester.dll) is available, then import it.
. (Join-Path $PSScriptRoot 'Ensure-Pester.ps1')

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "help_param_tests_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running -Help parameter tests..." -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $testPath 'HelpParamTests.Unit.Tests.ps1')
)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = 'Auto'

# Machine-readable test results for CI artifact collection (GitLab junit report).
# JUnitXml requires Pester 5.2+; fall back to NUnitXml on older 5.x.
$pesterVersion = (Get-Module Pester).Version
$junitPath = Join-Path $logDir "help_param_tests_junit_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').xml"
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = if ($pesterVersion -ge [version]'5.2.0') { 'JUnitXml' } else { 'NUnitXml' }
$config.TestResult.OutputPath = $junitPath

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
Write-Host " Passed        : $($results.PassedCount) " -NoNewline -ForegroundColor White
if ($results.PassedCount -eq $results.TotalCount) { Write-Host "✔" -ForegroundColor Green } else { Write-Host "✔" -ForegroundColor Green }

if ($results.FailedCount -gt 0) {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline -ForegroundColor White
    Write-Host "✖ (CRITICAL)" -ForegroundColor Red
} else {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline -ForegroundColor White
    Write-Host "✔" -ForegroundColor Green
}
Write-Host " Skipped       : $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host " Duration      : $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " JUnit report  : $junitPath" -ForegroundColor Cyan

# Persist the summary to the log file (the block above is written to the host
# after Stop-Transcript, so it never lands in the transcript).
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
