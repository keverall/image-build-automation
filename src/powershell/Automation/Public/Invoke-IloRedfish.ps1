#
# Public/Invoke-IloRedfish.ps1 - iLO Redfish API integration
#
# Provides full Redfish implementation for virtual media mount + one-time boot
# + system reset, replacing the iLO REST scaffold that lived in Invoke-IsoDeploy.
#
# All Redfish calls reuse:
#   - -IloUser/-IloPassword parameters or interactive prompt (never config/env)
#   - Invoke-RestMethod -SkipCertificateCheck  (iLO ships with self-signed cert)
#
# Redfish vs iLO REST:
#   Redfish:   POST /redfish/v1/SessionService/Sessions  (basic auth → X-Auth-Token)
#              POST /redfish/v1/Managers/1/VirtualMedia/1/Actions/VirtualMedia.InsertMedia
#              PATCH /redfish/v1/Systems/1  (BootSourceOverrideTarget=Cd, Enabled=Once)
#              POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset  (ResetType=ForceRestart)
#   iLO REST:  POST /rest/v1/sessions  (X-Redfish-Session header)
#

function Invoke-IloRedfish {
    <#
    .SYNOPSIS
        Mount, boot, reset, or eject virtual media on an iLO 5/6 Redfish endpoint.
        Callable from the module Router.

    .DESCRIPTION
        Implements the iLO Redfish virtual-media workflow:
            * Session login (basic auth → X-Auth-Token)
            * Insert / Eject virtual media (CD/DVD)
            * One-time boot override to CD
            * System reset (ForceRestart)
        Operates against a single iLO IP. Connection details are runtime
        parameters - no JSON config required.

    .PARAMETER Action
        Operation to perform. One of: Mount, MountAndBoot, Boot, Reset, Eject, Status.

    .PARAMETER IloIp
        iLO IPv4 address or hostname. Required.

    .PARAMETER IloUser
        iLO username. If omitted on a live run, prompted interactively. Never
        read from config or environment.

    .PARAMETER IloPassword
        iLO password. If omitted on a live run, prompted interactively (secure
        input). Never read from config or environment.

    .PARAMETER IsoUrl
        HTTPS URL to the ISO file (required for Mount / MountAndBoot).

    .PARAMETER CdDeviceId
        VirtualMedia device id (default 1). Enumerate via /redfish/v1/Managers/1/VirtualMedia.

    .PARAMETER Force
        Required for destructive actions (MountAndBoot, Boot, Reset) to confirm intent.
        Read-only actions (Status, Eject without -Force) do not require this switch.

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true - iLO uses self-signed certs).

    .PARAMETER TimeoutSec
        Per-call timeout (default 30 s).

    .PARAMETER DryRun
        Print actions without performing them.

    .RETURNS
        [hashtable] with Success, Action, Details.

    .EXAMPLE
        Invoke-IloRedfish -Action MountAndBoot -IloIp 192.168.1.101 `
            -IsoUrl 'https://artifacts.internal.example.com/isos/WinSrv2025_BootableMedia_v1.0.iso'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][ValidateSet('Mount','MountAndBoot','Boot','Reset','Eject','Status')][string] $Action,
        [Parameter(Mandatory)][string] $IloIp,
        [string] $IloUser  = $null,
        [string] $IloPassword = $null,
        [string] $IsoUrl = $null,
        [int]    $CdDeviceId = 1,
        [bool]   $SkipCertificateCheck = $true,
        [int]    $TimeoutSec = 30,
        [switch] $Force,
        [switch] $DryRun
    )

    $destructiveActions = @('MountAndBoot','Boot','Reset')
    if ($Action -in $destructiveActions -and -not $Force -and -not $DryRun) {
        return @{
            Success = $false; Action = $Action; IloIp = $IloIp
            Error   = "Action '$Action' is destructive and requires -Force (or -DryRun). Use -Force to confirm intent."
        }
    }

    try {
        if ($DryRun) {
            Write-Output "[DRY RUN] Invoke-IloRedfish Action=$Action Ilo=$IloIp Iso=$IsoUrl"
            return @{
                Success  = $true
                Action   = $Action
                Details  = '[DRY RUN] no Redfish calls issued'
                IloIp    = $IloIp
            }
        }

        # TERMINAL COMMAND: iLO credentials come ONLY from -IloUser/-IloPassword
        # or a direct interactive prompt. Never from config, environment, or
        # CyberArk (pipeline-only; see AGENTS.md).
        if (-not $IloUser -or -not $IloPassword) {
            $canPrompt = ([System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -ne 'true') -and
                [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected
            if ($canPrompt) {
                if (-not $IloUser) {
                    Write-Host "Enter iLO username for '$IloIp': " -ForegroundColor Yellow -NoNewline
                    $IloUser = Read-Host
                }
                if ($IloUser -and -not $IloPassword) {
                    $securePass = Read-Host "Enter iLO password for '$IloIp': " -AsSecureString
                    $IloPassword = [System.Net.NetworkCredential]::new('', $securePass).Password
                }
            }
            if (-not $IloUser -or -not $IloPassword) {
                return @{
                    Success = $false; Action = $Action; IloIp = $IloIp
                    Error   = "iLO credentials required. Supply -IloUser and -IloPassword, or run interactively to be prompted. Terminal commands never read credentials from config or environment."
                }
            }
        }

        $baseUrl = "https://$IloIp/redfish/v1"
        $session = [IloRedfishSession]::new($baseUrl, $IloUser, $IloPassword, $SkipCertificateCheck, $TimeoutSec)

        try {
            switch ($Action) {
                'Mount' {
                    if (-not $IsoUrl) { throw "Mount requires -IsoUrl" }
                    $r = $session.InsertMedia($CdDeviceId, $IsoUrl)
                    return @{ Success = $true; Action = $Action; IloIp = $IloIp; Details = $r }
                }
                'MountAndBoot' {
                    if (-not $IsoUrl) { throw "MountAndBoot requires -IsoUrl" }
                    $null = $session.InsertMedia($CdDeviceId, $IsoUrl)
                    $null = $session.SetOneTimeBootCd()
                    $null = $session.ResetSystem('ForceRestart')
                    return @{ Success = $true; Action = $Action; IloIp = $IloIp; Details = 'Media inserted, one-time boot CD set, ForceRestart issued' }
                }
                'Boot' {
                    $null = $session.SetOneTimeBootCd()
                    $null = $session.ResetSystem('ForceRestart')
                    return @{ Success = $true; Action = $Action; IloIp = $IloIp; Details = 'One-time boot CD set, ForceRestart issued' }
                }
                'Reset' {
                    $null = $session.ResetSystem('ForceRestart')
                    return @{ Success = $true; Action = $Action; IloIp = $IloIp; Details = 'ForceRestart issued' }
                }
                'Eject' {
                    $r = $session.EjectMedia($CdDeviceId)
                    return @{ Success = $true; Action = $Action; IloIp = $IloIp; Details = $r }
                }
                'Status' {
                    $sys = $session.GetSystem()
                    $vm  = $session.ListVirtualMedia()
                    $result = @{
                        Success = $true
                        Action  = $Action
                        IloIp   = $IloIp
                        Details = @{ system = $sys; virtual_media = $vm }
                    }
                    _Format-IloRedfishResult -Result $result
                    return $result
                }
            }
        }
        finally {
            $session.Logout()
        }
    }
    catch {
        return @{ Success = $false; Action = $Action; IloIp = $IloIp; Error = $_.Exception.Message }
    }
}

# IloRedfishSession class is defined in Automation.psm1 (root module)
# so the type is available at module-load time.

function _Format-IloRedfishResult {
    param([hashtable]$Result)

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  iLO Redfish - $($Result.Action)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  iLO IP:    $($Result.IloIp)" -ForegroundColor White
    Write-Host "  Success:   $($Result.Success)" -ForegroundColor $(if ($Result.Success) { 'Green' } else { 'Red' })

    if ($Result.Error) {
        Write-Host "  Error:     $($Result.Error)" -ForegroundColor Red
    }

    if ($Result.Details -is [hashtable] -and $Result.Details.system) {
        $sys = $Result.Details.system
        $vm  = $Result.Details.virtual_media
        Write-Host ""
        Write-Host "  --- System ---" -ForegroundColor Yellow
        if ($sys.Name) { Write-Host "    Name:          $($sys.Name)" }
        if ($sys.Manufacturer) { Write-Host "    Manufacturer:  $($sys.Manufacturer)" }
        if ($sys.Model) { Write-Host "    Model:         $($sys.Model)" }
        if ($sys.SerialNumber) { Write-Host "    Serial:        $($sys.SerialNumber)" }
        if ($sys.PowerState) { Write-Host "    Power State:   $($sys.PowerState)" -ForegroundColor $(if ($sys.PowerState -eq 'On') { 'Green' } else { 'Yellow' }) }
        if ($sys.Status -and $sys.Status.Health) { Write-Host "    Health:        $($sys.Status.Health)" -ForegroundColor $(if ($sys.Status.Health -eq 'OK') { 'Green' } else { 'Yellow' }) }
        if ($sys.BiosVersion) { Write-Host "    BIOS:          $($sys.BiosVersion)" }

        if ($vm) {
            Write-Host ""
            Write-Host "  --- Virtual Media ---" -ForegroundColor Yellow
            $vmItems = if ($vm -is [array]) { $vm } else { @($vm) }
            foreach ($v in $vmItems) {
                $id = if ($v.Id) { $v.Id } elseif ($v.Name) { $v.Name } else { 'unknown' }
                $inserted = if ($v.Inserted) { 'Yes' } else { 'No' }
                $image = if ($v.Image) { $v.Image } else { '-' }
                Write-Host "    Device $id`:  Inserted=$inserted" -ForegroundColor $(if ($v.Inserted) { 'Green' } else { 'Gray' })
                if ($v.Image) { Write-Host "      Image: $image" }
            }
        }
    } elseif ($Result.Details -is [string]) {
        Write-Host "  Details:   $($Result.Details)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# vim: ts=4 sw=4 et
