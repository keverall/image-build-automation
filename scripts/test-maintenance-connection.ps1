#!/usr/bin/env pwsh
# Test script for maintenance mode connection with environment-based host selection

<#
.SYNOPSIS
    Test maintenance mode connectivity to SCOM or OneView.

.DESCRIPTION
    Validates connection to maintenance mode infrastructure (SCOM or OneView)
    using environment-based host selection from connection_hosts.json.
    
    Loads .env file if present, builds parameters, and executes validation
    against Set-MaintenanceMode function.

.PARAMETER Environment
    Environment to test: Test or Prod (default: 'Test')

.PARAMETER Mode
    Maintenance mode type: scom or oneview (default: 'scom')

.PARAMETER DryRun
    Validate connection without making changes

.PARAMETER Username
    Override username for authentication

.PARAMETER ManagementHost
    Override management server/appliance hostname

.EXAMPLE
    pwsh -File scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom
    
.EXAMPLE
    ./scripts/test-maintenance-connection.ps1 -Environment Prod -Mode oneview -DryRun -ManagementHost 'backup-server.local'
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Test',
    [ValidateSet('scom', 'oneview')][string]$Mode = 'scom',
    [switch]$DryRun,
    [string]$Username,
    [string]$ManagementHost
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Maintenance Mode Connection Test ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Mode: $Mode" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Check if .env file exists and load it
$envFile = Join-Path $PSScriptRoot '..\.env'
if (Test-Path $envFile) {
    Write-Host "Loading .env file..." -ForegroundColor Green
    Get-Content $envFile | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $name = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($value) {
                [System.Environment]::SetEnvironmentVariable($name, $value)
                Write-Verbose "Set env var: $name"
            }
        }
    }
}

# Build parameters
$params = @{
    Action = 'validate'
    TargetId = 'TEST-CLUSTER-01'
    Mode = $Mode
    Environment = $Environment
    DryRun = $DryRun
}

if ($Username) { $params['Username'] = $Username }
if ($ManagementHost) { $params['ManagementHost'] = $ManagementHost }

Write-Host "Parameters:" -ForegroundColor Yellow
$params | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Executing validation..." -ForegroundColor Green
Write-Host ""

try {
    $result = & "$PSScriptRoot\..\src\powershell\Automation\Public\Set-MaintenanceMode.ps1" @params
    
    Write-Host "=== Result ===" -ForegroundColor Cyan
    if ($result.Success) {
        Write-Host "SUCCESS: Connection validated successfully" -ForegroundColor Green
        Write-Host "Message: $($result.Message)" -ForegroundColor White
    } else {
        Write-Host "FAILED: Connection validation failed" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
    }
    
    if ($result.ContainsKey('StartTimeUtc')) {
        Write-Host "Start Time (UTC): $($result.StartTimeUtc)" -ForegroundColor White
    }
    if ($result.ContainsKey('EndTimeUtc')) {
        Write-Host "End Time (UTC): $($result.EndTimeUtc)" -ForegroundColor White
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
