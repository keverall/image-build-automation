#!/usr/bin/env pwsh
# Quick OneView connectivity check during maintenance windows.
# Combines network ping + authentication in a single command.  Read-only.

<#
.SYNOPSIS
    OneView connectivity STATUS CHECK (safe during change freeze).

.DESCRIPTION
    Wrapper around the Test-ServerConnectivity module command. This is a STATUS
    CHECK, not a connect command - it NEVER prompts for a host or credentials.
    Run with no parameters to report the ACTIVE OneView connection (established
    by Connect-OneView); supply -OneViewHost to check a SPECIFIC appliance.
    To actually connect, use Connect-OneView -OneViewHost <host>.

.PARAMETER Environment
    Environment to test: Test or Prod (default: 'Prod'). Only used with -JsonConfig.

.PARAMETER OneViewHost
    Override OneView appliance hostname (highest priority). Optional - omit to
    report the active Connect-OneView session.

.PARAMETER Credential
    PSCredential for the live connection. If omitted, the active session is reused
    (when it matches) or ONEVIEW_USER / ONEVIEW_PASSWORD / CyberArk are used. This
    command never prompts.

.PARAMETER JsonConfig
    Use configs/connection_hosts.json to resolve the appliance (DryRun only).

.PARAMETER Json
    Output as JSON

.PARAMETER DryRun
    Simulate connectivity without actual network calls

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds (default: 3000)

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -OneViewHost 'oneview.example.com'

.EXAMPLE
    pwsh -File scripts/test-connectivity.ps1 -Environment Test -JsonConfig -DryRun
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Prod')][string]$Environment = 'Prod',
    [string]$OneViewHost,
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
if ($OneViewHost) { $connParams['OneViewHost'] = $OneViewHost }
if ($Credential)    { $connParams['Credential'] = $Credential }
if ($JsonConfig)     { $connParams['JsonConfig'] = $true }
if ($Json)           { $connParams['Json'] = $true }

$result = Test-ServerConnectivity @connParams

if ($Json) {
    $result | ConvertTo-Json -Depth 10
}

if (-not $result.Available) { exit 1 }
