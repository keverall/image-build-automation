# scripts/cyberark-bootstrap.ps1
# Fetches secrets from CyberArk AIM REST API and exports them as environment variables
# Used in GitLab CI pipelines to securely inject credentials before maintenance operations

<#
.SYNOPSIS
    Bootstrap secrets from CyberArk CCP for CI/CD pipelines.

.DESCRIPTION
    Fetches required secrets from CyberArk Central Credential Provider (CCP)
    and exports them as environment variables for use in automation scripts.
    
    Required secrets:
    - SCOM_ADMIN_USER / SCOM_ADMIN_PASSWORD (from SCOM-2015 safe)
    - ONEVIEW_USER / ONEVIEW_PASSWORD (from HPE-OneView safe)
    
    Supports two output modes:
    - ExportForGitLab: Outputs dotenv format for GitLab CI (.env file)
    - Default: Sets environment variables in current PowerShell session

.PARAMETER CyberArkUrl
    CyberArk CCP API URL (default: from CYBERARK_CCP_URL env var or https://cyberark-ccp:443/AIMWebService/API/Accounts)

.PARAMETER AppId
    CyberArk application ID for authentication (default: 'ci')

.PARAMETER ExportForGitLab
    Output secrets in GitLab CI dotenv format instead of setting in session

.EXAMPLE
    pwsh -File scripts/cyberark-bootstrap.ps1
    
.EXAMPLE
    pwsh -File scripts/cyberark-bootstrap.ps1 -ExportForGitLab > .env
#>

param(
    [string]$CyberArkUrl = $env:CYBERARK_CCP_URL,
    [string]$AppId = 'ci',
    [switch]$ExportForGitLab
)

$ErrorActionPreference = 'Stop'

# Default CyberArk CCP URL if not provided
if (-not $CyberArkUrl) {
    $CyberArkUrl = 'https://cyberark-ccp:443/AIMWebService/API/Accounts'
}

# Define required secrets for SCOM and OneView
$SecretsToFetch = @(
    @{ Safe = 'SCOM-2015'; Object = 'SCOM_ADMIN_USER'; EnvVar = 'SCOM_ADMIN_USER' },
    @{ Safe = 'SCOM-2015'; Object = 'SCOM_ADMIN_PASSWORD'; EnvVar = 'SCOM_ADMIN_PASSWORD' },
    @{ Safe = 'HPE-OneView'; Object = 'ONEVIEW_USER'; EnvVar = 'ONEVIEW_USER' },
    @{ Safe = 'HPE-OneView'; Object = 'ONEVIEW_PASSWORD'; EnvVar = 'ONEVIEW_PASSWORD' }
)

$FetchedSecrets = @{}
$FailedSecrets = @()

Write-Host "=== CyberArk Secret Bootstrap ===" -ForegroundColor Cyan
Write-Host "Target URL: $CyberArkUrl"
Write-Host "App ID: $AppId"
Write-Host ""

foreach ($secret in $SecretsToFetch) {
    $query = "Safe=$($secret.Safe);Object=$($secret.Object)"
    $queryEnc = [System.Uri]::EscapeDataString($query)
    $fullUrl = "$CyberArkUrl?AppID=$AppId&Query=$queryEnc"

    Write-Host "Fetching $($secret.EnvVar)..." -NoNewline

    try {
        # Disable SSL validation for internal CyberArk appliances with self-signed certs
        # In production, use proper CA-signed certificates instead
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        $response = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        $items = if ($response -is [System.Array]) { $response[0] } else { $response }
        $value = $items.Content

        if ($value) {
            $FetchedSecrets[$secret.EnvVar] = $value
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [FAILED - Empty response]" -ForegroundColor Red
            $FailedSecrets += $secret.EnvVar
        }
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $FailedSecrets += $secret.EnvVar
    }
}

Write-Host ""
Write-Host "=== Bootstrap Summary ===" -ForegroundColor Cyan

if ($FailedSecrets.Count -gt 0) {
    Write-Host "Failed to fetch $($FailedSecrets.Count) secret(s): $($FailedSecrets -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "Successfully fetched $($FetchedSecrets.Count) secret(s)" -ForegroundColor Green

# Export for GitLab CI
if ($ExportForGitLab) {
    Write-Host ""
    Write-Host "=== GitLab CI Export ===" -ForegroundColor Cyan
    foreach ($key in $FetchedSecrets.Keys) {
        # GitLab CI dotenv format: KEY=value (no quotes)
        Write-Output "$key=$($FetchedSecrets[$key])"
    }
}
else {
    # Set in current PowerShell session
    foreach ($key in $FetchedSecrets.Keys) {
        [System.Environment]::SetEnvironmentVariable($key, $FetchedSecrets[$key], 'Process')
    }
    Write-Host "Secrets set in current PowerShell session." -ForegroundColor Green
}