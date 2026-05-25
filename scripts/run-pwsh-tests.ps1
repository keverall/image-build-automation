# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Test Runner
# =============================================================================
# Runs all Pester tests for the automation module.
# Usage: pwsh -File scripts/run-pwsh-tests.ps1
# =============================================================================

using namespace System

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Ensure Pester is available
if (-not (Get-Module Pester -ListAvailable)) {
    Write-Error "Pester not installed. Run 'make pwsh-setup' or install manually: Install-Module Pester -Scope CurrentUser"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1') -Force -WarningAction SilentlyContinue

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$publicPath = Join-Path $PROJECT_ROOT 'src/powershell'

Write-Host "Running Pester tests from: $testPath" -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $testPath 'Audit.Unit.Tests.ps1'),
    (Join-Path $testPath 'Config.Unit.Tests.ps1'),
    (Join-Path $testPath 'Credentials.Unit.Tests.ps1'),
    (Join-Path $testPath 'Executor.Unit.Tests.ps1'),
    (Join-Path $testPath 'FileIO.Unit.Tests.ps1'),
    (Join-Path $testPath 'Inventory.Unit.Tests.ps1'),
    (Join-Path $testPath 'Router.Unit.Tests.ps1'),
    (Join-Path $testPath 'Set-MaintenanceMode.Unit.Tests.ps1'),
    (Join-Path $testPath 'Validators.Unit.Tests.ps1')
)
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = 'Auto'

$results = Invoke-Pester -Configuration $config
exit ([int]($results.FailedCount -gt 0))