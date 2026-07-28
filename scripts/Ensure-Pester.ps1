# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Pester Availability Bootstrap
# =============================================================================
# Ensures a working Pester 6.0.1 module (with bin/net8.0/Pester.dll present) is
# available before the caller imports it. Shared by every test runner so each
# `make <x>-tests` target self-heals a broken or missing Pester install instead
# of failing on `Import-Module Pester` with an Add-Type / Pester.dll error.
#
# Logic (mirrors the previously-inline repair in run-tests.ps1):
#   1. If Pester 6 with bin/net8.0/Pester.dll is already installed -> import it.
#   2. Otherwise remove the broken copy and reinstall 6.0.1 from PSGallery,
#      falling back to the bundled vendor copy under vendor/modules/Pester.
#
# Dot-source this file from a test runner; it performs the import itself:
#   . (Join-Path $PSScriptRoot 'Ensure-Pester.ps1')

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

function Ensure-PesterAvailable {
    $userModuleDir = ($env:PSModulePath -split [IO.Path]::PathSeparator | Select-Object -First 1)
    $pesterUserPath = Join-Path $userModuleDir 'Pester'
    $dllRelative = Join-Path 'bin' 'net8.0' 'Pester.dll'
    $pesterOk = $false

    $pesterModule = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($pesterModule) {
        $moduleBase = Split-Path $pesterModule.Path -Parent
        $dllPath = Join-Path $moduleBase $dllRelative
        if (Test-Path $dllPath) { $pesterOk = $true }
    }

    if (-not $pesterOk) {
        Write-Host '[ensure-pester] Pester 6 with bin/net8.0/Pester.dll not available - repairing...' -ForegroundColor Yellow
        if (Test-Path $pesterUserPath) {
            Remove-Item -Recurse -Force $pesterUserPath -ErrorAction SilentlyContinue
            Write-Host '[ensure-pester] Removed broken Pester installation' -ForegroundColor Yellow
        }

        $localRoots = @(
            (Join-Path $PROJECT_ROOT 'scripts/modules/Pester'),
            (Join-Path $PROJECT_ROOT 'vendor/modules/Pester')
        )
        $repaired = $false
        foreach ($localRoot in $localRoots) {
            $versionDir = Get-ChildItem -Path $localRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($versionDir -and (Test-Path (Join-Path $versionDir.FullName $dllRelative))) {
                $destDir = Join-Path $pesterUserPath $versionDir.Name
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                Copy-Item -Path "$($versionDir.FullName)/*" -Destination $destDir -Recurse -Force
                $verifyPath = Join-Path $destDir $dllRelative
                if (-not (Test-Path $verifyPath)) {
                    Write-Host "[ensure-pester] Copy verification failed ($verifyPath missing) - trying next source" -ForegroundColor Yellow
                    Remove-Item -Recurse -Force $destDir -ErrorAction SilentlyContinue
                    continue
                }
                Write-Host "[ensure-pester] Installed Pester $($versionDir.Name) from $($localRoot)" -ForegroundColor Green
                $repaired = $true
                break
            }
        }

        # Fall back to PSGallery only if no usable local copy was found.
        if (-not $repaired) {
            try {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                Install-Module Pester -RequiredVersion 6.0.1 -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
                Write-Host '[ensure-pester] Installed Pester 6.0.1 from PSGallery' -ForegroundColor Green
                $repaired = $true
            } catch {
                Write-Host '[ensure-pester] PSGallery unavailable.' -ForegroundColor Yellow
            }
        }

        if (-not $repaired) {
            Write-Error 'Pester repair failed. No local copy (scripts/modules or vendor) and PSGallery unreachable.'
            exit 1
        }
    } else {
        Write-Host "[ensure-pester] Pester $($pesterModule.Version) already available." -ForegroundColor Green
    }

    if (-not (Get-Module Pester -ListAvailable)) {
        Write-Error "Pester not installed. Run 'make setup' or install manually: Install-Module Pester -Scope CurrentUser"
        exit 1
    }

    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
}

Ensure-PesterAvailable
