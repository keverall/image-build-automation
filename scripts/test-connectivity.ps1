#!/usr/bin/env pwsh
# Quick connectivity check for SCOM / OneView during maintenance windows.
# Combines network ping + authentication in a single command.  Read-only.

<#
.SYNOPSIS
    Combined ping + connect test for SCOM or OneView (safe during change freeze).

.PARAMETER Environment
    Environment to test: Test or Prod (default: 'Test')

.PARAMETER Mode
    Maintenance mode type: scom or oneview (default: 'scom')

.PARAMETER ManagementHost
    Override management server/appliance hostname

.PARAMETER Json
    Output as JSON

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds (default: 3000)

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Environment Test -Mode scom

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Environment Prod -Mode oneview -Json
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Test',
    [ValidateSet('scom', 'oneview')][string]$Mode = 'scom',
    [string]$ManagementHost,
    [switch]$Json,
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
    Mode          = $Mode
    Environment   = $Environment
    PingTimeoutMs = $PingTimeoutMs
}

if ($ManagementHost) { $connParams['ManagementHost'] = $ManagementHost }

$result = Test-ServerConnectivity @connParams

if ($Json) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host ""
    $statusColor = if ($result.Available) { 'Green' } else { 'Red' }
    $header = if ($result.Available) { "AVAILABLE" } else { "UNAVAILABLE" }
    Write-Host "  $($result.Mode.ToUpper()) [$($result.Environment)] -> $($result.ManagementHost)" -ForegroundColor Cyan
    Write-Host "  Status: $header" -ForegroundColor $statusColor

    $np = $result.NetworkPing
    if ($np.DnsResolved) {
        Write-Host "  DNS: Resolved" -ForegroundColor Green
        if ($np.IpAddress) { Write-Host "  IP:  $($np.IpAddress)" }
    } else {
        Write-Host "  DNS: FAILED" -ForegroundColor Red
    }

    if ($np.TcpPortOpen) {
        Write-Host "  TCP: Open (port $($np.Port), $($np.LatencyMs)ms)" -ForegroundColor Green
    } else {
        Write-Host "  TCP: FAILED" -ForegroundColor Red
    }

    $ac = $result.AuthConnect
    if ($ac.Error -match 'Skipped') {
        Write-Host "  Auth: $($ac.Error)" -ForegroundColor Yellow
    } elseif ($ac.Connected) {
        Write-Host "  Auth: Connected and disconnected" -ForegroundColor Green
    } else {
        Write-Host "  Auth: FAILED" -ForegroundColor Red
        if ($ac.Error) { Write-Host "  Error: $($ac.Error)" -ForegroundColor Red }
    }
    Write-Host ""
}

if (-not $result.Available) { exit 1 }
