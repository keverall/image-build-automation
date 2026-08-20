#
# Public/Update-Firmware.ps1 - HPE firmware/driver ISO builder via HPE Smart Update Tool (SUT)
# Mirrors reference implementation cli/update_firmware_drivers.py
# Usage:  pwsh -File Update-Firmware.ps1 -Server 'srv01.corp.local'
#         pwsh -File Update-Firmware.ps1 -Config 'configs\hpe_firmware_drivers_nov2025.json'
#
# Differences from reference: PS uses the same single-shot SUT call as the reference,
# but also calls through Invoke-NativeCommandWithRetry (exponential back-off)
# so transient SUT failures are automatically retried.  The reference's single
# run_command() call does NOT do this - so the PS version is in fact stronger.
#
# NOTE: This function is NOT part of the new ConfigMgr end-to-end build workflow
# (Start-PhysicalServerBuild).  It remains available for standalone firmware ISO
# generation and is registered in request_types.json under update_firmware and
# patch_windows for that purpose.  Firmware is delivered separately by HPE SUT;
# the ConfigMgr bootable media is OS-image only.
#

function Update-Firmware {
    <#
    .SYNOPSIS
        Build HPE firmware/driver ISOs using the Smart Update Tool (SUT).
        Callable from the module Router.

    .DESCRIPTION
        Reads the firmware/driver manifest (hpe_firmware_drivers_nov2025.json) and
        invokes hpe_sut.exe to create per-server firmware ISOs.  Equivalent to the
        reference implementation automation.cli.update_firmware_drivers module.

    .PARAMETER Config
        Path to firmware drivers JSON config (default: configs\hpe_firmware_drivers_nov2025.json).

    .PARAMETER Server
        Build for a specific server only. Mutually exclusive with -SerialNumber.

    .PARAMETER SerialNumber
        Build for a server identified by its HPE serial number. Resolved to the
        server hostname via OneView; requires -OneViewHost.

    .PARAMETER OneViewHost
        OneView appliance hostname/IP used to resolve -SerialNumber.

    .PARAMETER ServerList
        Path to server_list.txt. Only used for -DryRun mock targeting.

    .PARAMETER OutputDir
        Output directory.

    .PARAMETER FirmwareFolders
        Additional firmware component source directories (string array). These are
        local folder paths containing pre-downloaded HPE SUT component packages
        (e.g. '.spp' component folders or extracted firmware update packs).
        Each folder is passed to hpe_sut via the --firmware-components flag so
        SUT includes them alongside the manifest-specified components. Use this
        when Marin provides firmware component folders outside the standard
        manifest repository.

        Example:
          Update-Firmware -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER SkipDownload
        Skip component download step.

    .PARAMETER DryRun
        Simulate without executing.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        firmware update. If it is OMITTED the command fails early with an expressive,
        logged error and performs no update. If it does NOT match the target, the
        update is aborted. Example (regex): -GuardRail 'quickview\.ilo0' matches
        server 'quickview.ilo03.alp'.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -Server 'srv01.corp.local'
    .EXAMPLE
        Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.ad.example.com'
    .EXAMPLE
        Update-Firmware -Server 'srv01.corp.local' -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
param(
    [Alias('Cfg')]
    [Parameter(Mandatory = $false)][string] $Config     = 'configs\hpe_firmware_drivers_nov2025.json',
    [Alias('Srvr')]
    [Parameter(Mandatory = $false)][string] $Server     = $null,
    [Alias('Srl')]
    [Parameter(Mandatory = $false)][string] $SerialNumber = $null,
    [Alias('OVHost')]
    [Parameter(Mandatory = $false)][string] $OneViewHost = $null,
    [Alias('SrvrList')]
    [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
    [Alias('OutDir')]
    [Parameter(Mandatory = $false)][string] $OutputDir  = 'output\firmware',
    [Alias('SkipDl')]
    [Parameter(Mandatory = $false)][switch] $SkipDownload,
    [Alias('Dry')]
    [Parameter(Mandatory = $false)][switch] $DryRun,
    [Alias('FwDirs')]
    [Parameter(Mandatory = $false)][string[]] $FirmwareFolders = @(),
    [string] $GuardRail = $null
)

    # ── Guard rail is MANDATORY on build/deploy commands ──────────────────────
    # Fail early (graceful, logged) when omitted so we never flash firmware to an
    # unapproved server on a shared/production network.
    $grCheck = Assert-GuardRailRequired -GuardRail $GuardRail `
        -CommandName 'Update-Firmware' -ActionDescription 'firmware update'
    if ($grCheck) { return $grCheck }

    if ($SerialNumber) {
        $resolved = Resolve-OneViewTarget -SerialNumber $SerialNumber -OneViewHost $OneViewHost -DryRun:$DryRun
        if (-not $resolved.Success) { return @{ Success = $false; Error = $resolved.Error } }
        $Server = $resolved.Identifier
        Write-Verbose "Resolved serial '$SerialNumber' -> $Server"
    }

    # ── Guard rail (build/deploy safety gate) ──────────────────────────────────
    if ($GuardRail -and $Server) {
        $guardOk = Assert-GuardRail -GuardRail $GuardRail -ResolvedServerName $Server `
            -SerialNumber $SerialNumber -ApplianceName $OneViewHost `
            -ActionDescription 'firmware update' -DryRun:$DryRun -SkipConfirmation
        if (-not $guardOk) {
            return @{ Success = $false; Error = "Guard rail rejected target '$Server' (guard: '$GuardRail'). No firmware update performed." }
        }
    }

    if (-not $DryRun -and -not $Server) {
        throw "Server or SerialNumber is required for non-dryrun firmware update"
    }
    # TERMINAL COMMAND: config is only read when the operator explicitly passes
    # -Config, or under -DryRun (config is a dry-run helper). A live run must not
    # silently read the default manifest path (see AGENTS.md).
    if (-not $DryRun -and -not $PSBoundParameters.ContainsKey('Config')) {
        return @{ Success = $false; Error = "A firmware manifest is required for a live run. Supply -Config <path-to-manifest.json> explicitly. The default config path is only used with -DryRun." }
    }
    Initialize-Logging -LogFile 'firmware_updater.log' -CommandName 'Update-Firmware'
    try {
        $servers = if ($DryRun -and -not $Server) { Load-ServerList -Path $ServerList } else { @($Server) }
        $updater = [FirmwareUpdater]::new($Config, $OutputDir)
        $updater.FirmwareFolders = $FirmwareFolders
        $results = foreach ($s in $servers) { $updater.Build($s, [bool]$DryRun) }
        $okCount = ($results | Where-Object { $_.success }).Count
        Write-Output "Firmware build: $okCount/$($servers.Count) succeeded"
        $resDir  = Join-Path $OutputDir 'results'
        Ensure-DirectoryExists -Path $resDir
        foreach ($r in $results) { Save-Json -Data $r -Path (Join-Path $resDir "firmware_result_$($r['server']).json") }
        $result = @{ Success = ($okCount -eq $servers.Count); Total = $servers.Count; Succeeded = $okCount; Results = $results }
        _Format-FirmwareResult -Result $result
        return $result
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}


function _Format-FirmwareResult {
    param([hashtable]$Result)

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  Firmware Build Results" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $overallColor = if ($Result.Success) { 'Green' } else { 'Red' }
    Write-Host "  Total:      $($Result.Total)" -ForegroundColor White
    Write-Host "  Succeeded:  $($Result.Succeeded)" -ForegroundColor Green
    Write-Host "  Failed:     $($Result.Total - $Result.Succeeded)" -ForegroundColor $(if ($Result.Succeeded -eq $Result.Total) { 'Gray' } else { 'Red' })
    Write-Host "  Overall:    $(if ($Result.Success) { 'PASS' } else { 'FAIL' })" -ForegroundColor $overallColor
    Write-Host ""

    if ($Result.Results -and $Result.Results.Count -gt 0) {
        $nameWidth = ($Result.Results | ForEach-Object { $_.server.Length } | Measure-Object -Maximum).Maximum
        if ($nameWidth -lt 15) { $nameWidth = 15 }
        if ($nameWidth -gt 40) { $nameWidth = 40 }

        $header = "{0,-$nameWidth}  {1,-10}  {2}" -f 'Server', 'Status', 'ISO Path'
        Write-Host $header -ForegroundColor Yellow
        Write-Host ("-" * $header.Length) -ForegroundColor Gray

        foreach ($r in $Result.Results) {
            $statusColor = if ($r.success) { 'Green' } else { 'Red' }
            $status = if ($r.success) { 'SUCCESS' } else { 'FAILED' }
            $isoPath = if ($r.firmware_iso) { $r.firmware_iso } else { '-' }
            $line = "{0,-$nameWidth}  {1,-10}  {2}" -f $r.server, $status, $isoPath
            Write-Host $line -ForegroundColor $statusColor
            if (-not $r.success -and $r.error) {
                Write-Host "    Error: $($r.error)" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}


class FirmwareUpdater {
    [string] $ConfigPath
    [string] $OutputDir
    [hashtable] $Config
    [string] $SutPath
    [hashtable] $DownloadCreds
    [System.Collections.ArrayList] $BuildLog
    [string[]] $FirmwareFolders

    # SUT retry settings (mirrors Invoke-NativeCommandWithRetry semantics)
    [int]    $MaxRetryAttempts = 3
    [double] $RetryDelaySeconds = 5.0

    FirmwareUpdater([string]$ConfigPath, [string]$OutputDir) {
        $this.ConfigPath = $ConfigPath
        $this.OutputDir  = $OutputDir
        $this.FirmwareFolders = @()
        $this.Config     = Import-JsonConfig -Path $ConfigPath -Required $true
        $this.BuildLog   = [System.Collections.ArrayList]::new()
        $this.SutPath    = $this._FindSut()
        # HPE repository download credentials from config (${VAR} expanded by Import-JsonConfig)
        # Config key: download_credentials.{username,password}  OR  download_credentials.use_env=true
        $dlCreds = $this.Config.Get_Item('download_credentials') ?? @{}
        if ($dlCreds.Count -gt 0) {
            $u = $dlCreds.Get_Item('username')
            $p = $dlCreds.Get_Item('password')
            if ($u -and $p) { $this.DownloadCreds = @{ User = $u; Password = $p } }
        }
    }

    [string] _FindSut() {
        $candidates = @(
            'tools\hpe_sut.exe',
            'C:\Program Files\HPE\Smart Update Tool\hpe_sut.exe',
            '/opt/hpe/sut/hpe_sut.exe',
            '/usr/local/bin/hpe_sut'
        )
        foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
        $envPath = [System.Environment]::GetEnvironmentVariable('PATH') -split [System.IO.Path]::PathSeparator
        foreach ($d in $envPath) {
            $p = Join-Path $d 'hpe_sut'
            if (Test-Path $p) { return $p }
        }
        throw "HPE SUT (hpe_sut) not found. Place in tools/ or add to PATH."
    }

    [string] _DetectGen([string]$ServerName) {
        $sn = $ServerName.ToLowerInvariant()
        if ($sn.Contains('gen10+') -or $sn.Contains('gen10plus') -or $sn.Contains('plus')) { return 'gen10_plus' }
        return 'gen10'
    }

    [hashtable[]] _ComponentsForGen([string]$Gen) {
        $components  = [System.Collections.Generic.List[hashtable]]::new()
        $genCfg      = $this.Config.Get_Item('components')
        if ($genCfg -and $genCfg.ContainsKey($Gen)) {
            $gCfg = $genCfg[$Gen]
            foreach ($fw in ($gCfg.Get_Item('firmware') ?? @())) {
                $components.Add(@{ Type='firmware'; Component=$fw['component']; Version=$fw['version'] })
            }
            foreach ($drv in ($gCfg.Get_Item('drivers') ?? @())) {
                $components.Add(@{ Type='driver'; Component=$drv['component']; Version=$drv['version'] })
            }
        }
        return ,$components.ToArray()
    }

    [void] _Log([string]$Step, [string]$Status, [string]$Details) {
        $entry = @{ timestamp = Get-UtcTimestamp; step = $Step; status = $Status; details = $Details }
        $null = $this.BuildLog.Add($entry)
        $msg = if ($Details) { "[$Status] $Step : $Details" } else { "[$Status] $Step" }
        Write-Output $msg
    }

    [CommandResult] _RunSut([string[]]$Args) {
        # Apply HPE download credentials to the command environment if available
        $envBlock = $null
        if ($this.DownloadCreds) {
            $envBlock = @{
                HPE_DOWNLOAD_USER  = $this.DownloadCreds.Get_Item('User')
                HPE_DOWNLOAD_PASS  = $this.DownloadCreds.Get_Item('Password')
            }
        }
        # Use Invoke-NativeCommandWithRetry for exponential back-off on transient SUT failures.
        # This is what makes the PowerShell version stronger than reference implementation's single-shot run_command.
        return Invoke-NativeCommandWithRetry -Command (@($this.SutPath) + $Args) `
                                             -MaxAttempts $this.MaxRetryAttempts `
                                             -DelaySeconds $this.RetryDelaySeconds `
                                             -TimeoutSeconds 3600
    }

    [hashtable] Build([string]$ServerName, [bool]$DryRun) {
        $result = @{
            server       = $ServerName
            firmware_iso = $null
            success      = $false
            build_log    = $this.BuildLog
            timestamp    = Get-UtcTimestamp
        }
        try {
            $gen        = $this._DetectGen($ServerName)
            $components = $this._ComponentsForGen($gen)
            $this._Log('build_start','START',"Building for $ServerName (gen=$gen)")
            $this._Log('detect_generation','INFO',"Detected: $gen")
            $this._Log('component_resolution','INFO',"Components: $($components.Count)")

            Ensure-DirectoryExists -Path $this.OutputDir
            $serverDir = Join-Path $this.OutputDir $ServerName
            Ensure-DirectoryExists -Path $serverDir

            if ($DryRun) {
                $fakeIso = Join-Path $serverDir "$ServerName`_firmware_dryrun.iso"
                $this._Log('dry_run','INFO','SUT execution skipped')
                $result.firmware_iso = $fakeIso
                $result.success      = $true
                return $result
            }

            $repoUrl  = $this.Config.Get_Item('hpe_repository_url') ?? ''
            $isoOut   = Join-Path $serverDir "$ServerName`_firmware.iso"
            $compList = ($components | ForEach-Object { $_['Component'] }) -join ','
            $sutArgs  = @('create', '--server-generation', $gen, '--repository', $repoUrl,
                          '--output', $isoOut, '--components', $compList, '--include-drivers')

            # Append additional firmware component source folders (Marin-provided)
            if ($this.FirmwareFolders.Count -gt 0) {
                $fwFoldersEscaped = ($this.FirmwareFolders | ForEach-Object { $_.Replace(' ', '` ' ) }) -join ','
                $sutArgs += '--firmware-components'
                $sutArgs += $fwFoldersEscaped
                $this._Log('component_resolution','INFO',"Extra firmware folders: $($this.FirmwareFolders -join ', ')")
            }

            $this._Log('sut_invoke','START',"$($this.SutPath) $($sutArgs -join ' ')  (max $($this.MaxRetryAttempts) attempts)")
            $sutResult = $this._RunSut($sutArgs)

            if ($sutResult.Success) {
                $this._Log('sut_invoke','SUCCESS','SUT completed')
                if (Test-Path $isoOut) {
                    $this._Log('iso_create','SUCCESS',"Created: $isoOut")
                    $result.firmware_iso = $isoOut
                    $result.success      = $true
                } else {
                    $this._Log('iso_create','FAILED','ISO not found after SUT run')
                }
            } else {
                $errSnip = $sutResult.StandardError.Substring(0, [Math]::Min(200,$sutResult.StandardError.Length))
                $this._Log('sut_invoke','FAILED',$errSnip)
                $result['error'] = $sutResult.StandardError
            }
        }
        catch {
            $this._Log('build','FAILED',$_.Exception.Message)
            $result['error'] = $_.Exception.Message
        }
        return $result
    }
}

# vim: ts=4 sw=4 et