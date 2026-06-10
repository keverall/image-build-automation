# scripts/setup-scom.ps1
# Setup script for SCOM cluster-level maintenance mode configuration
param(
    [string]$ConfigDir = 'configs'
)

$ErrorActionPreference = 'Stop'

# Import the Automation module
Import-Module (Join-Path $PSScriptRoot 'src/powershell/Automation/Automation.psd1') -Force

# Verify OperationsManager module is available
if (-not (Get-Module -ListAvailable -Name 'OperationsManager')) {
    Write-Warning "OperationsManager module not found."
    Write-Warning "Import from SCOM server share or install SCOM console:"
    Write-Warning "  Import-Module \\VR-OPM19P1-7382.ad.example.com\share\OperationsManager"
}

# Test SCOM credentials are available
$scomUser = [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_USER')
$scomPass = [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_PASSWORD')

if ($scomUser -and $scomPass) {
    Write-Host "[OK] SCOM credentials available (`$scomUser)" -ForegroundColor Green
} else {
    Write-Warning "[MISSING] SCOM credentials not found. Set via:"
    Write-Warning "  `$env:SCOM_ADMIN_USER = '<username>'"
    Write-Warning "  `$env:SCOM_ADMIN_PASSWORD = '<password>'"
    Write-Warning "Or ensure CyberArk bootstrap stage ran before this script."
}

# Verify config file exists
$configPath = Join-Path $PSScriptRoot $ConfigDir 'scom_config.json'
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "[OK] SCOM config loaded" -ForegroundColor Green
    Write-Host "  Management Server: $($config.scom.management_server)"
    Write-Host "  Use WinRM: $($config.scom.use_winrm)"
} else {
    Write-Warning "[MISSING] Config file not found: $configPath"
}