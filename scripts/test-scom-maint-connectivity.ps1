#!/usr/bin/env pwsh
# Quick SCOM connectivity check during maintenance windows.
# Combines network ping + authentication in a single command.  Read-only.

<#
.SYNOPSIS
    SCOM ping + connect test (safe during change freeze).

.PARAMETER Environment
    Environment to test: Test or Prod (default: 'Prod'). Only used with -JsonConfig.

.PARAMETER ManagementHost
    Override SCOM management server hostname (highest priority, required for live runs)

.PARAMETER Credential
    PSCredential for the live connection. If omitted, prompts interactively.

.PARAMETER JsonConfig
    Use configs/connection_hosts.json to resolve the management server (DryRun only).

.PARAMETER Json
    Output as JSON

.PARAMETER DryRun
    Simulate connectivity without actual network calls

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds (default: 3000)

.EXAMPLE
    pwsh -File scripts/test-scom-maint-connectivity.ps1 -ManagementHost 'VR-OPM19T1-7382.ad.example.com'

.EXAMPLE
    pwsh -File scripts/test-scom-maint-connectivity.ps1 -Environment Test -JsonConfig -DryRun

.EXAMPLE
    pwsh -File scripts/test-scom-maint-connectivity.ps1 -ManagementHost 'VR-OPM19T1-7382.ad.example.com' -Credential (Get-Credential)
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Prod',
    [string]$ManagementHost,
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$JsonConfig,
    [switch]$Json,
    [switch]$DryRun,
    [int]$PingTimeoutMs = 3000
)

$ErrorActionPreference = 'Continue'

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
            }
        }
    }
}

$modulePath = Join-Path $PSScriptRoot '..\src\powershell\Automation\Automation.psd1'
Import-Module $modulePath -Force -WarningAction SilentlyContinue

$connParams = @{
    PingTimeoutMs = $PingTimeoutMs
    DryRun = $DryRun
}

if ($Environment)    { $connParams['Environment'] = $Environment }
if ($ManagementHost) { $connParams['ManagementHost'] = $ManagementHost }
if ($Credential)    { $connParams['Credential'] = $Credential }
if ($JsonConfig)     { $connParams['JsonConfig'] = $true }
if ($Json)           { $connParams['Json'] = $true }

$result = Test-ScomMaintenanceConnectivity @connParams

if ($Json) {
    $result | ConvertTo-Json -Depth 10
}

if (-not $result.Available) { exit 1 }
