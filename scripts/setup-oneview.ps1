# scripts/setup-oneview.ps1
# Setup script for HPE OneView hardware-level maintenance mode configuration
param(
    [string]$ConfigDir = 'configs'
)

$ErrorActionPreference = 'Stop'

# Import the Automation module
Import-Module (Join-Path $PSScriptRoot 'src/powershell/Automation/Automation.psd1') -Force

# Verify HPOneView module is available
if (-not (Get-Module -ListAvailable -Name 'HPOneView.Managed')) {
    Write-Warning "HPOneView.Managed module not found."
    Write-Warning "Install from OneView appliance:"
    Write-Warning "  Save-Module -Name HPOneView.Managed -Path C:\temp"
    Write-Warning "  Import-Module C:\temp\HPOneView.Managed\*"
}

# Test OneView credentials are available
$ovUser = [System.Environment]::GetEnvironmentVariable('ONEVIEW_USER')
$ovPass = [System.Environment]::GetEnvironmentVariable('ONEVIEW_PASSWORD')

if ($ovUser -and $ovPass) {
    Write-Host "[OK] OneView credentials available (`$ovUser)" -ForegroundColor Green
} else {
    Write-Warning "[MISSING] OneView credentials not found. Set via:"
    Write-Warning "  `$env:ONEVIEW_USER = '<username>'"
    Write-Warning "  `$env:ONEVIEW_PASSWORD = '<password>'"
    Write-Warning "Or ensure CyberArk bootstrap stage ran before this script."
}

# Verify config file exists
$configPath = Join-Path $PSScriptRoot $ConfigDir 'oneview_config.json'
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "[OK] OneView config loaded" -ForegroundColor Green
    Write-Host "  Appliance: $($config.oneview.appliance)"
    Write-Host "  Use WinRM: $($config.oneview.use_winrm)"
} else {
    Write-Warning "[MISSING] Config file not found: $configPath"
}