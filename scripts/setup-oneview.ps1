# scripts/setup-oneview.ps1
# Setup script for HPE OneView hardware-level maintenance mode configuration

<#
.SYNOPSIS
    Configure HPE OneView integration for maintenance mode.

.DESCRIPTION
    Validates OneView setup by checking:
    - HPEOneView.Xxx PowerShell module availability (only ONE version allowed)
    - ONEVIEW_USER and ONEVIEW_PASSWORD environment variables
    - OneView configuration file (oneview_config.json) existence
    
    Displays warnings if components are missing but doesn't fail execution.

.PARAMETER ConfigDir
    Directory containing configuration files (default: 'configs')

.EXAMPLE
    pwsh -File scripts/setup-oneview.ps1

.EXAMPLE
    pwsh -File scripts/setup-oneview.ps1 -ConfigDir './configs'

.NOTES
    Module name format: HPEOneView.<major><minor> (e.g., HPEOneView.1000 for OneView 10.00)
    Only ONE HPE OneView module version can be installed at a time.
    To switch versions: Uninstall-Module HPEOneView.OLD_VERSION -Force
    See docs/oneview-module-versions.md for compatibility table.
#>

param(
    [string]$ConfigDir = 'configs'
)

$ErrorActionPreference = 'Stop'

# Import the Automation module
Import-Module (Join-Path $PSScriptRoot 'src/powershell/Automation/Automation.psd1') -Force

# Verify HPE OneView module is available
$ovModules = Get-Module -ListAvailable -Name 'HPEOneView.*' | Select-Object -ExpandProperty Name
if (-not $ovModules) {
    $ovModules = Get-Module -ListAvailable -Name 'HPOneView.*' | Select-Object -ExpandProperty Name
}
if ($ovModules) {
    Write-Host "[OK] OneView module(s) found: ($($ovModules -join ', '))" -ForegroundColor Green
    Write-Host "  Recommended module format: HPEOneView.1000 (for OneView 10.00+)"
    Write-Host "  See docs/oneview-module-versions.md for compatibility table."
    if ($ovModules.Count -gt 1) {
        Write-Warning "[WARNING] Multiple modules detected. Only ONE HPE OneView module should be installed."
        Write-Warning "  Remove old versions: Uninstall-Module HPEOneView.OLD_VERSION -Force"
        Write-Warning "  Or use: Install-Module HPEOneView.1000 -Scope CurrentUser -AllowClobber -Force"
    }
} else {
    Write-Warning "[MISSING] No HPEOneView.* module found."
    Write-Warning "Install from PowerShell Gallery:"
    Write-Warning "  Install-Module HPEOneView.1000 -Scope CurrentUser -AllowClobber -Force"
    Write-Warning "  See: https://github.com/HewlettPackard/POSH-HPEOneView"
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