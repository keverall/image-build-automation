<#
.SYNOPSIS
    Setup-Runner.ps1 - PowerShell runner environment setup.

.DESCRIPTION
    Offline-only, non-destructive setup script that verifies required PowerShell modules
    (Pester, PSScriptAnalyzer, PlatyPS) and binary tools (Oh My Posh, GNU make,
    checkmake). Bundled copies live in scripts/modules/ and are imported by
    explicit manifest path. Missing or unusable dependencies are reported without
    deleting packages or attempting Internet downloads.

.EXAMPLE
    pwsh -File scripts/setup-runner.ps1
#>

# =============================================================================
# HPE ProLiant Windows Server ISO Automation - PowerShell Runner Setup
# =============================================================================
# Offline-only. Never delete a dependency or attempt an Internet download.
# =============================================================================

using namespace System

# ── Configuration ────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'
$PROJECT_ROOT    = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$LOG_FILE        = Join-Path (${env:TEMP} ?? '/tmp') "hpe-automation-pwsh-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$VENDOR_MODULES_DIR = Join-Path $PSScriptRoot 'modules'
$TEMP_MODULES_DIR   = Join-Path $PROJECT_ROOT 'temp-modules'
$BIN_DIR            = Join-Path $PROJECT_ROOT 'bin'

# Bundled module manifest - name + minimum version (version is the *requested*
# floor; the actual installed version may be higher for modules like
# OperationsManager that ship with SCOM in arbitrary versions).
$REQUIRED_MODULES = @(
    @{ Name = 'Pester';           Version = '6.0.1' },
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' },
    @{ Name = 'PlatyPS';          Version = '0.14.0' },
    @{ Name = 'HPEOneView.1000';   Version = '10.00' },
    # HPE's Get-OVIloSso -IloRestSession object is designed for this module.
    # The official OneView virtual-media automation uses HPRESTCmdlets for
    # iLO REST/SSO operations rather than reimplementing the session client.
    @{ Name = 'HPRESTCmdlets';     Version = '1.2.0.0'; WindowsOnly = $true; OfflineOnly = $true },
    @{ Name = 'OperationsManager';Version = '1.0'; WindowsOnly = $true }   # installed with SCOM; real versions are 10.x
)

# Colours (ANSI - works in all hosts that support colour)
$C_RESET  = "`e[0m"
$C_CYAN   = "`e[36m"
$C_GREEN  = "`e[32m"
$C_YELLOW = "`e[33m"
$C_RED    = "`e[31m"

# ── Log helpers ──────────────────────────────────────────────────────────────
function _WL {
    <#
    .SYNOPSIS
        Internal log writer used by the setup-runner log helpers.
    #>
 param($tag, $colour, $msg)
    Write-Output "${colour}${tag}${C_RESET} $msg"
    Add-Content $LOG_FILE "${tag} $msg" }
function Write-Log  {
    <#
    .SYNOPSIS
        Writes log.
    #>
 param($m) _WL '[INFO]'  $C_CYAN   $m }
function Write-OK   {
    <#
    .SYNOPSIS
        Writes ok.
    #>
 param($m) _WL '[OK]'    $C_GREEN  $m }
function Write-Warn {
    <#
    .SYNOPSIS
        Writes warn.
    #>
 param($m) _WL '[WARN]'  $C_YELLOW $m }
function Write-Err  {
    <#
    .SYNOPSIS
        Writes err.
    #>
 param($m) _WL '[ERROR]' $C_RED    $m }

# ── Utility: user PS module path (OS-aware) ─────────────────────────────────
function Get-UserModulePath {
    <#
    .SYNOPSIS
        Gets user module path.
    #>

    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
    $base  = if ($isWin) { [Environment]::GetFolderPath('MyDocuments') } else { $HOME }
    $rel   = if ($isWin) { 'PowerShell\Modules' }         else { '.local/share/powershell/Modules' }
    return Join-Path $base $rel
}

# ── Utility: add directory to session + persistent user PATH ─────────────────
function Ensure-OfflineModulePath {
    <#
    .SYNOPSIS
        Makes the repository's bundled PowerShell modules available automatically.

    .DESCRIPTION
        Adds scripts/modules to the current and persistent user PSModulePath. This
        is required on regulated/offline Windows hosts where PSGallery is unavailable.
        Import verification is performed separately, using explicit manifest paths.
    #>
    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or
        $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    $moduleRoot = (Resolve-Path $VENDOR_MODULES_DIR).Path
    $separator = [IO.Path]::PathSeparator
    $entries = @($env:PSModulePath -split [regex]::Escape($separator) | Where-Object { $_ })
    if ($entries.Count -eq 0 -or $entries[0] -ne $moduleRoot) {
        $env:PSModulePath = (@($moduleRoot) + @($entries | Where-Object { $_ -ne $moduleRoot })) -join $separator
        Write-OK "Added offline module path for this session: $moduleRoot"
    }
    if ($isWin) {
        $userPath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
        $userEntries = @($userPath -split [regex]::Escape($separator) | Where-Object { $_ })
        if ($userEntries.Count -eq 0 -or $userEntries[0] -ne $moduleRoot) {
            $newUserPath = (@($moduleRoot) + @($userEntries | Where-Object { $_ -ne $moduleRoot })) -join $separator
            [Environment]::SetEnvironmentVariable('PSModulePath', $newUserPath, 'User')
            Write-OK "Persisted offline module path for future sessions: $moduleRoot"
        }
    }
}

function Add-BinToPath {
    <#
    .SYNOPSIS
        Adds bin to path.
    #>

    param([string]$Dir)
    if ($env:PATH -notlike "*$Dir*") { $env:PATH = "$Dir;$env:PATH" }
    $persisted = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($persisted -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable('PATH', "$Dir;$persisted", 'User')
        Write-Log "Added $Dir to user PATH (persistent)"
    }
}

# =============================================================================
# PREREQUISITES
# =============================================================================

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests power shell version.
    #>

    $v = $PSVersionTable.PSVersion
    if ($v.Major -lt 7) {
        Write-Err "PowerShell 7+ required. Current: $($v.ToString())"
        Write-Err "Install via: winget install Microsoft.PowerShell  ·  brew install pwsh"
        exit 1
    }
    Write-OK "PowerShell $($v.ToString())"
}

# =============================================================================
# MODULE VERIFICATION (local manifests only; no removal or downloads)
# =============================================================================

function Get-BundledModulePath {
    <#
    .SYNOPSIS
        Gets bundled module path.
    #>

    param([string]$Name, [string]$Version)

    $parent = Get-ChildItem -Path $VENDOR_MODULES_DIR -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if (-not $parent) { return $null }

    # Helper: resolve highest version from a directory containing version sub-dirs
    function _HighestVersion([string]$Dir) {
        Get-ChildItem -Path $Dir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1
    }

    # Layout A (canonical): scripts/modules/<Name>/<version>/
    $exact = Join-Path $parent.FullName $Version
    if (Test-Path $exact) { return @{ Path = $exact; ActualVersion = $Version } }

    $highest = _HighestVersion $parent.FullName
    if ($highest) {
        Write-Warn "Exact version $Version of $Name not found. Using $($highest.Name)."
        return @{ Path = $highest.FullName; ActualVersion = $highest.Name }
    }

    # Layout B (legacy nesting): Save-Module into <Name>/ subfolder creates
    #   scripts/modules/<Name>/<Name>/<version>/  - handle for backwards compat.
    $inner = Get-ChildItem -Path $parent.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if ($inner) {
        $innerExact = Join-Path $inner.FullName $Version
        if (Test-Path $innerExact) { return @{ Path = $innerExact; ActualVersion = $Version } }
        $innerHighest = _HighestVersion $inner.FullName
        if ($innerHighest) {
            Write-Warn "Exact version $Version of $Name not found (nested layout). Using $($innerHighest.Name)."
            return @{ Path = $innerHighest.FullName; ActualVersion = $innerHighest.Name }
        }
    }
    return $null
}

function Repair-TempModulesDirectory {
    <#
    .SYNOPSIS
        Repairs temp modules directory.
    #>

    if (-not (Test-Path $TEMP_MODULES_DIR -PathType Container)) { return }

    Write-Warn "Found legacy temp-modules directory; preserving originals and copying only absent module directories"
    New-Item -ItemType Directory -Force -Path $VENDOR_MODULES_DIR | Out-Null

    foreach ($module in Get-ChildItem -Path $TEMP_MODULES_DIR -Directory -ErrorAction SilentlyContinue) {
        $dest = Join-Path $VENDOR_MODULES_DIR $module.Name
        if (Test-Path $dest) {
            Write-Log "Existing $dest retained; legacy copy $($module.FullName) also retained"
            continue
        }

        Write-Log "Copying $($module.FullName) -> $dest (source retained)"
        Copy-Item -LiteralPath $module.FullName -Destination $dest -Recurse -ErrorAction Stop
    }
}

function Test-ModuleImportIsolated {
    <#
    .SYNOPSIS
        Tests a module import in a short-lived PowerShell process.

    .DESCRIPTION
        Some Windows PowerShell modules load native/.NET assemblies during
        Import-Module. Verify in a child process without locking assemblies in
        setup or misclassifying runtime/permission/license errors as corruption.
        No module directory is removed or overwritten when an import fails.
    #>

    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][version]$Version,
        [Parameter(Mandatory)][string]$ManifestPath
    )

    $pwsh = Join-Path $PSHOME 'pwsh.exe'
    if (-not (Test-Path $pwsh)) { $pwsh = (Get-Command pwsh -ErrorAction Stop).Source }

    $quotedPath = $ManifestPath.Replace("'", "''")
    $command = "`$ErrorActionPreference = 'Stop'; Import-Module -Name '$quotedPath' -ErrorAction Stop -WarningAction SilentlyContinue"
    $requiredCommands = switch ($Name) {
        'HPEOneView.1000' { @('Get-OVServer', 'Get-OVIloSso') }
        'HPRESTCmdlets' { @('Connect-HPREST', 'Get-HPRESTDataRaw') }
        default { @() }
    }
    foreach ($requiredCommand in $requiredCommands) {
        $command += "; Get-Command '$requiredCommand' -Module '$Name' -ErrorAction Stop | Out-Null"
    }
    if ($Name -in @('HPEOneView.1000', 'HPRESTCmdlets')) {
        $importer = (Join-Path $PSScriptRoot 'Import-OfflineHpeModules.ps1').Replace("'", "''")
        $commandList = ($requiredCommands | ForEach-Object { "'$_'" }) -join ', '
        $command = "`$ErrorActionPreference = 'Stop'; . '$importer' -Name @(); Import-OfflineHpeModule -ModuleName '$Name' -ManifestPath '$quotedPath' -ExpectedVersion '$Version' -RequiredCommands @($commandList)"
    }
    $details = & $pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Local import failed for $Name $Version from '$ManifestPath'. Files were preserved. Import error: $($details -join [Environment]::NewLine)"
    }
    return $true
}

function Install-RequiredModule {
    <#
    .SYNOPSIS
        Installs required module.
    #>

    param([string]$Name, [string]$Version)

    # Always select the approved repository copy before any stale user installation.
    $bundled = Get-BundledModulePath -Name $Name -Version $Version
    if ($bundled) {
        $manifest = Get-ChildItem -LiteralPath $bundled.Path -Filter '*.psd1' -File -ErrorAction Stop |
            Where-Object { $_.BaseName -ieq $Name } | Select-Object -First 1
        if (-not $manifest) {
            throw "Bundled $Name at '$($bundled.Path)' has no matching module manifest. Files were preserved; restore the complete approved package through Git. No download was attempted."
        }
        $metadata = Import-PowerShellDataFile -LiteralPath $manifest.FullName -ErrorAction Stop
        if ([version]$metadata.ModuleVersion -lt [version]$Version) {
            throw "Bundled $Name version $($metadata.ModuleVersion) is older than required $Version. Files were preserved; supply the approved package offline."
        }
        $null = Test-ModuleImportIsolated -Name $Name -Version $metadata.ModuleVersion -ManifestPath $manifest.FullName
        Write-OK "$Name $($metadata.ModuleVersion) verified from local manifest: $($manifest.FullName)"
        return
    }

    # An existing local installation (for example SCOM) is acceptable, but must
    # never be removed merely because Import-Module fails in this runtime.
    $existing = Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($existing -and $existing.Version -ge [version]$Version) {
        $null = Test-ModuleImportIsolated -Name $Name -Version $existing.Version -ManifestPath $existing.Path
        Write-OK "$Name $($existing.Version) verified from existing local installation"
        return
    }
    throw "Offline setup cannot find $Name $Version or newer. Supply the complete approved package in scripts/modules/$Name/<version>/ through Git or install it through your approved offline process. No files were deleted and no download was attempted."
}

function Install-RequiredModules {
    <#
    .SYNOPSIS
        Installs required modules.
    #>

    Write-Log "Verifying local PowerShell modules (offline; files are preserved)…"
    $onWindows = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or
        $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    foreach ($m in $REQUIRED_MODULES) {
        if ($m.WindowsOnly -and -not $onWindows) {
            Write-Log "Skipping Windows-only module $($m.Name) on this platform"
            continue
        }
        if ($m.OfflineOnly -and -not (Get-BundledModulePath -Name $m.Name -Version $m.Version)) {
            throw "Offline-required module $($m.Name) $($m.Version) is missing from scripts/modules/$($m.Name)/$($m.Version). Copy the approved package into the repository before running setup."
        }
        Install-RequiredModule -Name $m.Name -Version $m.Version
    }
}

# =============================================================================
# BINARY TOOLS (Oh My Posh, GNU make, checkmake)
# =============================================================================

# Generic helper: locate a binary in the project bin/ dir or system PATH.
# If found, ensures it's on PATH (both session and persistent).  Returns $true.
# Guards against Windows App Execution Aliases (real exes must have a Source path).
function Find-LocalBinary {
    <#
    .SYNOPSIS
        Finds local binary.
    #>

    param([string]$BinaryName)            # e.g. 'checkmake.exe'
    # 1. Project bin/ (most reliable - avoids Windows app-picker stubs)
    $binPath = Join-Path $BIN_DIR $BinaryName
    if (Test-Path $binPath) {
        $fileSize = (Get-Item $binPath).Length
        if ($fileSize -gt 0) {
            Add-BinToPath -Dir $BIN_DIR
            return $true
        }
    }
    # 2. System PATH - but only if it resolves to a real executable
    $cmd = Get-Command $BinaryName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and $cmd.Source -ne '') { return $true }
    return $false
}

function Install-OhMyPosh {
    <#
    .SYNOPSIS
        Installs oh my posh.
    #>

    $bin = 'oh-my-posh.exe'
    if (Find-LocalBinary -BinaryName $bin) {
        $src = Join-Path $BIN_DIR $bin
        if (Test-Path $src) {
            $destDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'bin'
            $dest    = Join-Path $destDir $bin
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                Copy-Item -Path $src -Destination $dest -Force
                Write-OK "Oh My Posh installed to $dest"
            }
        }
        return
    }
    Write-Warn "Oh My Posh binary not found in bin/. Skipping."
    Write-Warn "If .exe execution is blocked (AppLocker etc.), add oh-my-posh.exe to bin/ or use a pure-PS profile prompt."
}

function Install-Make {
    <#
    .SYNOPSIS
        Installs make.
    #>

    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or
             $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    if (-not $isWin) { Write-Log "Non-Windows platform - skipping make detection"; return }

    if (Find-LocalBinary -BinaryName 'make.exe') {
        Write-OK "make: $((make --version 2>$null | Select-Object -First 1))"
        return
    }

    # Search known Git-for-Windows install locations
    $candidates = @(
        'C:\Program Files\Git\usr\bin\make.exe',
        'C:\Program Files (x86)\Git\usr\bin\make.exe',
        'C:\Program Files\Git\mingw64\bin\make.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) {
            Add-BinToPath -Dir (Split-Path $p)
            Write-OK "make available from Git for Windows"
            return
        }
    }

    Write-Warn "make not found. Install Git for Windows or place make.exe in $BIN_DIR"
}

function Test-ValidExecutable {
    <#
    .SYNOPSIS
        Tests valid executable.
    #>

    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $size = (Get-Item $Path).Length
    if ($size -lt 4) { return $false }
    $bytes = [byte[]]::new(4)
    try {
        $stream = [IO.File]::OpenRead($Path)
        try { $stream.Read($bytes, 0, 4) | Out-Null } finally { $stream.Close() }
    } catch { return $false }
    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
    if ($isWin) {
        return ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A)   # PE: MZ
    } else {
        return ($bytes[0] -eq 0x7F -and $bytes[1] -eq 0x45 -and
                $bytes[2] -eq 0x4C -and $bytes[3] -eq 0x46)    # ELF: \x7fELF
    }
}

function Install-Checkmake {
    <#
    .SYNOPSIS
        Installs checkmake.
    #>

    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
    $exe   = if ($isWin) { 'checkmake.exe' } else { 'checkmake' }
    $dest  = Join-Path $BIN_DIR $exe

    if (Find-LocalBinary -BinaryName $exe) {
        $candidate = if (Test-Path -LiteralPath $dest) { $dest } else { (Get-Command $exe -ErrorAction Stop).Source }
        if (Test-ValidExecutable -Path $candidate) {
            Write-OK "checkmake found"
            return
        }
        Write-Warn "checkmake at '$candidate' is not valid for this platform. File retained; supply an approved executable offline."
        return
    }
    Write-Warn "Optional checkmake not found. Supply an approved executable at '$dest' offline. No download was attempted."
}

# =============================================================================
# SUMMARY + MAIN
# =============================================================================

function Show-Summary {
    <#
    .SYNOPSIS
        Shows summary.
    #>

    $onWindows = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or
        $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    $ok = ($REQUIRED_MODULES | ForEach-Object {
        if ($_.WindowsOnly -and -not $onWindows) {
            [pscustomobject]@{ Name = $_.Name; Version = 'SKIPPED (Windows-only)'; Skipped = $true }
            return
        }
        $m = Get-Module $_.Name -ListAvailable -ErrorAction SilentlyContinue |
             Sort-Object Version -Descending | Select-Object -First 1
        [pscustomobject]@{ Name = $_.Name; Version = if ($m) { $m.Version } else { '- MISSING' }; Skipped = $false }
    })
    Write-Output ""
    Write-Output "${C_GREEN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    Write-Output "${C_GREEN}║  ${C_CYAN}HPE ProLiant ISO Automation - Setup Complete${C_GREEN}         ║${C_RESET}"
    Write-Output "${C_GREEN}╚══════════════════════════════════════════════════════╝${C_RESET}"
    Write-Output ""
    foreach ($item in $ok) {
        $icon = if ($item.Skipped) { "${C_YELLOW}-${C_RESET}" } elseif ($item.Version -eq '- MISSING') { "${C_RED}✗${C_RESET}" } else { "${C_GREEN}✓${C_RESET}" }
        Write-Output "  $icon $($item.Name) $($item.Version)"
    }
    Write-Output ""
    Write-Output "  Log file : $LOG_FILE"
    Write-Output "  Tests    : make test"
    Write-Output "  Lint     : make lint"
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        Write-Output "  ${C_YELLOW}make not installed - run scripts directly:${C_RESET} pwsh -File scripts/run-tests.ps1"
    }
}

function Main {
    <#
    .SYNOPSIS
        Main entry point for the setup-runner script.
    #>

    Write-Output ""
    Write-Output "${C_CYAN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    Write-Output "${C_CYAN}║  HPE ProLiant ISO Automation - PowerShell Setup     ║${C_RESET}"
    Write-Output "${C_CYAN}╚══════════════════════════════════════════════════════╝${C_RESET}"
    Write-Output ""
    Test-PowerShellVersion
    Repair-TempModulesDirectory
    Ensure-OfflineModulePath
    Install-RequiredModules
    Install-OhMyPosh
    Install-Make
    Install-Checkmake
    Show-Summary
    Write-OK 'Setup complete'
}

Main
