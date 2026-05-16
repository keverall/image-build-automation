#
# Public/Update-Firmware.ps1 — HPE firmware/driver ISO builder via HPE Smart Update Tool (SUT)
# Mirrors Python cli/update_firmware_drivers.py
# Usage:  pwsh -File Update-Firmware.ps1 -Server 'srv01.corp.local'
#         pwsh -File Update-Firmware.ps1 -Config 'configs\hpe_firmware_drivers_nov2025.json'
#
# Differences from Python: PS uses the same single-shot SUT call as Python,
# but also calls through Invoke-NativeCommandWithRetry (exponential back-off)
# so transient SUT failures are automatically retried.  Python's single
# run_command() call does NOT do this — so the PS version is in fact stronger.
#

function Update-Firmware {
    <#
    .SYNOPSIS
        Build HPE firmware/driver ISOs using the Smart Update Tool (SUT).
        Callable from the module Router.

    .DESCRIPTION
        Reads the firmware/driver manifest (hpe_firmware_drivers_nov2025.json) and
        invokes hpe_sut.exe to create per-server firmware ISOs.  Equivalent to the
        Python automation.cli.update_firmware_drivers module.

    .PARAMETER Config
        Path to firmware drivers JSON config (default: configs\hpe_firmware_drivers_nov2025.json).

    .PARAMETER Server
        Build for a specific server only.

    .PARAMETER ServerList
        Path to server_list.txt.

    .PARAMETER OutputDir
        Output directory.

    .PARAMETER SkipDownload
        Skip component download step.

    .PARAMETER DryRun
        Simulate without executing.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -Server 'srv01.corp.local'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)][string] $Config     = 'configs\hpe_firmware_drivers_nov2025.json',
        [Parameter(Mandatory = $false)][string] $Server     = $null,
        [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][string] $OutputDir  = 'output\firmware',
        [Parameter(Mandatory = $false)][switch] $SkipDownload,
        [Parameter(Mandatory = $false)][switch] $DryRun
    )
    Initialize-Logging -LogFile 'firmware_updater.log'
    try {
        $servers = if ($Server) { @($Server) } else { Load-ServerList -Path $ServerList }
        $updater = [FirmwareUpdater]::new($Config, $OutputDir)
        $results = foreach ($s in $servers) { $updater.Build($s, [bool]$DryRun) }
        $okCount = ($results | Where-Object { $_.success }).Count
        Write-Host "Firmware build: $okCount/$($servers.Count) succeeded"
        $resDir  = Join-Path $OutputDir 'results'
        Ensure-DirectoryExists -Path $resDir
        foreach ($r in $results) { Save-Json -Data $r -Path (Join-Path $resDir "firmware_result_$($r['server']).json") }
        return @{ Success = ($okCount -eq $servers.Count); Total = $servers.Count; Succeeded = $okCount; Results = $results }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

[CmdletBinding()]
param(
    [string] $Config     = 'configs\hpe_firmware_drivers_nov2025.json',
    [string] $Server     = $null,
    [string] $ServerList = 'configs\server_list.txt',
    [string] $OutputDir  = 'output\firmware',
    [switch] $SkipDownload,
    [switch] $DryRun
)

Initialize-Logging -LogFile 'firmware_updater.log'

class FirmwareUpdater {
    [string] $ConfigPath
    [string] $OutputDir
    [hashtable] $Config
    [string] $SutPath
    [hashtable] $DownloadCreds
    [System.Collections.ArrayList] $BuildLog

    # SUT retry settings (mirrors Invoke-NativeCommandWithRetry semantics)
    [int]    $MaxRetryAttempts = 3
    [double] $RetryDelaySeconds = 5.0

    FirmwareUpdater([string]$ConfigPath, [string]$OutputDir) {
        $this.ConfigPath = $ConfigPath
        $this.OutputDir  = $OutputDir
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
        $entry = @{ timestamp = (Get-Date -Format o); step = $Step; status = $Status; details = $Details }
        $null = $this.BuildLog.Add($entry)
        $msg = if ($Details) { "[$Status] $Step : $Details" } else { "[$Status] $Step" }
        Write-Host $msg
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
        # This is what makes the PowerShell version stronger than Python's single-shot run_command.
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
            timestamp    = (Get-Date -Format o)
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

# ── Main (script mode only) ───────────────────────────────────────────────────
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.PSScriptRoot -ne $null) {
    try {
        $servers = if ($Server) { @($Server) } else { Load-ServerList -Path $ServerList }
        $updater = [FirmwareUpdater]::new($Config, $OutputDir)
        $results = foreach ($s in $servers) { $updater.Build($s, [bool]$DryRun) }
        $okCount = ($results | Where-Object { $_.success }).Count
        Write-Host "Firmware build: $okCount/$($servers.Count) succeeded"
        $resDir  = Join-Path $OutputDir 'results'
        Ensure-DirectoryExists -Path $resDir
        foreach ($r in $results) { Save-Json -Data $r -Path (Join-Path $resDir "firmware_result_$($r['server']).json") }
        exit (if ($okCount -eq $servers.Count) { 0 } else { 1 })
    }
    catch { Write-Error "Firmware build failed: $($_.Exception.Message)"; exit 1 }
}

# vim: ts=4 sw=4 et
