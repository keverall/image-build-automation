# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Coverage Report
# =============================================================================
# Generates Cobertura XML code coverage reports using Pester.
# Usage: pwsh -File scripts/coverage-report.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

if (-not (Get-Module Pester -ListAvailable)) {
    Write-Error "Pester not installed. Install with: Install-Module Pester -Scope CurrentUser"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$publicPath = Join-Path $PROJECT_ROOT 'src/powershell/Automation/Public'
$outputPath = Join-Path $PROJECT_ROOT 'coverage-results.xml'

Write-Host "[coverage-report] Generating Cobertura XML coverage report..." -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @($testPath)
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @((Get-ChildItem -Path $publicPath -Filter '*.ps1' | ForEach-Object { $_.FullName }))
$config.CodeCoverage.OutputPath = $outputPath
$config.CodeCoverage.OutputFormat = 'Cobertura'

Invoke-Pester -Configuration $config

Write-Host "[coverage-report] Report written to coverage-results.xml" -ForegroundColor Green