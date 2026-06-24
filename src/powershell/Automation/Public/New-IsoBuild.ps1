#
# Public/New-IsoBuild.ps1 — ConfigMgr bootable media ISO builder
#
# Replaces the old DSC/DISM-based firmware+patching pipeline with the runbook's
# ConfigMgr bootable-media workflow.  Uses New-CMBootableMedia from the
# ConfigurationManager PowerShell module (auto-detected locally or via PSRemoting).
#
# Output naming per runbook:  WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso
#
# All ConfigMgr connection details are runtime parameters — no JSON config required.
#

function New-IsoBuild {
    <#
    .SYNOPSIS
        Build a ConfigMgr bootable media ISO (WinPE) for physical server deployment.
        Callable from the module Router.

    .DESCRIPTION
        Auto-detects a ConfigMgr PowerShell context (local module or PSRemoting
        to the site server) and invokes New-CMBootableMedia to produce a WinPE
        bootable ISO that can be mounted via iLO Redfish and used to run a task
        sequence against a freshly-racked HPE ProLiant server.

    .PARAMETER OutputPath
        Full path (including filename) for the output ISO.  When omitted a
        versioned filename is generated under the local output directory.

    .PARAMETER VersionMajor
        Major version number embedded in the filename (default 1).

    .PARAMETER VersionMinor
        Minor version number embedded in the filename (default 0).

    .PARAMETER SiteCode
        ConfigMgr site code (e.g. P01). Required.

    .PARAMETER ManagementPoint
        FQDN of the Management Point (e.g. mp01.ad.aib.pri). Required.

    .PARAMETER DistributionPoint
        FQDN of the Distribution Point (e.g. dp01.ad.aib.pri). Required.

    .PARAMETER BootImageName
        Name of the boot image to embed (e.g. 'WinPE x64 - HPE').

    .PARAMETER TaskSequenceName
        Optional task sequence name (informational; TS selection happens at boot).

    .PARAMETER SiteServer
        FQDN of the ConfigMgr site server for PSRemoting fallback (e.g. cm01.ad.aib.pri).

    .PARAMETER SiteServerUser
        Site server admin username for PSRemoting. Defaults to $env:CM_SITE_USER.

    .PARAMETER SiteServerPassword
        Site server admin password. Defaults to $env:CM_SITE_PASSWORD.

    .PARAMETER MediaPassword
        Optional boot media password (env: CM_MEDIA_PASSWORD).

    .PARAMETER AllowUnknownMachine
        Pass -AllowUnknownMachine to New-CMBootableMedia (default true).

    .PARAMETER AllowUnattended
        Pass -AllowUnattended to New-CMBootableMedia (default true).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER MockIso
        Create a 0-byte placeholder ISO without calling ConfigMgr (used by tests).

    .PARAMETER DryRun
        Validate inputs and print plan without creating the ISO.

    .RETURNS
        [hashtable] with Success, IsoPath, IsoUrl (if -RepoBaseUrl given), Metadata.

    .EXAMPLE
        New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp01.ad.aib.pri' `
            -DistributionPoint 'dp01.ad.aib.pri' -BootImageName 'WinPE x64 - HPE' `
            -SiteServer 'cm01.ad.aib.pri'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $OutputPath,
        [int]    $VersionMajor = 1,
        [int]    $VersionMinor = 0,
        [Parameter(Mandatory)][string] $SiteCode,
        [Parameter(Mandatory)][string] $ManagementPoint,
        [Parameter(Mandatory)][string] $DistributionPoint,
        [string] $BootImageName,
        [string] $TaskSequenceName,
        [string] $SiteServer,
        [string] $SiteServerUser,
        [string] $SiteServerPassword,
        [string] $MediaPassword,
        [bool]   $AllowUnknownMachine = $true,
        [bool]   $AllowUnattended = $true,
        [bool]   $SkipCertificateCheck = $true,
        [string] $MockIsoPath = $null,
        [switch] $DryRun
    )

    Initialize-Logging -LogFile 'iso_build.log'

    if (-not $OutputPath) {
        $projectRoot = Get-ProjectRoot
        $outDir = if ($projectRoot) { Join-Path $projectRoot 'output/bootable_media' } else { 'output/bootable_media' }
        Ensure-DirectoryExists -Path $outDir
        if ($VersionMajor -eq 1 -and $VersionMinor -eq 0) {
            $existing = Get-ChildItem $outDir -Filter 'WinSrv2025_HPE_BootableMedia_v*.iso' -ErrorAction SilentlyContinue |
                ForEach-Object { if ($_.BaseName -match '_v(\d+)\.(\d+)$') { [int]$Matches[1] * 1000 + [int]$Matches[2] } } |
                Sort-Object -Descending | Select-Object -First 1
            if ($existing) {
                $VersionMajor = [int][Math]::Floor($existing / 1000)
                $VersionMinor = [int]($existing % 1000) + 1
                Write-Host "Auto-incremented version to ${VersionMajor}.${VersionMinor}"
            }
        }
        $OutputPath = Join-Path $outDir "WinSrv2025_HPE_BootableMedia_v${VersionMajor}.${VersionMinor}.iso"
    }

    if (Test-Path $OutputPath -PathType Leaf) {
        Write-Warning "ISO already exists at $OutputPath — will be overwritten by New-CMBootableMedia."
    }

    $result = @{
        Success   = $false
        IsoPath   = $OutputPath
        Timestamp = Get-UtcTimestamp
        Metadata  = @{
            site_code        = $SiteCode
            management_point = $ManagementPoint
            distribution_point = $DistributionPoint
            boot_image       = $BootImageName
            task_sequence    = $TaskSequenceName
            version          = "${VersionMajor}.${VersionMinor}"
        }
    }

    if ($MockIsoPath) {
        Ensure-DirectoryExists -Path (Split-Path $OutputPath -Parent)
        if (-not (Test-Path $MockIsoPath)) { Set-Content -Path $MockIsoPath -Value 'MOCK' -Encoding UTF8 }
        Copy-Item -Path $MockIsoPath -Destination $OutputPath -Force
        $result.Success  = $true
        $result.Mocked   = $true
        $result.Metadata.bootable_iso = Split-Path $OutputPath -Leaf
        Save-Json -Data $result.Metadata -Path (Join-Path (Split-Path $OutputPath -Parent) 'deployment_metadata.json')
        return $result
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] New-IsoBuild → $OutputPath"
        $result.DryRun = $true
        $result.Success = $true
        return $result
    }

    try {
        $context = Resolve-ConfigMgrContext -SiteCode $SiteCode `
            -SiteServer $SiteServer `
            -SiteServerUser $SiteServerUser `
            -SiteServerPassword $SiteServerPassword `
            -SkipCertificateCheck $SkipCertificateCheck

        if (-not $context.Available) {
            $result.Error = $context.Error
            return $result
        }

        if ($context.Mode -eq 'Remote') {
            $script = {
                param($mp, $dp, $mp_pwd, $bi, $out, $aum, $au)
                $ErrorActionPreference = 'Stop'
                Import-Module ConfigurationManager
                if ((Get-PSDrive -Name $mp.Substring(0,2) -ErrorAction SilentlyContinue) -eq $null) {
                    New-PSDrive -Name $mp.Substring(0,2) -PSProvider 'AdminUI.PS.Provider\CMSite' -Root $mp -ErrorAction Stop | Out-Null
                }
                Push-Location (Get-PSDrive -Name $mp.Substring(0,2))
                try {
                    $bootImg = Get-CMBootImage -Name $bi -ErrorAction SilentlyContinue
                    if (-not $bootImg) { throw "Boot image '$bi' not found in site" }
                    New-CMBootableMedia -MediaMode Dynamic -MediaType CdDvd `
                        -Path $out `
                        -AllowUnknownMachine:$aum `
                        -AllowUnattended:$au `
                        -BootImage $bootImg `
                        -DistributionPoint $dp `
                        -ManagementPoint $mp
                } finally { Pop-Location }
            }
            $invokeArgs = @{
                ScriptBlock = $script
                ArgumentList = @($ManagementPoint, $DistributionPoint, $MediaPassword,
                                 $BootImageName, $OutputPath, $AllowUnknownMachine, $AllowUnattended)
                ErrorAction = 'Stop'
            }
            if ($context.PSSession) { $invokeArgs['Session'] = $context.PSSession }
            Invoke-Command @invokeArgs | Out-Null
        }
        else {
            Import-Module ConfigurationManager -ErrorAction Stop
            $siteDrive = $SiteCode + ':'
            if ((Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue) -eq $null) {
                New-PSDrive -Name $SiteCode -PSProvider 'AdminUI.PS.Provider\CMSite' `
                    -Root $ManagementPoint -ErrorAction Stop | Out-Null
            }
            Push-Location $siteDrive
            try {
                $bootImg = Get-CMBootImage -Name $BootImageName -ErrorAction Stop
                $cmArgs = @{
                    MediaMode = 'Dynamic'
                    MediaType = 'CdDvd'
                    Path      = $OutputPath
                    BootImage = $bootImg
                    DistributionPoint = $DistributionPoint
                    ManagementPoint   = $ManagementPoint
                }
                if ($AllowUnknownMachine) { $cmArgs['AllowUnknownMachine'] = $true }
                if ($AllowUnattended)     { $cmArgs['AllowUnattended']     = $true }
                if ($MediaPassword)       { $cmArgs['MediaPassword']       = $MediaPassword }
                New-CMBootableMedia @cmArgs -ErrorAction Stop
            } finally { Pop-Location }
        }

        if (-not (Test-Path $OutputPath -PathType Leaf)) {
            $result.Error = "New-CMBootableMedia reported success but ISO not found at $OutputPath"
            return $result
        }

        $result.Success  = $true
        $result.Metadata.bootable_iso = Split-Path $OutputPath -Leaf
        $result.Metadata.iso_size    = (Get-Item $OutputPath).Length

        $metaDir = Split-Path $OutputPath -Parent
        Save-Json -Data $result.Metadata -Path (Join-Path $metaDir 'deployment_metadata.json')

        return $result
    }
    catch {
        $result.Error = $_.Exception.Message
        return $result
    }
}

function Resolve-ConfigMgrContext {
    param(
        [Parameter(Mandatory)][string] $SiteCode,
        [string] $SiteServer,
        [string] $SiteServerUser,
        [string] $SiteServerPassword,
        [bool]   $SkipCertificateCheck = $true
    )
    $r = [ordered]@{ Available = $false; Mode = $null; PSSession = $null; Credential = $null; Error = $null }
    if (Get-Module -ListAvailable -Name ConfigurationManager -ErrorAction SilentlyContinue) {
        $r.Available = $true
        $r.Mode = 'Local'
        return $r
    }
    if (-not $SiteServer) {
        $r.Error = "ConfigurationManager module not available locally and -SiteServer not provided"
        return $r
    }
    if (-not $SiteServerUser)     { $SiteServerUser     = [System.Environment]::GetEnvironmentVariable('CM_SITE_USER') }
    if (-not $SiteServerPassword) { $SiteServerPassword = [System.Environment]::GetEnvironmentVariable('CM_SITE_PASSWORD') }
    $cred = $null
    if ($SiteServerUser -and $SiteServerPassword) {
        $cred = New-Object System.Management.Automation.PSCredential(
            $SiteServerUser, (ConvertTo-SecureString $SiteServerPassword -AsPlainText -Force))
    }
    try {
        $opts = New-PSSessionOption -SkipCACheck -SkipCNCheck:$SkipCertificateCheck -OpenTimeout 30000
        $sess = New-PSSession -ComputerName $SiteServer -Credential $cred -Authentication Negotiate `
            -SessionOption $opts -ErrorAction Stop
        $r.Available  = $true
        $r.Mode       = 'Remote'
        $r.PSSession  = $sess
        return $r
    } catch {
        $r.Error = "PSRemoting to $SiteServer failed: $($_.Exception.Message)"
        return $r
    }
    finally {
        if ($cred) { $cred = $null }
    }
}

# vim: ts=4 sw=4 et
