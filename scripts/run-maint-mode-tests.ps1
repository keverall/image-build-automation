# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Maintenance Mode Test Runner
# =============================================================================
# Runs high-priority Pester tests for Set-MaintenanceMode.ps1 with a 
# Jest/Pytest-style summary block.

<#
.SYNOPSIS
    Run maintenance mode validation and connectivity tests.

.DESCRIPTION
    Executes high-priority Pester tests for maintenance mode operations:
    - Test-ServerConnectivity.Tests.ps1 (connectivity validation - runs first)
    - Set-MaintenanceMode.Validation.Tests.ps1
    - Set-MaintenanceMode.Enable.Tests.ps1
    - Set-MaintenanceMode.Disable.Tests.ps1
    
    Tests are ordered logically: connectivity checks first, then maintenance operations.
    
    Displays detailed test summary with pass/fail/skip counts and duration.
    Logs detailed output to generated/logs/{environment}/maint_mode_tests_*.log
    
    Exits with code 1 if any tests fail.

.EXAMPLE
    pwsh -File scripts/run-maint-mode-tests.ps1
#>

# Usage: pwsh -File scripts/run-maint-mode-tests.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1') -Force -WarningAction SilentlyContinue

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "maint_mode_tests_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running high-priority Set-MaintenanceMode tests..." -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $testPath 'Test-ServerConnectivity.Tests.ps1'),
    (Join-Path $testPath 'Set-MaintenanceMode.Validation.Tests.ps1'),
    (Join-Path $testPath 'Set-MaintenanceMode.Enable.Tests.ps1'),
    (Join-Path $testPath 'Set-MaintenanceMode.Disable.Tests.ps1')
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
if ($results.PassedCount -eq $results.TotalCount) { Write-Host "✔" -ForegroundColor Green } else { Write-Host "✔" -ForegroundColor Green }

if ($results.FailedCount -gt 0) {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "✖ (CRITICAL)" -ForegroundColor Red
} else {
    Write-Host " Failed        : $($results.FailedCount) " -NoNewline
    Write-Host "✔" -ForegroundColor Green
}

Write-Host " Skipped       : $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host " Duration      : $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

exit ([int]($results.FailedCount -gt 0))
