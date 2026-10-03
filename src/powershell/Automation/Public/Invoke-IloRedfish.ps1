#
# Public/Invoke-IloRedfish.ps1 - iLO Redfish API integration
#
# Provides full Redfish implementation for virtual media mount + one-time boot
# + system reset, replacing the iLO REST scaffold that lived in Invoke-IsoDeploy.
#
# OneView-managed servers use the OneView-generated iLO SSO token. Direct iLO
# PSCredential is supported only for unmanaged-server fallback; no password prompt
# or plain-text password parameters are used.
# All Redfish calls reuse Invoke-RestMethod -SkipCertificateCheck.
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

    .PARAMETER IloCredential
        Direct iLO PSCredential fallback for unmanaged servers only. Managed
        OneView servers use OneView iLO SSO instead.

    .PARAMETER OneViewHost
        OneView appliance associated with the active OneView session.

    .PARAMETER OneViewServerName
        Resolved OneView server-hardware name used to obtain the iLO SSO token.

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
        [Parameter(Mandatory, ParameterSetName = 'Run')][ValidateSet('Mount','MountAndBoot','Boot','Reset','Eject','Status')][string] $Action,
        [Alias('Ilo')]
        [Parameter(Mandatory, ParameterSetName = 'Run')][string] $IloIp,
        [System.Management.Automation.PSCredential] $IloCredential,
        [string] $OneViewHost,
        [string] $OneViewServerName,
        [Alias('Iso')]
        [string] $IsoUrl = $null,
        [int]    $CdDeviceId = 1,
        [Alias('SkipCert')]
        [bool]   $SkipCertificateCheck = $true,
        [Alias('Timeout')]
        [int]    $TimeoutSec = 30,
        [switch] $Force,
        [Alias('Dry')]
        [switch] $DryRun,
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Invoke-IloRedfish'; return }

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

        # OneView-managed servers normally use OneView iLO SSO. If the HPE
        # OneView module is unavailable, an explicitly supplied direct iLO
        # credential is a supported fallback. Never silently reuse a OneView
        # credential as an iLO credential because they are separate auth domains.
        $hasOneViewSso = $OneViewHost -and $OneViewServerName -and
            (Get-Command Get-OVServer -ErrorAction SilentlyContinue) -and
            (Get-Command Get-OVIloSso -ErrorAction SilentlyContinue)
        if ($hasOneViewSso -and -not $IloCredential) {
            try {
                $iloSso = Get-OVServer -Name $OneViewServerName -ErrorAction Stop |
                    Get-OVIloSso -IloRestSession -ErrorAction Stop
                $session = [IloRedfishSession]::new($iloSso, $SkipCertificateCheck, $TimeoutSec)
            } catch {
                return @{
                    Success = $false; Action = $Action; IloIp = $IloIp
                    Error = "OneView iLO SSO acquisition failed for '$OneViewServerName': $($_.Exception.Message)"
                }
            }
        } elseif ($IloCredential) {
            $baseUrl = "https://$IloIp/redfish/v1"
            $session = [IloRedfishSession]::new($baseUrl, $IloCredential.UserName,
                $IloCredential.GetNetworkCredential().Password, $SkipCertificateCheck, $TimeoutSec)
        } else {
            if ($OneViewHost -and $OneViewServerName) {
                return @{
                    Success = $false; Action = $Action; IloIp = $IloIp
                    Error = 'OneView iLO SSO is unavailable because the HPE OneView PowerShell module is not loaded. Supply an explicit -IloCredential for direct iLO access, or load Get-OVServer/Get-OVIloSso.'
                }
            }
            if (-not $IloCredential) {
                return @{
                    Success = $false; Action = $Action; IloIp = $IloIp
                    Error = 'Direct iLO credentials are required only when OneView iLO SSO is unavailable. Supply -IloCredential; never pass an iLO password on the command line.'
                }
            }
        }

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
