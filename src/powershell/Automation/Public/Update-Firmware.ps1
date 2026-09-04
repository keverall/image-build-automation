#
# Public/Update-Firmware.ps1 - Apply HPE firmware from client-supplied folders (post-OS, via HPE SUT/SUM)
#
# Applied AFTER the OS image install (post-OS) so HPE Smart Update Tools (SUT) /
# Smart Update Manager (SUM) can run against the live, managed Windows OS. Each
# firmware folder supplied by the client is treated as an SUT/SUM repository and
# pushed to the target server over WinRM, where the HPE tool installs the latest
# BIOS / iLO / device firmware it finds.
#
# The firmware folders use the same path formats as the ISO (UNC/SMB, cifs://,
# smb://, https://, nfs://, mapped drive). For iLO mount the resolver emits a
# cifs:// URL; for SUT on the OS we convert that back to a UNC/path the OS can
# read directly.
#

function Update-Firmware {
    <#
    .SYNOPSIS
        Install HPE firmware from client-supplied folders on a built server (post-OS, via HPE SUT/SUM).

    .DESCRIPTION
        Connects to the freshly-built Windows server over WinRM and applies firmware
        from each supplied folder using HPE Smart Update Tools / Smart Update Manager.
        Designed to run as a step inside Start-PhysicalServerBuild after the OS install
        completes, but can also be invoked directly (e.g. via the 'update_firmware'
        request type) to remediate firmware on an already-built server.

    .PARAMETER FirmwareFolders
        One or more firmware component source locations (directories or .zip files)
        supplied by the client. Each is resolved to a path the target OS can read
        (UNC/SMB, cifs:// -> UNC, smb:// -> UNC, or passthrough for https:// / nfs://).

    .PARAMETER Server
        Target server hostname or IP (the installed OS, reachable over WinRM).

    .PARAMETER Credential
        PSCredential for WinRM to the installed OS. If omitted, resolved from
        OS_ADMIN_USER / OS_ADMIN_PASSWORD (env / CyberArk) or prompted interactively.

    .PARAMETER SutToolPath
        Override the HPE SUT/SUM tool path. Auto-detects SUM (preferred, accepts a
        -repository path) then SUT (sut.exe -s) when omitted.

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation (used by the orchestrator after APPROVE/-Deploy).

    .PARAMETER DryRun
        Print the resolved tool + repository plan without running anything.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.

    .PARAMETER Quiet
        Suppress the human-readable report.

    .RETURNS
        [hashtable] with Success (bool), Server, and FirmwareResults (per-folder
        {Folder, OsRepoPath, Tool, ExitCode, Output, Success}).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string[]] $FirmwareFolders,
        [Parameter(Mandatory)][string] $Server,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $SutToolPath,
        [Alias('SkipConf')]
        [switch] $SkipConfirmation,
        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )

    # ── Resolve OS credential ───────────────────────────────────────────────────
    if (-not $Credential) {
        $osUser = Get-EnvCredential -EnvVarName 'OS_ADMIN_USER' -Default ''
        $osPass = Get-EnvCredential -EnvVarName 'OS_ADMIN_PASSWORD' -Default ''
        if ($osUser -and $osPass) {
            $Credential = [System.Management.Automation.PSCredential]::new($osUser, (ConvertTo-SecureString $osPass -AsPlainText -Force))
        } elseif ([Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected) {
            $Credential = Get-Credential -Message "OS admin credentials for firmware (WinRM) on '$Server'"
        }
    }
    if (-not $Credential) {
        $result = @{ Success = $false; Server = $Server; Error = 'OS credential required for firmware step. Supply -Credential, or set OS_ADMIN_USER/OS_ADMIN_PASSWORD (env / CyberArk).' }
        return (_Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # ── Convert a normalized media path to one the target OS can read ────────────
    function ConvertTo-OsRepoPath([string]$p) {
        $p = $p.Trim().Trim('"', '''')
        if ($p -match '^cifs://') { return '\\' + $p.Substring('cifs://'.Length).Replace('/', '\') }
        if ($p -match '^smb://')  { return '\\' + $p.Substring('smb://'.Length).Replace('/', '\') }
        # UNC, https://, nfs:// and local paths pass through unchanged
        return $p
    }

    # ── Resolve + validate each folder (shared resolver rejects local drives) ────
    $folderResults = [ordered]@{}
    $overall = $true
    foreach ($fw in $FirmwareFolders) {
        $entry = [ordered]@{}
        try {
            $resolved = Resolve-ExternalIsoPath -IsoPath $fw
            $osRepo   = ConvertTo-OsRepoPath $resolved
            $entry['Folder']     = $fw
            $entry['OsRepoPath'] = $osRepo
            $entry['Resolved']   = $resolved
        } catch {
            $entry['Folder']  = $fw
            $entry['Success'] = $false
            $entry['Error']   = $_.Exception.Message
            $overall = $false
            $folderResults[$fw] = $entry
            continue
        }

        if ($DryRun) {
            $entry['Success'] = $true
            $entry['Tool']    = if ($SutToolPath) { $SutToolPath } else { 'SUM (auto-detected) / SUT (fallback)' }
            $entry['Output']  = "[DRY RUN] would apply firmware from: $($entry['OsRepoPath'])"
            $folderResults[$fw] = $entry
            continue
        }

        # ── Run HPE SUT/SUM on the target over WinRM ──────────────────────────
        $script = @'
param($Repo, $ToolPath)
$ErrorActionPreference = 'Continue'
if ($ToolPath) {
    if ($ToolPath -match '\.bat$') {
        $r = & cmd /c ("`"" + $ToolPath + "`" -action update -target node -repository `"" + $Repo + "`" -silence -allow_non_bundles 2>&1")
    } else {
        $r = & $ToolPath -action update -target node -repository $Repo -silence -allow_non_bundles 2>&1
    }
    $code = $LASTEXITCODE
} else {
    $sum = Get-ChildItem -Path 'C:\Program Files\HPE\SUM\bin\sum.bat','C:\Program Files (x86)\HPE\SUM\bin\sum.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sum) {
        $r = & cmd /c ("`"" + $sum.FullName + "`" -action update -target node -repository `"" + $Repo + "`" -silence -allow_non_bundles 2>&1")
        $code = $LASTEXITCODE
        $used = $sum.FullName
    } else {
        $sut = Get-ChildItem -Path 'C:\Program Files\HPE\SUT\sut.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sut) {
            $r = & $sut.FullName -s 2>&1
            $code = $LASTEXITCODE
            $used = $sut.FullName
        } else {
            $r = 'No HPE SUM/SUT tool found on target (expected C:\Program Files\HPE\SUM\bin\sum.bat or C:\Program Files\HPE\SUT\sut.exe)'
            $code = 99
            $used = $null
        }
    }
}
[PSCustomObject]@{ Output = ($r | Out-String); ExitCode = $code; Tool = $used } | ConvertTo-Json -Compress
'@
        try {
            $remote = Invoke-PowerShellWinRM -Script $script -Server $Server `
                -Username $Credential.UserName -Password $Credential.Password `
                -TimeoutSeconds 1800 -ArgumentList @($entry['OsRepoPath'], $SutToolPath)
            if (-not $remote.Success) {
                $entry['Success'] = $false
                $entry['Error']   = "WinRM to '$Server' failed: $($remote.Output)"
                $overall = $false
            } else {
                # Remote block emits a single-line JSON object; parse it back.
                $parsed = $remote.Output | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($parsed) {
                    $exitCode = [int]($parsed.ExitCode)
                    $entry['Tool']     = [string]$parsed.Tool
                    $entry['Output']   = [string]$parsed.Output
                    $entry['ExitCode'] = $exitCode
                    $entry['Success']  = ($exitCode -eq 0)
                    if ($exitCode -ne 0) { $overall = $false }
                } else {
                    $entry['Success'] = $false
                    $entry['Error']   = "Could not parse firmware tool output: $($remote.Output)"
                    $overall = $false
                }
            }
        } catch {
            $entry['Success'] = $false
            $entry['Error']   = $_.Exception.Message
            $overall = $false
        }
        $folderResults[$fw] = $entry
    }

    $result = @{
        Success         = $overall
        Server          = $Server
        FirmwareResults = $folderResults
    }
    return (_Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}

# vim: ts=4 sw=4 et
