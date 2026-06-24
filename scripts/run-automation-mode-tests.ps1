# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Automation Mode Test Runner
# =============================================================================
# Runs Pester tests covering the automation module's core build/deploy/runbook
# functionality (ConfigMgr bootable media, OneView resolution, iLO Redfish,
# pre/post validation, and the end-to-end orchestrator).
#
# This target is intended for quick validation of the automation workflow
# without running the full suite.

<#
.SYNOPSIS
    Run automation functionality tests.

.DESCRIPTION
    Executes focused Pester tests for the automation module's runbook functions:
    - New-IsoBuild, Publish-BootIso
    - Get-OneViewServerTarget
    - Invoke-IloRedfish, Invoke-IsoDeploy
    - Start-PhysicalServerBuild
    - Test-PreBuildValidation, Test-PostBuildValidation
    - Start-InstallMonitor
    - Update-Firmware, Update-WindowsSecurity

    Displays detailed test summary with pass/fail/skip counts and duration.
    Logs detailed output to generated/logs/{environment}/automation_mode_tests_*.log

    Exits with code 1 if any tests fail.

.EXAMPLE
    pwsh -File scripts/run-automation-mode-tests.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1') -Force -WarningAction SilentlyContinue

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "automation_mode_tests_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running automation functionality tests..." -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $testPath 'New-IsoBuild.Unit.Tests.ps1'),
    (Join-Path $testPath 'Publish-BootIso.Unit.Tests.ps1'),
    (Join-Path $testPath 'Get-OneViewServerTarget.Unit.Tests.ps1'),
    (Join-Path $testPath 'Invoke-IloRedfish.Unit.Tests.ps1'),
    (Join-Path $testPath 'Invoke-IsoDeploy.Unit.Tests.ps1'),
    (Join-Path $testPath 'Start-PhysicalServerBuild.Unit.Tests.ps1'),
    (Join-Path $testPath 'Test-PreBuildValidation.Unit.Tests.ps1'),
    (Join-Path $testPath 'Test-PostBuildValidation.Unit.Tests.ps1'),
    (Join-Path $testPath 'Start-InstallMonitor.Unit.Tests.ps1'),
    (Join-Path $testPath 'Update-Firmware.Unit.Tests.ps1'),
    (Join-Path $testPath 'Update-WindowsSecurity.Unit.Tests.ps1')
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
Write-Host " Passed        : $($results.PassedCount) " -NoNewline
if ($results.PassedCount -eq $results.TotalCount) { Write-Host "`u{2714}" -ForegroundColor Green } else { Write-Host "`u{2714}" -ForegroundColor Green }

if ($results.FailedCount -gt 0) {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "`u{2716} (CRITICAL)" -ForegroundColor Red
} else {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "`u{2714}" -ForegroundColor Green
}

Write-Host " Skipped       : $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host " Duration      : $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

exit ([int]($results.FailedCount -gt 0))
