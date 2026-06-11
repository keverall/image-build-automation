# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Test Runner
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

# Ensure Pester is available and DLL is present
$ErrorActionPreference = 'Continue'
$pesterModule = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
$pesterOk = $true
$pesterUserPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\Pester'
if ($pesterModule) {
    $moduleBase = Split-Path $pesterModule.Path -Parent
    $dllPath = Join-Path $moduleBase 'bin\netstandard2.0\Pester.dll'
    if (-not (Test-Path $dllPath)) {
        Write-Host "[repair] Pester.dll missing — reinstalling Pester 5.7.1..." -ForegroundColor Yellow
        $pesterOk = $false
    }
} else {
    Write-Host "[repair] Pester not found — installing Pester 5.7.1..." -ForegroundColor Yellow
    $pesterOk = $false
}

# Repair Pester using the same approach as manual fix
if (-not $pesterOk) {
    # Remove broken installation
    if (Test-Path $pesterUserPath) {
        Remove-Item -Recurse -Force $pesterUserPath -ErrorAction SilentlyContinue
        Write-Host "[repair] Removed broken Pester installation" -ForegroundColor Yellow
    }

    # Try PSGallery first, fall back to bundled vendor copy
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
        Write-Host "[repair] Installed Pester 5.7.1 from PSGallery" -ForegroundColor Green
    } catch {
        Write-Host "[repair] PSGallery unavailable, using bundled vendor copy..." -ForegroundColor Yellow
        $vendorPesterDir = Join-Path $PROJECT_ROOT 'vendor/modules/Pester'
        $vendorVersionDir = Get-ChildItem -Path $vendorPesterDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($vendorVersionDir -and (Test-Path (Join-Path $vendorVersionDir.FullName 'bin/netstandard2.0/Pester.dll'))) {
            $destDir = Join-Path $pesterUserPath $vendorVersionDir.Name
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item -Path "$($vendorVersionDir.FullName)/*" -Destination $destDir -Recurse -Force
            Write-Host "[repair] Installed Pester $($vendorVersionDir.Name) from vendor copy" -ForegroundColor Green
        } else {
            Write-Error "Pester repair failed. PSGallery unreachable and vendor copy missing."
            exit 1
        }
    }
}
$ErrorActionPreference = 'Stop'

if (-not (Get-Module Pester -ListAvailable)) {
    Write-Error "Pester not installed. Run 'make setup' or install manually: Install-Module Pester -Scope CurrentUser"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1') -Force -WarningAction SilentlyContinue

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$publicPath = Join-Path $PROJECT_ROOT 'src/powershell'

$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "testing_coverage_detail_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Running Pester tests from: $testPath" -ForegroundColor Cyan
Write-Host "Detailed log: $pesterLogPath" -ForegroundColor Cyan

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

if ($PSVersionTable.PSVersion.Major -ge 7) { $PSStyle.OutputRendering = 'Ansi' }

Start-Transcript -Path $pesterLogPath -Append:$false | Out-Null
try {
    $results = Invoke-Pester -Configuration $config
}
finally {
    Stop-Transcript | Out-Null
}

exit ([int]($results.FailedCount -gt 0))