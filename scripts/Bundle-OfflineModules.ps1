<#
.SYNOPSIS
    Bundles required PowerShell modules for offline/air-gapped deployment.

.DESCRIPTION
    Downloads the required PowerShell modules (HPEOneView.860, OperationsManager) from the PowerShell Gallery 
    into the scripts/modules/ directory so they can be safely copied to an air-gapped environment.
    Run this script on a machine with internet access BEFORE copying the repo.
    Falls back to local SCOM installation paths for OperationsManager only if PSGallery download fails.

.EXAMPLE
    pwsh -File scripts/Bundle-OfflineModules.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$ModulesDir = Join-Path $PSScriptRoot 'modules'

if (-not (Test-Path $ModulesDir)) {
    New-Item -ItemType Directory -Path $ModulesDir -Force | Out-Null
}

Write-Host "Bundling modules for offline deployment..." -ForegroundColor Cyan

# 1. HPEOneView.860 (Download from PSGallery)
Write-Host "Downloading HPEOneView.860 (this may take a moment)..." -ForegroundColor Yellow
try {
    Save-Module -Name HPEOneView.860 -Path $ModulesDir -Force -ErrorAction Stop
    $hvModuleDir = Join-Path $ModulesDir 'HPEOneView.860'
    $downloadedVersion = (Get-ChildItem -Path $hvModuleDir -Directory | Select-Object -First 1).Name
    Write-Host "  -> Saved HPEOneView.860 version $downloadedVersion to $hvModuleDir`/$downloadedVersion/" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to download HPEOneView. Ensure you have internet access and PSGallery is reachable." -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. OperationsManager (Download from PSGallery)
Write-Host "Downloading OperationsManager (this may take a moment)..." -ForegroundColor Yellow
try {
    Save-Module -Name OperationsManager -Path $ModulesDir -Force -ErrorAction Stop
    $omModuleDir = Join-Path $ModulesDir 'OperationsManager'
    $downloadedVersion = (Get-ChildItem -Path $omModuleDir -Directory | Select-Object -First 1).Name
    Write-Host "  -> Saved OperationsManager version $downloadedVersion to $omModuleDir`/$downloadedVersion/" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to download OperationsManager from PSGallery. Attempting local SCOM paths fallback..." -ForegroundColor Yellow
    $scomPaths = @(
        'C:\Program Files\WindowsPowerShell\Modules\OperationsManager',
        'C:\Program Files\Microsoft System Center\Operations Manager\Powershell\OperationsManager'
    )

    $foundScom = $false
    foreach ($path in $scomPaths) {
        if (Test-Path $path) {
            $omTargetDir = Join-Path $ModulesDir 'OperationsManager'
            if (-not (Test-Path $omTargetDir)) { New-Item -ItemType Directory -Path $omTargetDir -Force | Out-Null }
            
            # Copy the version folder(s) to scripts/modules/OperationsManager/<version>/
            Get-ChildItem -Path $path -Directory | ForEach-Object {
                Write-Host "  -> Copying version $($_.Name)..." -ForegroundColor Yellow
                Copy-Item -Path $_.FullName -Destination (Join-Path $omTargetDir $_.Name) -Recurse -Force
            }
            $foundScom = $true
            Write-Host "  -> Saved OperationsManager to $omTargetDir" -ForegroundColor Green
            break
        }
    }

    if (-not $foundScom) {
        $manTarget = Join-Path $ModulesDir 'OperationsManager'
        Write-Host "  [ERROR] OperationsManager not found in standard SCOM paths and PSGallery download failed." -ForegroundColor Red
        Write-Host "  Please manually copy the OperationsManager folder from your SCOM server to:" -ForegroundColor Yellow
        Write-Host "  $manTarget\<version-folder>" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Bundling complete!" -ForegroundColor Green
Write-Host "You can now copy the entire 'image-build-automation' folder (including the scripts/modules directory) to your air-gapped test server." -ForegroundColor Cyan
