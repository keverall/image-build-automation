# =============================================================================
# HPE ProLiant Windows Server ISO Automation - PowerShell Test Runner
# =============================================================================
# Runs all Pester tests for the automation module.

<#
.SYNOPSIS
    Run full Pester test suite with code coverage.

.DESCRIPTION
    Executes comprehensive Pester tests for all automation module components:
    - Audit, Config, Credentials, Executor, FileIO, Inventory, Router unit tests
    - Set-MaintenanceMode unit tests
    - Validators unit tests
    
    Automatically repairs Pester installation if broken (using PSGallery or bundled vendor copy).
    Generates detailed test logs and Cobertura coverage reports.
    
    Exits with code 1 if any tests fail.

.EXAMPLE
    pwsh -File scripts/run-tests.ps1
#>

# Usage: pwsh -File scripts/run-pwsh-tests.ps1
# =============================================================================

using namespace System

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Ensure a working Pester 6.0.1 (with Pester.dll) is available, then import it.
. (Join-Path $PSScriptRoot 'Ensure-Pester.ps1')
Import-Module (Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1') -Force -WarningAction SilentlyContinue

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$publicPath = Join-Path $PROJECT_ROOT 'src/powershell'

$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT 'generated/logs/test'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "test_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running Pester tests from: $testPath" -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

# Dynamically discover all *.Tests.ps1 files in the test directory so newly
# added test files are picked up automatically without editing this script.
$discoveredTests = Get-ChildItem -Path $testPath -Filter '*.Tests.ps1' -File |
    Sort-Object Name |
    Where-Object { $_.Name -ne 'Pester.Integration.ps1' } |
    ForEach-Object { $_.FullName }

Write-Host "Discovered $($discoveredTests.Count) test files" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = $discoveredTests
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

# Persist the summary to the log file. The block above is written to the host
# after Stop-Transcript, so it never lands in the transcript. Append a
# plain-text copy here so the result is always recorded in the log.
$summaryLines = @(
    '',
    '================================================================================',
    '                           TEST SUMMARY BLOCK                                   ',
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