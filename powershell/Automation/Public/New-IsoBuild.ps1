#
# New-IsoBuild.ps1 — ISO build orchestrator
# Equivalent of Python cli/build_iso.py
#

<#

.SYNOPSIS
    Orchestrates the full ISO build pipeline: UUID generation → firmware/driver ISO
    → Windows security patched ISO → deployment package.

.PARAMETER BaseIsoPath
    Path to the base Windows Server ISO (required for Windows security patching).

.PARAMETER ConfigDir
    Directory containing configuration JSON files (default: configs).

.PARAMETER OutputDir
    Root output directory (default: output).

.PARAMETER Server
    Build for a specific server only (omit to build for all servers in server_list.txt).

.PARAMETER DryRun
    Simulate without executing any commands.

.PARAMETER SkipAudit
    Skip writing the master audit log.

.EXAMPLE
    New-IsoBuild -BaseIsoPath 'C:\ISOs\WinServer2022.iso' -Server 'srv01.corp.local'

#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param(
    [Parameter(Mandatory = $false)][string] $BaseIsoPath  = $null,

    [Parameter(Mandatory = $false)][string] $ConfigDir    = 'configs',

    [Parameter(Mandatory = $false)][string] $OutputDir    = 'output',

    [Parameter(Mandatory = $false)][string] $Server       = $null,

    [Parameter(Mandatory = $false)][switch]  $DryRun,

    [Parameter(Mandatory = $false)][switch]  $SkipAudit
)

$Script:LogDir = Join-Path $PSScriptRoot '..\..\logs'
Initialize-Logging -LogFile 'build_orchestrator.log'

$FwConfig     = Join-Path $ConfigDir 'hpe_firmware_drivers_nov2025.json'
$PatchConfig  = Join-Path $ConfigDir 'windows_patches.json'
$ServerList   = Join-Path $ConfigDir 'server_list.txt'

foreach ($f in @($FwConfig, $PatchConfig, $ServerList)) {
    if (-not (Test-Path $f -PathType Leaf)) {
        Write-Error "Required config not found: $f"
        exit 1
    }
}

function Build-ForServer([string]$ServerName) {
    Write-Host "`n$('='*70)"
    Write-Host "Processing: $ServerName"
    Write-Host "$('='*70)"

    $result = @{
        server       = $ServerName
        uuid         = $null
        firmware_iso = $null
        patched_iso  = $null
        combined_iso = $null
        success      = $false
        timestamp    = (Get-Date).ToString('o')
        steps        = @()
    }

    try {
        # Step 1: UUID
        if ($DryRun) { $generatedUuid = '00000000-0000-0000-0000-000000000000' }
        else         { $generatedUuid = Test-Uuid -ServerName $ServerName }
        $result.uuid = $generatedUuid
        $result.steps += @{ Step = 'generate_uuid'; Uuid = $generatedUuid }

        # Step 2: Firmware
        $fwOutput  = Join-Path $OutputDir "firmware\$ServerName"
        $fwUpdater = [FirmwareUpdater]::new($FwConfig, $fwOutput)
        $fwResult  = $fwUpdater.Build($ServerName, $DryRun)
        if ($fwResult.Success -and $fwResult.FirmwareIso) {
            $result.firmware_iso = $fwResult.FirmwareIso
            $result.steps       += @{ Step = 'firmware_iso'; Status = 'ok'; Iso = $fwResult.FirmwareIso }
        } else {
            $result.steps += @{ Step = 'firmware_iso'; Status = 'failed' }
        }

        # Step 3: Security patch (only if BaseIsoPath provided)
        if ($BaseIsoPath) {
            $patchOutput = Join-Path $OutputDir "patched\$ServerName"
            $patcher     = [WindowsPatcher]::new($PatchConfig, $patchOutput)
            $patchResult = $patcher.Build($BaseIsoPath, $ServerName, 'dism', $DryRun)
            if ($patchResult.Success -and $patchResult.PatchedIso) {
                $result.patched_iso = $patchResult.PatchedIso
                $result.steps       += @{ Step = 'patched_iso'; Status = 'ok'; Iso = $patchResult.PatchedIso }
            } else {
                $result.steps += @{ Step = 'patched_iso'; Status = 'failed' }
            }
        } else {
            Write-Warning "No base ISO path given; skipping Windows patching for $ServerName"
            $result.steps += @{ Step = 'patched_iso'; Status = 'skipped' }
        }

        # Step 4: Deployment package
        $combinedDir = Join-Path $OutputDir "combined\$ServerName"
        Ensure-DirectoryExists -Path $combinedDir
        if ($result.firmware_iso -and (Test-Path $result.firmware_iso)) {
            Copy-Item $result.firmware_iso (Join-Path $combinedDir (Split-Path $result.firmware_iso -Leaf)) -Force
        }
        if ($result.patched_iso -and (Test-Path $result.patched_iso)) {
            Copy-Item $result.patched_iso (Join-Path $combinedDir (Split-Path $result.patched_iso -Leaf)) -Force
        }
        $metadata = @{
            server_name      = $ServerName
            uuid             = $generatedUuid
            build_timestamp  = (Get-Date).ToString('o')
            firmware_iso     = if ($result.firmware_iso) { Split-Path $result.firmware_iso -Leaf } else { $null }
            patched_iso      = if ($result.patched_iso)  { Split-Path $result.patched_iso -Leaf }  else { $null }
            config_version   = 'nov2025'
        }
        Save-Json -Data $metadata -Path (Join-Path $combinedDir 'deployment_metadata.json')
        $result.combined_iso = $combinedDir
        $result.success      = $true
    }
    catch {
        Write-Error "Build failed for $ServerName : $($_.Exception.Message)"
        $result.error = $_.Exception.Message
    }
    Save-JsonResult -Data $result -BaseName 'build_result' -OutputDir $OutputDir -Category 'results'
    return $result
}

# ---- Main ----
try {
    $servers = if ($Server) { @($Server) } else { Load-ServerList -Path $ServerList }
    $results = foreach ($s in $servers) { Build-ForServer $s }

    $successCount = ($results | Where-Object { $_.success }).Count
    Write-Host "`nBuild Summary: $successCount/$($servers.Count) successful"

    $summary = @{
        timestamp      = (Get-Date).ToString('o')
        total_servers  = $servers.Count
        successful     = $successCount
        failed         = ($servers.Count - $successCount)
        results        = $results
    }
    Save-JsonResult -Data $summary -BaseName 'build_summary' -OutputDir $OutputDir
    if ($successCount -eq $servers.Count) { exit 0 } else { exit 1 }
}
catch {
    Write-Error "Orchestrator failed: $($_.Exception.Message)"
    exit 1
}

# vim: ts=4 sw=4 et
