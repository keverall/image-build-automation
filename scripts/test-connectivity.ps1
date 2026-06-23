#!/usr/bin/env pwsh
# Quick connectivity check for SCOM / OneView during maintenance windows.
# Combines network ping + authentication in a single command.  Read-only.

<#
.SYNOPSIS
    Combined ping + connect test for SCOM or OneView (safe during change freeze).

.PARAMETER Environment
    Environment to test: Test or Prod (default: 'Prod'). Only used with -JsonConfig.

.PARAMETER Mode
    Maintenance mode type: scom or oneview (default: 'scom')

.PARAMETER ManagementHost
    Override management server/appliance hostname (highest priority)

.PARAMETER JsonConfig
    Use configs/connection_hosts.json to resolve management host.
    Without this switch, the command prompts for host details interactively.

.PARAMETER Json
    Output as JSON

.PARAMETER DryRun
    Simulate connectivity without actual network calls

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds (default: 3000)

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Mode scom -JsonConfig -Environment Test

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Mode oneview -JsonConfig -Environment Prod -Json

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Mode scom -ManagementHost 'scom-test.local'

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Mode scom
    (Will prompt for host interactively)
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Prod',
    [ValidateSet('scom', 'oneview')][string]$Mode = 'scom',
    [string]$ManagementHost,
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
    Mode = $Mode
    PingTimeoutMs = $PingTimeoutMs
    DryRun = $DryRun
}

if ($ManagementHost)  { $connParams['ManagementHost'] = $ManagementHost }
if ($JsonConfig)      { $connParams['JsonConfig'] = $true }
if ($JsonConfig)      { $connParams['Environment'] = $Environment }
if ($Json)            { $connParams['Json'] = $true }

$result = Test-ServerConnectivity @connParams

if ($Json) {
    $result | ConvertTo-Json -Depth 10
}

if (-not $result.Available) { exit 1 }
