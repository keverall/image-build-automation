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

function New-IloAuthException {
    param(
        [string] $Stage,
        [string] $Uri,
        [System.Management.Automation.ErrorRecord] $ErrorRecord,
        [string] $Message
    )
    $status = $null
    if ($ErrorRecord -and $ErrorRecord.Exception.Response) {
        try { $status = [int]$ErrorRecord.Exception.Response.StatusCode } catch { }
    }
    $detail = if ($Message) { $Message } elseif ($ErrorRecord) { $ErrorRecord.Exception.Message } else { 'request failed' }
    $suffix = if ($status) { " HTTP $status" } else { '' }
    return [System.InvalidOperationException]::new("iLO authentication/request failure at $Stage ($Uri):$suffix $detail")
}

function Test-IloAuthentication {
    <#
    .SYNOPSIS
        Non-destructive iLO/OneView authentication and API path diagnostic.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string] $IloIp,
        [System.Management.Automation.PSCredential] $IloCredential,
        [string] $IloUsername,
        [switch] $UseGeneratedIloAccount,
        [string] $OneViewHost,
        [string] $OneViewServerName,
        [Alias('SkipCert')][bool] $SkipCertificateCheck = $true,
        [int] $TimeoutSec = 10,
        [switch] $Json,
        [switch] $Quiet
    )

    if ($UseGeneratedIloAccount -and $IloCredential) {
        throw 'Use either -IloCredential or -UseGeneratedIloAccount, not both.'
    }
    if ($UseGeneratedIloAccount -and [string]::IsNullOrWhiteSpace($OneViewServerName)) {
        throw '-OneViewServerName is required with -UseGeneratedIloAccount.'
    }
    if ($UseGeneratedIloAccount -or $IloUsername) {
        if (-not $IloUsername) { $IloUsername = $OneViewServerName }
        $generatedPassword = Read-Host "Password for generated iLO account '$IloUsername'" -AsSecureString
        $IloCredential = [System.Management.Automation.PSCredential]::new($IloUsername, $generatedPassword)
    }

    $results = [System.Collections.ArrayList]::new()
    $add = {
        param([string]$Name, [string]$Method, [string]$Uri, [bool]$Success, [string]$Detail, [int]$Status = 0)
        $null = $results.Add([ordered]@{ name=$Name; method=$Method; uri=$Uri; success=$Success; status=if ($Status) {$Status} else {$null}; detail=$Detail })
    }
    $probe = {
        param([string]$Name, [string]$Method, [string]$Uri, [hashtable]$Headers, [object]$Body, [System.Management.Automation.PSCredential]$Credential)
        try {
            $p = @{ Uri=$Uri; Method=$Method; SkipCertificateCheck=$SkipCertificateCheck; TimeoutSec=$TimeoutSec; ErrorAction='Stop' }
            if ($Headers) { $p.Headers = $Headers }
            if ($Body) { $p.Body = ($Body | ConvertTo-Json -Depth 10); $p.ContentType='application/json;charset=utf-8' }
            if ($Credential) { $p.Credential = $Credential }
            $response = Invoke-WebRequest @p
            & $add $Name $Method $Uri $true "HTTP $($response.StatusCode)" ([int]$response.StatusCode)
            return $response
        } catch {
            $status = 0
            if ($_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch {} }
            & $add $Name $Method $Uri $false $_.Exception.Message $status
            return $null
        }
    }

    & $probe 'tcp_tls_redfish' 'GET' "https://$IloIp/redfish/v1/" $null $null $null | Out-Null
    & $probe 'tcp_tls_ilo_rest' 'GET' "https://$IloIp/rest/v1/" $null $null $null | Out-Null

    if ($IloCredential) {
        $body = @{ UserName=$IloCredential.UserName; Password=$IloCredential.GetNetworkCredential().Password }
        $direct = & $probe 'direct_redfish_session' 'POST' "https://$IloIp/redfish/v1/SessionService/Sessions" $null $body $null
        if ($direct) {
            $token = $direct.Content | ConvertFrom-Json
            if ($token.token) {
                & $probe 'direct_redfish_authenticated_get' 'GET' "https://$IloIp/redfish/v1/Systems/1" @{ 'X-Auth-Token'=$token.token; Accept='application/json' } $null $null | Out-Null
                if ($direct.Headers.Location) { & $probe 'direct_redfish_logout' 'DELETE' ([string]$direct.Headers.Location) @{ 'X-Auth-Token'=$token.token } $null $null | Out-Null }
            }
        }
        & $probe 'direct_ilo_rest_session' 'POST' "https://$IloIp/rest/v1/sessions" $null $body $null | Out-Null
        & $probe 'direct_basic_redfish_get' 'GET' "https://$IloIp/redfish/v1/Systems/1" $null $null $IloCredential | Out-Null
    }

    if ($OneViewHost -and $OneViewServerName) {
        $cmds = (Get-Command Get-OVServer, Get-OVIloSso -ErrorAction SilentlyContinue)
        if ($cmds.Count -lt 2) {
            & $add 'oneview_sso_cmdlets' 'N/A' $OneViewHost $false 'Get-OVServer and/or Get-OVIloSso is unavailable.' 0
        } else {
            try {
                $sso = Get-OVServer -Name $OneViewServerName -ErrorAction Stop | Get-OVIloSso -IloRestSession -ErrorAction Stop
                $root = [string]$sso.RootUri
                $hasToken = -not [string]::IsNullOrWhiteSpace([string]$sso.'X-Auth-Token')
                & $add 'oneview_sso_acquisition' 'OneView' $OneViewServerName ($hasToken -and $root) ("RootUri present=$([bool]$root); token present=$hasToken") 0
                if ($hasToken -and $root) {
                    & $probe 'oneview_sso_redfish_get' 'GET' ("$($root.TrimEnd('/'))/Systems/1") @{ 'X-Auth-Token'=[string]$sso.'X-Auth-Token'; Accept='application/json'; 'OData-Version'='4.0' } $null $null | Out-Null
                    & $probe 'oneview_sso_redfish_root' 'GET' ("$($root.TrimEnd('/'))/") @{ 'X-Auth-Token'=[string]$sso.'X-Auth-Token'; Accept='application/json' } $null $null | Out-Null
                }
            } catch { & $add 'oneview_sso_acquisition' 'OneView' $OneViewServerName $false $_.Exception.Message 0 }
        }
    }

    $success = @($results | Where-Object { $_.name -match 'authenticated_get|sso_redfish_get' -and $_.success }).Count -gt 0
    $result = [ordered]@{ Success=$success; IloIp=$IloIp; TestedIloUsername=if ($IloCredential) {$IloCredential.UserName} else {$null}; Results=@($results); Recommendation=if ($success) {'At least one authenticated Redfish path works.'} else {'No authenticated Redfish path succeeded. Use the failing stage/status to correct the iLO account, SSO token, endpoint, or iLO policy before deployment.'} }
    if ($Json) { $result | ConvertTo-Json -Depth 10 } elseif (-not $Quiet) { $results | Format-Table name,method,status,success,detail -AutoSize; Write-Host $result.Recommendation }
    return $result
}

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

        # OneView-managed servers always use OneView iLO SSO. An explicitly
        # supplied direct credential must not override SSO: the HPE OneView UI
        # uses the appliance-issued token and the appliance-managed iLO account.
        # Direct credentials are only a fallback when no usable OneView SSO path
        # is available (for example, an unmanaged server).
        $hasOneViewSso = $OneViewHost -and $OneViewServerName -and
            (Get-Command Get-OVServer -ErrorAction SilentlyContinue) -and
            (Get-Command Get-OVIloSso -ErrorAction SilentlyContinue)
        if ($hasOneViewSso) {
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
