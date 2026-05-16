#
# Private/Router.ps1 — Request routing equivalent of Python core/router.py
#
# Routing table is loaded from configs/request_types.json (single source of truth).
# This keeps Python and PowerShell perfectly in sync.
#

$script:RouteConfigPath = Join-Path $PSScriptRoot '..\..\..\configs\request_types.json'
$script:RouteMap = @{}

try {
    $cfg = Get-Content $script:RouteConfigPath -Raw | ConvertFrom-Json -AsHashtable
    foreach ($entry in $cfg.request_types.GetEnumerator()) {
        $script:RouteMap[$entry.Key] = $entry.Value.powershell_handler
    }
}
catch {
    Write-Warning "Router: Could not load request_types.json – falling back to static map"
    $script:RouteMap = @{
        build_iso            = 'New-IsoBuild'
        update_firmware      = 'Update-Firmware'
        patch_windows        = 'Invoke-WindowsSecurityUpdate'
        deploy               = 'Invoke-IsoDeploy'
        monitor              = 'Start-InstallMonitor'
        maintenance_enable   = 'Set-MaintenanceMode'
        maintenance_disable  = 'Set-MaintenanceMode'
        maintenance_validate = 'Set-MaintenanceMode'
        opsramp_report       = 'Invoke-OpsRampClient'
        generate_uuid        = 'New-Uuid'
    }
}

function Invoke-RoutedRequest {
    <#
    .SYNOPSIS
        Routes a request to the appropriate handler function based on request type.
        Mirrors Python route_request(request_type, params).

    .PARAMETER RequestType
        One of the known request types (e.g. 'build_iso', 'maintenance_enable').

    .PARAMETER Params
        Hashtable of additional parameters forwarded to the handler.

    .RETURNS
        [hashtable] with at least keys: Success (bool), Output (string).

    .EXAMPLE
        Invoke-RoutedRequest -RequestType 'build_iso' -Params @{ BaseIsoPath = 'C:\ISOs\base.iso' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $RequestType,
        [hashtable] $Params = @{}
    )
    if (-not $script:RouteMap.ContainsKey($RequestType)) {
        Write-Error "Unknown request type: $RequestType"
        return @{
            Success        = $false
            Error          = "Unknown request type: $RequestType"
            AvailableTypes = @($script:RouteMap.Keys)
        }
    }
    $handlerName = $script:RouteMap[$RequestType]
    Write-Verbose "Routing $RequestType → $handlerName"
    if (Get-Command $handlerName -ErrorAction SilentlyContinue) {
        try {
            $result = & $handlerName @Params
            if ($result -is [hashtable]) {
                $result['request_type'] = $RequestType
                return $result
            }
            return @{ Success = $true; Output = ($result | Out-String) }
        }
        catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    }
    return @{ Success = $false; Error = "Handler '$handlerName' not found. Is the module loaded?" }
}
