# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Test Runner
# =============================================================================
# Runs all Pester tests for the automation module.
# Usage: pwsh -File scripts/run-pwsh-tests.ps1
# =============================================================================

using namespace System

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Ensure Pester is available and DLL is present
$ErrorActionPreference = 'Continue'
$pesterModule = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
$pesterOk = $true
if ($pesterModule) {
    $moduleBase = Split-Path $pesterModule.Path -Parent
    $dllPath = Join-Path $moduleBase 'bin\netstandard2.0\Pester.dll'
    if (-not (Test-Path $dllPath)) {
        Write-Host "[repair] Pester.dll missing — repairing from vendor/modules/Pester..." -ForegroundColor Yellow
        $pesterOk = $false
    }
} else {
    Write-Host "[repair] Pester not found — installing from vendor/modules/Pester..." -ForegroundColor Yellow
    $pesterOk = $false
}

# Repair Pester from bundled vendor copy if needed
if (-not $pesterOk) {
    $vendorPesterDir = Join-Path $PROJECT_ROOT 'vendor/modules/Pester'
    $vendorVersionDir = Get-ChildItem -Path $vendorPesterDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($vendorVersionDir -and (Test-Path (Join-Path $vendorVersionDir.FullName 'bin/netstandard2.0/Pester.dll'))) {
        if (-not $pesterModule) {
            $userModulePath = if ($IsWindows) { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules' } else { Join-Path $HOME '.local/share/powershell/Modules' }
            $destDir = Join-Path $userModulePath "Pester/$($vendorVersionDir.Name)"
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            Copy-Item -Path "$($vendorVersionDir.FullName)/*" -Destination $destDir -Recurse -Force
            Write-Host "[repair] Installed Pester $($vendorVersionDir.Name) from vendor copy" -ForegroundColor Green
        } else {
            $binDir = Join-Path $moduleBase 'bin'
            Copy-Item -Path "$($vendorVersionDir.FullName)/bin" -Destination $moduleBase -Recurse -Force
            Write-Host "[repair] Restored Pester bin/ folder from vendor copy" -ForegroundColor Green
        }
    } else {
        Write-Error "Vendor Pester copy not found at $vendorPesterDir or DLL missing. Run 'make setup'."
        exit 1
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