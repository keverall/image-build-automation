#!/usr/bin/env pwsh
#
# validate-maintenance-config.ps1 - Validate maintenance mode configuration and new parameters
#

<#
.SYNOPSIS
    Validate maintenance mode configuration files and environment.

.DESCRIPTION
    Comprehensive validation of maintenance mode setup including:
    - Configuration file existence (connection_hosts.json, scom_config, oneview_config, etc.)
    - connection_hosts.json structure and environment definitions
    - Required environment variables (SCOM/OneView credentials)
    - PowerShell module import and function availability
    - New parameter support (Environment, Host, Username)
    - Dry-run validation test
    
    Displays detailed pass/fail status for each check.

.PARAMETER Environment
    Environment to validate: Test or Prod (default: 'Test')

.EXAMPLE
    pwsh -File scripts/validate-maintenance-config.ps1
    
.EXAMPLE
    ./scripts/validate-maintenance-config.ps1 -Environment Prod
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Test'
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Maintenance Mode Configuration Validation ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Output ""

# Check required files
Write-Host "Checking configuration files..." -ForegroundColor Green

$files = @{
    'connection_hosts.json' = 'configs/connection_hosts.json'
    '.env (template)' = '.env.example'
    'scom_config.working.json' = 'configs/scom_config.working.json'
    'oneview_config.working.json' = 'configs/oneview_config.working.json'
    'clusters_catalogue.json' = 'configs/clusters_catalogue.json'
}

foreach ($name in $files.Keys) {
    $path = Join-Path $PSScriptRoot '..' $files[$name]
    if (Test-Path $path) {
        Write-Host "  ✓ $name" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $name (MISSING)" -ForegroundColor Red
    }
}

Write-Output ""

# Load and validate connection_hosts.json
Write-Host "Validating connection_hosts.json..." -ForegroundColor Green

$configPath = Join-Path $PSScriptRoot '../configs/connection_hosts.json'
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        
        if ($config.environments) {
            Write-Host "  ✓ Environments defined" -ForegroundColor Green
            
            if ($config.environments.Test) {
                Write-Host "  ✓ Test environment configured" -ForegroundColor Green
                if ($config.environments.Test.scom) {
                    Write-Host "    - SCOM: $($config.environments.Test.scom.management_server)" -ForegroundColor White
                }
                if ($config.environments.Test.oneview) {
                    Write-Host "    - OneView: $($config.environments.Test.oneview.appliance)" -ForegroundColor White
                }
            } else {
                Write-Host "  ✗ Test environment not configured" -ForegroundColor Red
            }
            
            if ($config.environments.Prod) {
                Write-Host "  ✓ Prod environment configured" -ForegroundColor Green
                if ($config.environments.Prod.scom) {
                    Write-Host "    - SCOM: $($config.environments.Prod.scom.management_server)" -ForegroundColor White
                }
                if ($config.environments.Prod.oneview) {
                    Write-Host "    - OneView: $($config.environments.Prod.oneview.appliance)" -ForegroundColor White
                }
            } else {
                Write-Host "  ✗ Prod environment not configured" -ForegroundColor Red
            }
        } else {
            Write-Host "  ✗ No environments section found" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Failed to parse connection_hosts.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ connection_hosts.json not found" -ForegroundColor Red
}

Write-Output ""

# Check environment variables
Write-Host "Checking environment variables..." -ForegroundColor Green

$envVars = @(
    'ENVIRONMENT',
    'SCOM_ADMIN_USER',
    'SCOM_ADMIN_PASSWORD',
    'ONEVIEW_USER',
    'ONEVIEW_PASSWORD',
    'MAINTENANCE_HOST'
)

foreach ($var in $envVars) {
    $value = [System.Environment]::GetEnvironmentVariable($var)
    if ($value) {
        $displayValue = if ($var -like '*PASSWORD*') { '***' } else { $value }
        Write-Host "  ✓ $var = $displayValue" -ForegroundColor Green
    } else {
        Write-Host "  - $var (not set)" -ForegroundColor Gray
    }
}

Write-Output ""

# Test module import
Write-Host "Testing module import..." -ForegroundColor Green

try {
    $modulePath = Join-Path $PSScriptRoot '../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
    
    # Check for Set-MaintenanceMode function
    $cmd = Get-Command Set-MaintenanceMode -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "  ✓ Set-MaintenanceMode function available" -ForegroundColor Green
        
        # Check for new parameters
        $newParams = @('Environment', 'Host', 'Username')
        foreach ($param in $newParams) {
            if ($cmd.Parameters.ContainsKey($param)) {
                Write-Host "  ✓ Parameter -$param available" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Parameter -$param NOT found" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  ✗ Set-MaintenanceMode function not found" -ForegroundColor Red
    }
    
    Remove-Module Automation -ErrorAction SilentlyContinue
}
catch {
    Write-Host "  ✗ Failed to import module: $_" -ForegroundColor Red
}

Write-Output ""

# Quick connectivity test (dry-run only)
Write-Host "Running dry-run validation..." -ForegroundColor Green

try {
    $modulePath = Join-Path $PSScriptRoot '../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    
    $result = Set-MaintenanceMode `
        -Action validate `
        -TargetId "$Environment-CLUSTER-01" `
        -Mode scom `
        -Environment $Environment `
        -DryRun
    
    if ($result.Success) {
        Write-Host "  ✓ Validation successful" -ForegroundColor Green
        Write-Host "    Message: $($result.Message)" -ForegroundColor White
    } else {
        Write-Host "  ✗ Validation failed" -ForegroundColor Red
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
    }
    
    Remove-Module Automation -ErrorAction SilentlyContinue
}
catch {
    Write-Host "  ✗ Validation error: $_" -ForegroundColor Red
}

Write-Output ""
Write-Host "=== Validation Complete ===" -ForegroundColor Cyan
Write-Output ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review any missing configuration files or environment variables" -ForegroundColor White
Write-Host "2. Run: pwsh scripts/test-maintenance-connection.ps1 -Environment $Environment -Mode scom" -ForegroundColor White
Write-Host "3. Run: pwsh scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru" -ForegroundColor White
Write-Output ""
