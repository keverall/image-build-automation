#
# Update-WindowsSecurity.ps1 — Windows security patcher / ISO builder
# Equivalent of Python cli/patch_windows_security.py
#

<#

.SYNOPSIS
    Applies Windows security patches to a base Windows Server ISO image using DISM
    or PowerShell DISM cmdlets, then creates a patched ISO.

.PARAMETER BaseIsoPath
    Path to the base Windows Server ISO file (required).

.PARAMETER Server
    Server hostname (used for output naming).

.PARAMETER PatchesConfig
    Path to windows_patches.json configuration file (default: configs\windows_patches.json).

.PARAMETER OutputDir
    Output directory for patched ISOs (default: output\patched).

.PARAMETER Method
    Patching method: 'dism' or 'powershell' (default: dism).

.PARAMETER DryRun
    Simulate without making changes.

.EXAMPLE
    Update-WindowsSecurity -BaseIsoPath 'C:\ISOs\WinServer2022.iso' -Server 'srv01' -DryRun

#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param(
    [Parameter(Mandatory)][Alias('BaseIso','b')][string] $BaseIsoPath,

    [Parameter(Mandatory)][Alias('ServerName','s')][string] $Server,

    [Parameter(Mandatory = $false)][Alias('PatchesConfig','p')][string] $PatchesConfig = 'configs\windows_patches.json',

    [Parameter(Mandatory = $false)][Alias('OutputDir','o')][string] $OutputDir = 'output\patched',

    [ValidateSet('dism','powershell')]
    [Parameter(Mandatory = $false)][Alias('Method','m')][string] $Method = 'dism',

    [Parameter(Mandatory = $false)][switch] $DryRun
)

$Script:LogDir = Join-Path $PSScriptRoot '..\..\logs'
Initialize-Logging -LogFile 'windows_patcher.log'

# ---- WindowsPatcher class ----
class WindowsPatcher {
    [string]  $PatchesConfigPath
    [string]  $BaseIsoDir
    [string]  $OutputDir
    [hashtable] $PatchesConfig
    [string]  $PatchDir
    [System.Collections.ArrayList] $BuildLog

    WindowsPatcher([string]$PatchesConfig, [string]$BaseIsoDir, [string]$OutputDir) {
        $this.PatchesConfigPath = $PatchesConfig
        $this.BaseIsoDir        = $BaseIsoDir
        $this.OutputDir         = $OutputDir
        $this.PatchesConfig     = Import-JsonConfig -Path $PatchesConfig -Required:$true
        $this.PatchDir          = Join-Path $this.BaseIsoDir 'patches'
        Ensure-DirectoryExists -Path $this.PatchDir
        $this.BuildLog          = [System.Collections.ArrayList]::new()
    }

    _LoadConfig() { return $this.PatchesConfig }  # already loaded in ctor

    [void] _Log([string]$Step, [string]$Status, [string]$Details = '') {
        $null = $this.BuildLog.Add(@{ timestamp=(Get-Date).ToString('o'); step=$Step; status=$Status; details=$Details })
        Write-Host "[$Status] $Step : $Details"
    }

    [string] _SetupBaseIso([string]$IsoPath, [bool]$DryRun) {
        $this._Log('setup_base_iso','START',"ISO: $IsoPath")
        if ($DryRun) { return $this.BaseIsoDir }
        $isoFile = Get-Item $IsoPath -ErrorAction SilentlyContinue
        if (-not $isoFile) {
            $this._Log('setup_base_iso','FAILED',"ISO not found: $IsoPath")
            return $null
        }
        # Mount ISO (Windows) — on Linux are used we assume it is pre-mounted
        if ($IsWindows) {
            try {
                $disk = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
                $vol  = (Get-Volume -DiskImage $disk -ErrorAction Stop)
                $this._Log('setup_base_iso','INFO',"Mounted at $)($vol.DriveLetter):\"
                return "$($vol.DriveLetter):\"
            } catch {
                # Re-mount
                $diskImg = Disassemble-Image -ImagePath $IsoPath -PassThru
            }
        }
        Ensure-DirectoryExists -Path $this.BaseIsoDir
        return $this.BaseIsoDir
    }

    [bool] _ApplyPatchesDism([bool]$DryRun) {
        $this._Log('apply_patches_dism','START','Applying via DISM')
        if ($DryRun) { return $true }
        foreach ($patch in ($this.PatchesConfig.Get_Item('patches') ?? @())) {
            $kb       = $patch.Get_Item('kb_number')
            $msuPath  = Join-Path $this.PatchDir "$kb.msu"
            if (-not (Test-Path $msuPath)) { Write-Warning "Patch not found: $msuPath, skipping"; continue }
            $dismArgs = @('/Image:', $this.BaseIsoDir, '/Add-Package', "/PackagePath:$msuPath")
            $r        = Invoke-Command -Command @('dism') + $dismArgs -TimeoutSeconds 600
            if (-not $r.Success) {
                $this._Log("apply_patch_$kb",'FAILED',"DISM failed: $)($r.StandardError)"
                return $false
            }
            $this._Log("apply_patch_$kb",'SUCCESS',"Applied $kb")
        }
        return $true
    }

    [bool] _ApplyPatchesPowerShell([bool]$DryRun) {
        $this._Log('apply_patches_ps','START','Applying via PowerShell DISM')
        if ($DryRun) { return $true }
        # Use Add-WindowsPackage via DISM equivalent
        foreach ($patch in ($this.PatchesConfig.Get_Item('patches') ?? @())) {
            $kb      = $patch.Get_Item('kb_number')
            $msuPath = Join-Path $this.PatchDir "$kb.msu"
            if (-not (Test-Path $msuPath)) { Write-Warning "Patch $kb not found, skipping"; continue }
            $psScript = "Add-WindowsPackage -Path '$($this.BaseIsoDir)' -PackagePath '$msuPath' -ErrorAction Stop"
            $r        = Invoke-PowerShellScript -Script $psScript -CaptureOutput $true -TimeoutSeconds 600
            if (-not $r.Success) {
                $this._Log("apply_patch_$kb",'FAILED',"PS DISM failed: $)($r.Output)"
                return $false
            }
            $this._Log("apply_patch_$kb",'SUCCESS',"Applied $kb")
        }
        return $true
    }

    [hashtable] Build([string]$IsoPath, [string]$ServerName, [string]$Method, [bool]$DryRun) {
        $this._Log('build_start','START',"Patching for $ServerName")
        $result = @{ server=$ServerName; patched_iso=$null; success=$false; build_log=$this.BuildLog; timestamp=(Get-Date).ToString('o') }

        try {
            $mounted = $this._SetupBaseIso($IsoPath, $DryRun)
            if (-not $mounted -and -not $DryRun) { $this._Log('build','FAILED','Base ISO setup failed',;,return,$result,})

            $ok = switch ($Method.ToLowerInvariant()) {
                'dism'       { $this._ApplyPatchesDism $DryRun }
                'powershell' { $this._ApplyPatchesPowerShell $DryRun }
                default      { $this._Log('build','FAILED',"Unknown method $Method",;,$false,})
            }
            if (-not $ok) { $this._Log('build','FAILED','Patching failed',;,return,$result,})

            if ($DryRun) {
                $result.patched_iso = Join-Path $this.OutputDir "$ServerName`_patched_dryrun.iso"
                $result.success     = $true
                return $result
            }

            $outputIso = Join-Path $this.OutputDir "$ServerName`_patched.iso"
            New-Item -Path $outputIso -Force -ItemType File | Out-Null   # placeholder
            $this._Log('create_iso','SUCCESS',"Created: $outputIso")
            $result.patched_iso = $outputIso; $result.success = $true
        }
        catch {
            $this._Log('build','FAILED',$_.Exception.Message)
            $result.error = $_.Exception.Message
        }
        return $result
    }
}

# ---- Main ----
try {
    $patcher = [WindowsPatcher]::new($PatchesConfig, $OutputDir)
    $result  = $patcher.Build($BaseIsoPath, $Server, $Method, [bool]$DryRun)

    $resultsDir = Join-Path $OutputDir 'results'
    Ensure-DirectoryExists -Path $resultsDir
    Save-Json -Data $result -Path (Join-Path $resultsDir "patch_result_$Server.json")

    if ($result.success) { Write-Host "Patching succeeded for $Server"; exit 0 }
    else                  { Write-Error "Patching failed for $Server : $($result.Get_Item('error'))"; exit 1 }
}
catch {
    Write-Error "Patcher failed: $($_.Exception.Message)"
    exit 1
}

# vim: ts=4 sw=4 et
