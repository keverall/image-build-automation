#
# Set-MaintenanceMode.ps1 — SCOM / OpenView maintenance-mode orchestrator
# Equivalent of reference implementation cli/maintenance_mode.py (~956 lines)
#
# Contains: Set-MaintenanceMode wrapper function, helper functions, manager classes,
#           and a script-mode guard for direct pwsh invocation.
#

# ---- Script-mode param block (MUST be at top of script) ----
# Supports two output modes:
# 1. Human-readable (default): for direct command-line usage
# 2. JSON: for iRequest/REST API integration (when -Json flag is used)
# Note: Mandatory is intentionally omitted here to allow the module to dot-source 
# this script without throwing parameter binding errors during module load.
param(
    [Parameter(Position = 0)][ValidateSet('enable', 'disable', 'validate')][string] $Action = 'enable',
    [Parameter(Position = 1)][string] $TargetId,
    [Parameter(Position = 2)][ValidateSet('scom', 'oneview')][string] $Mode,
    [ValidateSet('Test', 'Prod')][string] $Environment,
    [string] $ScomHost,
    [string] $OneViewHost,
    [string] $Username,
    [int] $PostDisableWaitSeconds = 120,
    [string] $ConfigDir = 'configs',
    [string] $Start = $null,
    [string] $End = $null,
    [switch] $DryRun,
    [switch] $NoSchedule,
    [switch] $Json,
    [Alias('h', 'help', '?')][switch] $ShowHelp
)

# Handle help flag - display practical help and exit
if ($ShowHelp) {
    Write-Host ""
    Write-Host "NAME" -ForegroundColor Cyan
    Write-Host "    Set-MaintenanceMode" -ForegroundColor White
    Write-Host ""
    Write-Host "SYNOPSIS" -ForegroundColor Cyan
    Write-Host "    Enable, disable, or validate maintenance mode for SCOM or OneView clusters." -ForegroundColor White
    Write-Host ""
    Write-Host "SYNTAX" -ForegroundColor Cyan
    Write-Host "    Set-MaintenanceMode -TargetId <string> -Mode <scom|oneview>" -ForegroundColor White
    Write-Host "        [-Action <enable|disable|validate>] [-Environment <Test|Prod>]" -ForegroundColor White
    Write-Host "        [-ScomHost <string>] [-OneViewHost <string>] [-Username <string>]" -ForegroundColor White
    Write-Host "        [-Start <datetime>] [-End <datetime>]" -ForegroundColor White
    Write-Host "        [-PostDisableWaitSeconds <int>] [-DryRun] [-NoSchedule] [-Json]" -ForegroundColor White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor Cyan
    Write-Host "    Manages maintenance mode for server clusters in SCOM or HPE OneView." -ForegroundColor White
    Write-Host "    Supports environment-based host selection from connection_hosts.json." -ForegroundColor White
    Write-Host ""
    Write-Host "    IMPORTANT: All datetime values are UTC only. No local timezone conversion is performed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "PARAMETERS" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  -Action <enable|disable|validate>" -ForegroundColor Green
    Write-Host "    Operation to perform (default: enable)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -TargetId <string> [REQUIRED]" -ForegroundColor Green
    Write-Host "    Cluster ID from clusters_catalogue.json or server name" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Mode <scom|oneview> [REQUIRED]" -ForegroundColor Green
    Write-Host "    scom     - Manage via SCOM (Windows clusters/groups)" -ForegroundColor White
    Write-Host "    oneview  - Manage via HPE OneView (hardware/servers)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Environment <Test|Prod>" -ForegroundColor Green
    Write-Host "    Select environment for host resolution from connection_hosts.json" -ForegroundColor White
    Write-Host "    Valid values: Test, Prod" -ForegroundColor Yellow
    Write-Host "    Default: Reads from `$env:ENVIRONMENT, then defaults to Prod" -ForegroundColor White
    Write-Host ""
    Write-Host "  -ScomHost <string>" -ForegroundColor Green
    Write-Host "    Override SCOM management server (takes precedence over environment config)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -OneViewHost <string>" -ForegroundColor Green
    Write-Host "    Override OneView appliance (takes precedence over environment config)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Username <string>" -ForegroundColor Green
    Write-Host "    Direct username (testing only, not recommended for production)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Start <datetime> / -End <datetime>" -ForegroundColor Green
    Write-Host "    Maintenance window times (UTC ONLY)" -ForegroundColor Yellow
    Write-Host "    Supported formats:" -ForegroundColor White
    Write-Host "      now                    - Current UTC time" -ForegroundColor Gray
    Write-Host "      +Xhours                - Relative hours (e.g., +2hours, +1hour)" -ForegroundColor Gray
    Write-Host "      +Xminutes              - Relative minutes (e.g., +30minutes)" -ForegroundColor Gray
    Write-Host "      +Xdays                 - Relative days (e.g., +1day, +7days)" -ForegroundColor Gray
    Write-Host "      +Xseconds              - Relative seconds (e.g., +3600seconds)" -ForegroundColor Gray
    Write-Host "      YYYY-MM-DD HH:MM       - Absolute UTC (e.g., 2026-06-11 22:00)" -ForegroundColor Gray
    Write-Host "      YYYY-MM-DDTHH:MM:SS    - ISO 8601 UTC (e.g., 2026-06-11T22:00:00)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  -PostDisableWaitSeconds <int>" -ForegroundColor Green
    Write-Host "    Wait after SCOM disable for stabilization (default: 120, set 0 to skip)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -DryRun" -ForegroundColor Green
    Write-Host "    Simulate without making changes" -ForegroundColor White
    Write-Host ""
    Write-Host "  -NoSchedule" -ForegroundColor Green
    Write-Host "    Skip Windows Task Scheduler creation" -ForegroundColor White
    Write-Host ""
    Write-Host "  -Json" -ForegroundColor Green
    Write-Host "    Output as JSON for API/iRequest integration" -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Validate configuration" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action validate -TargetId 'PROD-CLUSTER-01' -Mode scom" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Enable in Test environment with relative time" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom \" -ForegroundColor White
    Write-Host "      -Environment Test -Start 'now' -End '+2hours'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Enable in Prod with absolute UTC time" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom \" -ForegroundColor White
    Write-Host "      -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Disable with custom stabilization wait" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action disable -TargetId 'PROD-CLUSTER-01' -Mode scom \" -ForegroundColor White
    Write-Host "      -Environment Prod -PostDisableWaitSeconds 60" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Dry run test" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom \" -ForegroundColor White
    Write-Host "      -Environment Test -Start 'now' -End '+1hour' -DryRun" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Host override for emergency" -ForegroundColor Green
    Write-Host "  Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom \" -ForegroundColor White
    Write-Host "      -Environment Prod -ScomHost 'backup-scom.local' -Start 'now' -End '+4hours'" -ForegroundColor White
    Write-Host ""
    Write-Host "CREDENTIALS" -ForegroundColor Cyan
    Write-Host "    Set via environment variables (recommended):" -ForegroundColor White
    Write-Host "      `$env:SCOM_ADMIN_USER / `$env:SCOM_ADMIN_PASSWORD" -ForegroundColor Gray
    Write-Host "      `$env:ONEVIEW_USER / `$env:ONEVIEW_PASSWORD" -ForegroundColor Gray
    Write-Host "    Or run interactively - script will prompt if missing" -ForegroundColor White
    Write-Host ""
    Write-Host "MORE INFORMATION" -ForegroundColor Cyan
    Write-Host "    Full docs: Get-Help Set-MaintenanceMode -Full (after importing module)" -ForegroundColor White
    Write-Host "    Testing:   docs/maint-mode-initial-testing.md" -ForegroundColor White
    Write-Host "    Config:    docs/maintenance-mode-environment-config.md" -ForegroundColor White
    Write-Host ""
    exit 0
}

# ---- Module import for script mode ----
# Only import if:
# 1. The Automation module is not already loaded in this session
# 2. We are NOT being dot-sourced by the module itself (InvocationName == '.')
# This prevents circular imports when the module loads this script via dot-source.
if (-not (Get-Module -Name 'Automation' -ErrorAction SilentlyContinue) -and $MyInvocation.InvocationName -ne '.') {
    # Check if we're being invoked directly (not dot-sourced)
    if ($MyInvocation.InvocationName -match '\.ps1$') {
        # Running directly with pwsh -File - import the module
        $modulePath = Join-Path $PSScriptRoot '..\Automation.psd1'
        Import-Module $modulePath -Force -WarningAction SilentlyContinue
    }
}

function Set-MaintenanceMode {
    <#
    .SYNOPSIS
        Enable, disable, or validate maintenance mode for a server cluster.
        Callable from the module Router.

    .DESCRIPTION
        Orchestrates maintenance-mode operations across SCOM 2015 and HPE OpenView
        for a logical cluster defined in clusters_catalogue.json.
        Supports immediate enable/disable as well as scheduled windows with
        automatic disable via Windows Task Scheduler.
        Integrates with OpsRamp for metric/alert emission and can send email
        notifications.  The function is the PowerShell implementation.
        
        All datetime values are UTC only. Local time conversion is not performed.

    .PARAMETER Action
        'enable', 'disable', or 'validate'. Default is 'enable'.

    .PARAMETER TargetId
        Target identifier string (cluster ID or server name). Required.

    .PARAMETER Mode
        'scom' for SCOM-only or 'oneview' for HPE OpenView-only. 
        SCOM manages Windows cluster objects; OpenView manages hardware directly.
        Required.

    .PARAMETER Environment
        Environment selection: 'Test' or 'Prod'. 
        Determines which hosts to connect to from connection_hosts.json.
        If not specified, reads from $env:ENVIRONMENT environment variable.
        Defaults to 'Prod' if neither is set.

    .PARAMETER ScomHost
        Optional override for SCOM management server hostname/IP.
        Takes precedence over environment config.
        Can also be set via $env:SCOM_HOST or $env:SCOM_OVERRIDE_HOST.

    .PARAMETER OneViewHost
        Optional override for OneView appliance hostname/IP.
        Takes precedence over environment config.
        Can also be set via $env:ONEVIEW_HOST or $env:ONEVIEW_OVERRIDE_HOST.

    .PARAMETER Username
        Optional direct username parameter (for testing only).
        Not recommended for production use - use environment variables instead.
        For SCOM: overrides $env:SCOM_ADMIN_USER
        For OneView: overrides $env:ONEVIEW_USER

    .PARAMETER PostDisableWaitSeconds
        Seconds to sleep after disabling SCOM maintenance mode to allow servers
        time to reboot and restart services before alerting resumes.
        Default is 120 (2 minutes). Set to 0 to skip the wait.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs').

    .PARAMETER Start
        Maintenance start datetime (UTC only). Supported formats:
        - 'now': Current UTC time (default for enable action)
        - Relative offset: '+Xhours', '+Xminutes', '+Xdays', '+Xseconds'
          Examples: '+1hour', '+30minutes', '+2days', '+3600seconds'
        - Absolute UTC: 'YYYY-MM-DD HH:MM' or 'YYYY-MM-DDTHH:MM:SS'
          Examples: '2026-06-11 22:00', '2026-06-11T22:00:00'
        
        IMPORTANT: All times are UTC. No local timezone conversion is performed.

    .PARAMETER End
        Maintenance end datetime (UTC only). Same formats as Start.
        Required for 'enable' action.
        Examples: '+2hours', '2026-06-12 02:00', '2026-06-12T02:00:00'

    .PARAMETER DryRun
        Simulate without making changes. Shows what would happen.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .PARAMETER Json
        Output as JSON for API/iRequest integration.

    .RETURNS
        [hashtable] with Success (bool), Message, StartTimeUtc, EndTimeUtc,
        TargetId, ClusterName, ServerCount, DryRun, AuditFile,
        ScomObjects, ScomSummary, OneViewObjects, OneViewSummary, FailedObjects.

    .EXAMPLE
        # Validate configuration without making changes
        Set-MaintenanceMode -Action validate -TargetId 'PROD-CLUSTER-01' -Mode scom

    .EXAMPLE
        # Enable maintenance in Test environment with relative time
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+2hours'

    .EXAMPLE
        # Enable maintenance in Prod environment with absolute UTC time
        Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'

    .EXAMPLE
        # Disable maintenance with custom stabilization wait
        Set-MaintenanceMode -Action disable -TargetId 'PROD-CLUSTER-01' -Mode scom -Environment Prod -PostDisableWaitSeconds 60

    .EXAMPLE
        # Use host override for emergency maintenance
        Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom -Environment Prod -ScomHost 'backup-scom.local' -Start 'now' -End '+4hours'

    .EXAMPLE
        # Dry run to test configuration
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+1hour' -DryRun

    .EXAMPLE
        # OneView single server maintenance
        Set-MaintenanceMode -Action enable -TargetId 'server01.ad.example.com' -Mode oneview -Environment Test -Start 'now' -End '+1hour'

    .LINK
        https://github.com/yourorg/image-build-automation/docs/maint-mode-initial-testing.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][ValidateSet('enable', 'disable', 'validate')][string] $Action = 'enable',
        [Parameter(Mandatory, Position = 1)][string] $TargetId,
        [Parameter(Mandatory, Position = 2)][ValidateSet('scom', 'oneview')][string] $Mode,
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [string] $ScomHost,
        [string] $OneViewHost,
        [string] $Username,
        [int] $PostDisableWaitSeconds = 120,
        [string] $ConfigDir = 'configs',
        [string] $Start = $null,
        [string] $End = $null,
        [switch] $DryRun,
        [switch] $NoSchedule
    )

    $ErrorActionPreference = 'Continue'

    # Normalize Mode to lowercase for case-insensitive comparison
    if ($Mode) { $Mode = $Mode.ToLower() }
    else {
        return @{ Success = $false; Error = "Mode is required and must be either 'scom' or 'oneview'." }
    }

    # Use passed ConfigDir param or fall back to project-root configs
    $projRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $EffectiveConfigDir = if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        if (Split-Path $ConfigDir -IsAbsolute) { $ConfigDir } else { Join-Path (Get-Location) $ConfigDir }
    } else {
        Join-Path $projRoot 'configs'
    }
    
    # If the user passed a relative path and it's not found from Get-Location, try from projRoot
    if (-not (Test-Path (Join-Path $EffectiveConfigDir 'clusters_catalogue.json'))) {
        if (-not (Split-Path $ConfigDir -IsAbsolute)) {
            $fallback = Join-Path $projRoot $ConfigDir
            if (Test-Path (Join-Path $fallback 'clusters_catalogue.json')) {
                $EffectiveConfigDir = $fallback
            }
        }
    }

    # Load configs
    $clustersCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'scom_config.json')           -Required:$false
    $oneviewCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'oneview_config.json')        -Required:$false
    $emailCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'opsramp_config.json') -Required:$false

    # Parse Start / End explicitly if provided, so we can output them even on early errors
    $startDt = $null; $endDt = $null
    $utcStart = $null; $utcEnd = $null
    if ($Action -eq 'enable') {
        if ($Start) { $startDt = _Parse-Datetime $Start; $utcStart = Convert-ToUtcIso8601 $startDt }
        else { $startDt = [DateTime]::UtcNow; $utcStart = Convert-ToUtcIso8601 $startDt }
        if ($End) { $endDt = _Parse-Datetime $End; $utcEnd = Convert-ToUtcIso8601 $endDt }
    }

    # For oneview mode, TargetId can be a server name - resolve via API
    # For scom mode, TargetId must be in catalogue (current behavior)
    $isDirectServerMode = ($Mode -eq 'oneview')
    $clusterDef = $null
    $clusterName = $TargetId

    # Get clusters map once
    $clustersMap = $clustersCfg.Get_Item('clusters')

    if ($isDirectServerMode) {
        # Try catalogue lookup first
        if ($clustersMap -and $clustersMap.ContainsKey($TargetId)) {
            $clusterDef = $clustersMap[$TargetId]
            $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
        }
        # If not in catalogue, will be resolved via OneView API later
    } else {
        # SCOM mode - must be in catalogue
        if (-not $clustersMap -or -not $clustersMap.ContainsKey($TargetId)) {
            Write-Verbose "Target '$TargetId' not found in catalogue."
            $earlyErr = @{ Success = $false; Error = "Target '$TargetId' not found in catalogue."; ClusterName = $clusterName }
            if ($DryRun) { 
                $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd 
            }
            return $earlyErr
        }
        $clusterDef = $clustersMap[$TargetId]
        $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
    }

    # Validate cluster definition if found (required for scom mode)
    if ($clusterDef -and $Mode -eq 'scom') {
        $requiredFields = @('display_name', 'servers', 'scom_group', 'environment')
        $missing = foreach ($f in $requiredFields) { if (-not $clusterDef.ContainsKey($f)) { $f } }
        if ($missing) { 
            Write-Verbose "Cluster definition missing required fields: $($missing -join ', ')"
            $earlyErr = @{ Success = $false; Error = "Missing fields: $($missing -join ', ')"; ClusterName = $clusterName }
            if ($DryRun) { $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd }
            return $earlyErr
        }
        $servers = $clusterDef.Get_Item('servers')
        if (-not ($servers -is [System.Collections.IEnumerable]) -or -not ($servers | Measure-Object).Count) {
            Write-Verbose "Cluster 'servers' must be a non-empty list."
            $earlyErr = @{ Success = $false; Error = "Cluster 'servers' must be a non-empty list."; ClusterName = $clusterName }
            if ($DryRun) { $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd }
            return $earlyErr
        }
    } elseif (-not $clusterDef -and $isDirectServerMode) {
        # Single server mode - derive servers array from TargetId
        $servers = @($TargetId)
    } elseif ($clusterDef -and $isDirectServerMode) {
        $servers = $clusterDef.Get_Item('servers')
    }

    # VALIDATE action - exit early, no credentials needed
    if ($Action -eq 'validate') {
        Write-Host "Target '$TargetId' validated. Servers: $($servers -join ', ')"
        $audit = @{ target_id = $TargetId; action = $Action; dry_run = [bool]$DryRun; timestamp_start = Get-UtcTimestamp; steps = @{}; success = $true }
        _Save-AuditRecord $audit (Join-Path $Script:MaintLogDir "validate_${TargetId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json")
        return @{ Success = $true; Message = "Target '$TargetId' validated."
                  StartTimeUtc = if ($DryRun) { $utcStart } else { $null }
                  EndTimeUtc = if ($DryRun) { $utcEnd } else { $null }
                  ScomObjects = @(); ScomSummary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }; FailedObjects = @() }
    }

    # Load environment-based connection config
    $hostsCfgPath = Join-Path $EffectiveConfigDir 'connection_hosts.json'
    $hostsCfg = if (Test-Path $hostsCfgPath) { Import-JsonConfig -Path $hostsCfgPath -Required:$false } else { @{} }
    
    # Determine environment: parameter > env var > default to Prod
    $effectiveEnv = if ($PSBoundParameters.ContainsKey('Environment')) { 
        $Environment 
    } elseif ([System.Environment]::GetEnvironmentVariable('ENVIRONMENT')) {
        [System.Environment]::GetEnvironmentVariable('ENVIRONMENT')
    } else {
        'Prod'
    }
    
    Write-Verbose "Using environment: $effectiveEnv"
    
    # Resolve hosts from config or parameters
    $envConfig = $hostsCfg.Get_Item('environments') ?? @{}
    $selectedEnv = $envConfig.Get_Item($effectiveEnv) ?? @{}
    
    if ($Mode -eq 'scom') {
        $scomEnvConfig = $selectedEnv.Get_Item('scom') ?? @{}
        $resolvedScomHost = if ($PSBoundParameters.ContainsKey('ScomHost')) {
            $ScomHost
        } elseif ([System.Environment]::GetEnvironmentVariable('SCOM_OVERRIDE_HOST')) {
            [System.Environment]::GetEnvironmentVariable('SCOM_OVERRIDE_HOST')
        } elseif ([System.Environment]::GetEnvironmentVariable('SCOM_HOST')) {
            [System.Environment]::GetEnvironmentVariable('SCOM_HOST')
        } else {
            $scomEnvConfig.Get_Item('management_server')
        }
        
        if (-not $resolvedScomHost) {
            return @{ Success = $false; Error = "SCOM host not configured for environment '$effectiveEnv'. Set SCOM_HOST env var, use -ScomHost parameter, or update connection_hosts.json." }
        }
        
        Write-Verbose "SCOM host resolved to: $resolvedScomHost"
    }
    
    if ($Mode -eq 'oneview') {
        $oneviewEnvConfig = $selectedEnv.Get_Item('oneview') ?? @{}
        $resolvedOneViewHost = if ($PSBoundParameters.ContainsKey('OneViewHost')) {
            $OneViewHost
        } elseif ([System.Environment]::GetEnvironmentVariable('ONEVIEW_OVERRIDE_HOST')) {
            [System.Environment]::GetEnvironmentVariable('ONEVIEW_OVERRIDE_HOST')
        } elseif ([System.Environment]::GetEnvironmentVariable('ONEVIEW_HOST')) {
            [System.Environment]::GetEnvironmentVariable('ONEVIEW_HOST')
        } else {
            $oneviewEnvConfig.Get_Item('appliance')
        }
        
        if (-not $resolvedOneViewHost) {
            return @{ Success = $false; Error = "OneView host not configured for environment '$effectiveEnv'. Set ONEVIEW_HOST env var, use -OneViewHost parameter, or update connection_hosts.json." }
        }
        
        Write-Verbose "OneView host resolved to: $resolvedOneViewHost"
    }
    
    # Resolve credentials: parameter > env var > interactive prompt
    # Skip credential resolution entirely in DryRun mode (no actual connections needed)
    if ($DryRun) {
        $resolvedUsername = $null
        $resolvedPassword = $null
    } else {
        $resolvedUsername = if ($PSBoundParameters.ContainsKey('Username')) {
            $Username
        } elseif ($Mode -eq 'scom' -and [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_USER')) {
            [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_USER')
        } elseif ($Mode -eq 'oneview' -and [System.Environment]::GetEnvironmentVariable('ONEVIEW_USER')) {
            [System.Environment]::GetEnvironmentVariable('ONEVIEW_USER')
        } else {
            $null
        }
        
        $resolvedPassword = if ($Mode -eq 'scom' -and [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_PASSWORD')) {
            [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_PASSWORD')
        } elseif ($Mode -eq 'oneview' -and [System.Environment]::GetEnvironmentVariable('ONEVIEW_PASSWORD')) {
            [System.Environment]::GetEnvironmentVariable('ONEVIEW_PASSWORD')
        } else {
            $null
        }
        
        # Interactive prompt for missing credentials (only in interactive mode, not automated)
        $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
        
        if (-not $resolvedUsername -and -not $isAutomated) {
            $credPrompt = if ($Mode -eq 'scom') { "SCOM" } else { "OneView" }
            Write-Host "Enter $credPrompt username:" -ForegroundColor Yellow
            $resolvedUsername = Read-Host
        }
        
        if (-not $resolvedPassword -and -not $isAutomated) {
            $credPrompt = if ($Mode -eq 'scom') { "SCOM" } else { "OneView" }
            $securePass = Read-Host "Enter $credPrompt password" -AsSecureString
            $resolvedPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
            )
        }
        
        if (-not $resolvedUsername -or -not $resolvedPassword) {
            $missingCreds = @()
            if (-not $resolvedUsername) { $missingCreds += "username" }
            if (-not $resolvedPassword) { $missingCreds += "password" }
            return @{ 
                Success = $false
                Error = "Missing credentials: $($missingCreds -join ', '). Set environment variables, use parameters, or run interactively."
            }
        }
    }

    # Load configs
    $clustersCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'scom_config.json')           -Required:$false
    $oneviewCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'oneview_config.json')        -Required:$false
    $emailCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'opsramp_config.json') -Required:$false

    # Parse Start / End explicitly if provided, so we can output them even on early errors
    $startDt = $null; $endDt = $null
    $utcStart = $null; $utcEnd = $null
    if ($Action -eq 'enable') {
        if ($Start) { $startDt = _Parse-Datetime $Start; $utcStart = Convert-ToUtcIso8601 $startDt }
        else { $startDt = [DateTime]::UtcNow; $utcStart = Convert-ToUtcIso8601 $startDt }
        if ($End) { $endDt = _Parse-Datetime $End; $utcEnd = Convert-ToUtcIso8601 $endDt }
    }

    # For oneview mode, TargetId can be a server name - resolve via API
    # For scom mode, TargetId must be in catalogue (current behavior)
    $isDirectServerMode = ($Mode -eq 'oneview')
    $clusterDef = $null
    $clusterName = $TargetId

    # Get clusters map once
    $clustersMap = $clustersCfg.Get_Item('clusters')

    if ($isDirectServerMode) {
        # Try catalogue lookup first
        if ($clustersMap -and $clustersMap.ContainsKey($TargetId)) {
            $clusterDef = $clustersMap[$TargetId]
            $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
        }
        # If not in catalogue, will be resolved via OneView API later
    } else {
        # SCOM mode - must be in catalogue
        if (-not $clustersMap -or -not $clustersMap.ContainsKey($TargetId)) {
            Write-Verbose "Target '$TargetId' not found in catalogue."
            $earlyErr = @{ Success = $false; Error = "Target '$TargetId' not found in catalogue."; ClusterName = $clusterName }
            if ($DryRun) { 
                $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd 
            }
            return $earlyErr
        }
        $clusterDef = $clustersMap[$TargetId]
        $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
    }

    # Validate cluster definition if found (required for scom mode)
    if ($clusterDef -and $Mode -eq 'scom') {
        $requiredFields = @('display_name', 'servers', 'scom_group', 'environment')
        $missing = foreach ($f in $requiredFields) { if (-not $clusterDef.ContainsKey($f)) { $f } }
        if ($missing) { 
            Write-Verbose "Cluster definition missing required fields: $($missing -join ', ')"
            $earlyErr = @{ Success = $false; Error = "Missing fields: $($missing -join ', ')"; ClusterName = $clusterName }
            if ($DryRun) { $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd }
            return $earlyErr
        }
        $servers = $clusterDef.Get_Item('servers')
        if (-not ($servers -is [System.Collections.IEnumerable]) -or -not ($servers | Measure-Object).Count) {
            Write-Verbose "Cluster 'servers' must be a non-empty list."
            $earlyErr = @{ Success = $false; Error = "Cluster 'servers' must be a non-empty list."; ClusterName = $clusterName }
            if ($DryRun) { $earlyErr['StartTimeUtc'] = $utcStart; $earlyErr['EndTimeUtc'] = $utcEnd }
            return $earlyErr
        }
    } elseif (-not $clusterDef -and $isDirectServerMode) {
        # Single server mode - derive servers array from TargetId
        $servers = @($TargetId)
    } elseif ($clusterDef -and $isDirectServerMode) {
        $servers = $clusterDef.Get_Item('servers')
    }

    # Finalize Start / End with catalogue defaults if needed
    if ($Action -eq 'enable') {
        if (-not $End) {
            $defaultHours = 4
            if ($scomCfg) {
                $scomSettings = $scomCfg.Get_Item('maintenance_settings')
                if ($scomSettings -and $scomSettings.ContainsKey('default_duration_hours')) {
                    $defaultHours = [int]$scomSettings['default_duration_hours']
                }
            }
            $minEnd = $startDt.AddHours($defaultHours)
            $endDt = $minEnd
            $schedule = $clusterDef.Get_Item('schedule')
            if ($schedule) {
                $scheduleEnd = _Compute-NextWorkStart $schedule $startDt
                if ($scheduleEnd -gt $endDt) { $endDt = $scheduleEnd }
            }
            $utcEnd = Convert-ToUtcIso8601 $endDt
        }

        if ($endDt -le $startDt) { 
            Write-Verbose 'End time must be after start time.'
            return @{ 
                Success = $false; 
                Error = 'End time must be after start time.';
                StartTimeUtc = $utcStart;
                EndTimeUtc = $utcEnd;
                ClusterName = $clusterName
            } 
        }
        $duration = $endDt - $startDt
        Write-Verbose "Maintenance window: $startDt → $endDt (duration: $duration)"
    }

    # Initialise managers
    $scomMgr = $null
    $oneviewMgr = $null
    $resolveResult = $null

    if ($Mode -eq 'scom') {
        try { 
            # Override management server if resolved from environment/parameter
            if ($resolvedScomHost) {
                $scomCfgCopy = $scomCfg.Clone()
                $scomCfgCopy['management_server'] = $resolvedScomHost
                $scomMgr = [SCOMManager]::new($scomCfgCopy)
            } else {
                $scomMgr = [SCOMManager]::new($scomCfg)
            }
            
            # Override credentials if provided via parameter
            if ($resolvedUsername -and $resolvedPassword) {
                $scomMgr.Cred = @{ username = $resolvedUsername; password = $resolvedPassword }
            }
        } catch { Write-Warning "SCOM manager unavailable: $($_.Exception.Message)" }
    }

    if ($Mode -eq 'oneview') {
        try {
            # Override appliance if resolved from environment/parameter
            if ($resolvedOneViewHost) {
                $oneviewCfgCopy = $oneviewCfg.Clone()
                if (-not $oneviewCfgCopy.ContainsKey('oneview')) {
                    $oneviewCfgCopy['oneview'] = @{}
                }
                $oneviewCfgCopy['oneview']['appliance'] = $resolvedOneViewHost
                $oneviewMgr = [OneViewClient]::new($oneviewCfgCopy)
            } else {
                $oneviewMgr = [OneViewClient]::new($oneviewCfg)
            }
            
            # Override credentials if provided via parameter
            if ($resolvedUsername -and $resolvedPassword) {
                $oneviewMgr.Username = $resolvedUsername
                $oneviewMgr.Password = $resolvedPassword
            }
            
            # Resolve target for oneview - determine if server or cluster/scope
            if ($oneviewMgr -and $isDirectServerMode) {
                $resolveResult = $oneviewMgr.ResolveTarget($TargetId, [bool]$DryRun)
                if (-not $resolveResult.Success) {
                    return @{ Success = $false; Error = "OneView could not resolve '$TargetId' as server or cluster: $($resolveResult.Message)" }
                }
                $clusterName = $resolveResult.TargetName
            }
        } catch { Write-Warning "OneView client unavailable: $($_.Exception.Message)" }
    }

    $emailer = [EmailNotifier]::new($emailCfg)

    $opsrampClient = $null
    if ($opsrampCfg) { try { $opsrampClient = [OpsRamp_Client]::new((Join-Path $Script:ConfigDir 'opsramp_config.json')) } catch { Write-Debug "OpsRamp init failed" } }

    # Test connection before proceeding (non-dry-run only)
    if (-not $DryRun) {
        if ($Mode -eq 'scom' -and $scomMgr) {
            Write-Verbose "Testing SCOM connection to $($scomMgr.MgmtServer)..."
            $connectionOk = Test-ScomConnection -ManagementServer $scomMgr.MgmtServer -Username $scomMgr.Cred.username -Password $scomMgr.Cred.password
            if (-not $connectionOk) {
                return @{ 
                    Success = $false
                    Error = "Failed to connect to SCOM management server '$($scomMgr.MgmtServer)'. Check credentials and network connectivity."
                    ClusterName = $clusterName
                }
            }
            Write-Verbose "SCOM connection verified successfully"
        }
        
        if ($Mode -eq 'oneview' -and $oneviewMgr) {
            Write-Verbose "Testing OneView connection to $($oneviewMgr.Appliance)..."
            $connectionOk = Test-OneViewConnection -Appliance $oneviewMgr.Appliance -Username $oneviewMgr.Username -Password $oneviewMgr.Password
            if (-not $connectionOk) {
                return @{ 
                    Success = $false
                    Error = "Failed to connect to OneView appliance '$($oneviewMgr.Appliance)'. Check credentials and network connectivity."
                    ClusterName = $clusterName
                }
            }
            Write-Verbose "OneView connection verified successfully"
        }
    }

    # Execute action
    $overallOk = $true
    $audit = @{ target_id = $TargetId; action = $Action; dry_run = [bool]$DryRun; timestamp_start = Get-UtcTimestamp; steps = @{}; success = $true }

    if ($Action -eq 'enable') {
        # SCOM — use group mode to put ALL objects in the SCOM group into maintenance mode
        # (servers, network devices, nodes, cluster objects, everything under the group)
        # Only for 'scom' mode
        $scomOk = $true; $scomInfo = ''; $scomObjects = @(); $scomSummary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
        if ($scomMgr) {
            $scomOk = $false
            $durHrs = $duration.TotalSeconds / 3600.0
            $comment = "iRequest Maintenance: $TargetId"
            $scomRes = $scomMgr.EnterMaintenance(
                $clusterDef.Get_Item('scom_group'),
                $duration, $comment, [bool]$DryRun,
                $null, $false)
            $scomOk = $scomRes.Success
            $scomObjects = $scomRes.Objects
            $scomSummary = $scomRes.Summary
            $scomInfo = if ($scomRes.Output) { ($scomRes.Output -join "`n") } else { '' }
        }
    if ($Mode -eq 'scom') {
            $audit.steps['scom'] = @{ Success = $scomOk; Info = $scomInfo; Objects = $scomObjects; Summary = $scomSummary }
            if (-not $scomOk) { $overallOk = $false }
        }

        # OneView — for 'oneview' mode
        $oneviewOk = $true; $oneviewMsg = ''; $oneviewObjects = @(); $oneviewSummary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
        if ($Mode -eq 'oneview') {
            if ($oneviewMgr) {
                $targetName = if ($resolveResult) { $resolveResult.TargetName } else { $TargetId }
                $targetType = if ($resolveResult) { $resolveResult.TargetType } else { 'Scope' }
                $oneviewRes = $oneviewMgr.SetMaintenance($targetName, $targetType, $startDt, $endDt, [bool]$DryRun)
                $oneviewOk = $oneviewRes.Success; $oneviewMsg = $oneviewRes.Message
                $oneviewObjects = $oneviewRes.Objects ?? @()
                $oneviewSummary = $oneviewRes.Summary ?? @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
            } else {
                $oneviewOk = $false; $oneviewMsg = 'OneView client not available'
            }
            $audit.steps['oneview'] = @{ Success = $oneviewOk; Message = $oneviewMsg; Objects = $oneviewObjects; Summary = $oneviewSummary }
            if (-not $oneviewOk) { $overallOk = $false }
        }

        # Email
        $emailOk = $emailer.SendMaintenanceNotification('enabled', $clusterDef, $servers, $startDt, $endDt, [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk -and -not $DryRun) { $overallOk = $false }

        # OpsRamp
        $opsOk = $false
        if ($opsrampClient -and -not $DryRun) {
            $env = if ($clusterDef) { $clusterDef.Get_Item('environment') } else { 'unknown' }
            $displayName = if ($clusterDef) { $clusterDef.Get_Item('display_name') } else { $clusterName }
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 1, [DateTime]::MinValue, @{ cluster = $TargetId; environment = $env })
            }
            $opsrampClient.SendAlert($TargetId, 'maintenance.enabled', 'INFO',
                "Maintenance enabled for $TargetId",
                @{ cluster = $displayName; servers = $servers;
                    start = Convert-ToUtcIso8601 $startDt; end = Convert-ToUtcIso8601 $endDt
                })
            $opsrampClient.SendEvent($TargetId, 'maintenance.enabled',
                "Maintenance window started for $displayName",
                @{ cluster = $TargetId; action = 'enable' })
        }
        $audit.steps['opsramp'] = @{ Success = $opsOk }

        # Scheduled Task
        if ($IsWindows -and -not $NoSchedule) {
            $taskName = "MaintenanceDisable-$TargetId"
            $scriptAbs = (Resolve-Path $PSScriptRoot).Path
            $stTime = $endDt.ToString('HH:mm')
            $sdDate = $endDt.ToString('yyyy/MM/dd')
            schtasks /Delete /TN $taskName /F 2>$null | Out-Null
            try {
                schtasks /Create /TN $taskName /TR "`"$($PSHOME)\pwsh.exe`" `"$scriptAbs`" -Action disable -TargetId $TargetId -NoSchedule" `
                    /SC ONCE /ST $stTime /SD $sdDate /RL HIGHEST /RU SYSTEM /F 2>&1 | Out-Null
                $audit.steps.scheduled_task = @{ Created = $true }
            }
            catch { $audit.steps.scheduled_task = @{ Created = $false; Error = $_.Exception.Message }; $overallOk = $false }
        }
        
    }
    elseif ($Action -eq 'disable') {
        # SCOM — exit maintenance mode for ALL objects in the group (group mode, not cluster mode)
        # Only for 'scom' mode
        $scomExitOk = $true; $scomExitObjects = @(); $scomExitSummary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
        if ($scomMgr -and $Mode -eq 'scom') {
            $scomExitOk = $false
            Write-Verbose "Exiting SCOM maintenance mode for group '$($clusterDef.Get_Item('scom_group'))' (all objects)"
            $scomExitRes = $scomMgr.ExitMaintenance(
                $clusterDef.Get_Item('scom_group'),
                [bool]$DryRun, $null, $false)
            $scomExitOk = $scomExitRes.Success
            $scomExitObjects = $scomExitRes.Objects
            $scomExitSummary = $scomExitRes.Summary
            $audit.steps['scom_exit'] = @{ Success = $scomExitOk; Objects = $scomExitObjects; Summary = $scomExitSummary }
            if (-not $scomExitOk) { $overallOk = $false }

            # Wait/sleep period after disabling SCOM maintenance to allow servers time
            # to reboot, restart services, and stabilize before alerting resumes.
            # This prevents false alerts that support staff report frequently.
            if (-not $DryRun -and $PostDisableWaitSeconds -gt 0) {
                Write-Host "Waiting ${PostDisableWaitSeconds}s for servers to stabilize after SCOM maintenance exit..."
                Start-Sleep -Seconds $PostDisableWaitSeconds
                Write-Host 'Stabilization wait complete. Alerting is now active.'
                $audit.steps['post_disable_wait'] = @{ Seconds = $PostDisableWaitSeconds }
            }
            else {
                $audit.steps['post_disable_wait'] = @{ Skipped = $true; Reason = if ($DryRun) { 'DryRun' } else { 'PostDisableWaitSeconds=0' } }
            }
        }

        # OneView disable — for 'oneview' mode
        $oneviewExitOk = $true; $oneviewExitMsg = ''; $oneviewExitObjects = @(); $oneviewExitSummary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
        if ($Mode -eq 'oneview' -and $oneviewMgr) {
            $targetName = if ($resolveResult) { $resolveResult.TargetName } else { $TargetId }
            $targetType = if ($resolveResult) { $resolveResult.TargetType } else { 'Scope' }
            $oneviewExitRes = $oneviewMgr.DisableMaintenance($targetName, $targetType, [bool]$DryRun)
            $oneviewExitOk = $oneviewExitRes.Success; $oneviewExitMsg = $oneviewExitRes.Message
            $oneviewExitObjects = $oneviewExitRes.Objects ?? @()
            $oneviewExitSummary = $oneviewExitRes.Summary ?? @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
            $audit.steps['oneview_exit'] = @{ Success = $oneviewExitOk; Message = $oneviewExitMsg; Objects = $oneviewExitObjects; Summary = $oneviewExitSummary }
            if (-not $oneviewExitOk) { $overallOk = $false }
        }

        # Email disable notification
        if ($clusterDef) {
            $emailOk = $emailer.SendMaintenanceNotification('disabled', $clusterDef, $servers, $null, [DateTime]::UtcNow, [bool]$DryRun)
            $audit.steps['email'] = @{ Sent = $emailOk }
            if (-not $emailOk) { $overallOk = $false }
        }

        # OpsRamp
        if ($opsrampClient -and -not $DryRun) {
            $env = if ($clusterDef) { $clusterDef.Get_Item('environment') } else { 'unknown' }
            $displayName = if ($clusterDef) { $clusterDef.Get_Item('display_name') } else { $clusterName }
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 0, [DateTime]::MinValue, @{ cluster = $TargetId; environment = $env })
            }
            $opsrampClient.SendAlert($TargetId, 'maintenance.disabled', 'INFO',
                "Maintenance disabled for $TargetId",
                @{ completed_at = Get-UtcTimestamp })
            $opsrampClient.SendEvent($TargetId, 'maintenance.disabled',
                "Maintenance window ended for $displayName",
                @{ cluster = $TargetId; action = 'disable' })
        }

        # Clean up scheduled task
        if ($IsWindows) {
            $taskName = "MaintenanceDisable-$TargetId"
            try { schtasks /Delete /TN $taskName /F 2>&1 | Out-Null; $audit.steps.scheduled_task_cleanup = @{ Deleted = $true } }
            catch { $audit.steps.scheduled_task_cleanup = @{ Deleted = $false; Error = $_.Exception.Message } }
        }
    }

    $audit.success = $overallOk
    $auditFile = Join-Path $Script:MaintLogDir "$($Action)_${TargetId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
    _Save-AuditRecord $audit $auditFile

    # Build detailed completion message
    $serverCount = ($servers | Measure-Object).Count
    $dryRunNote = if ($DryRun) { " [DRY-RUN]" } else { "" }
    
    $detailMessage = if ($overallOk) {
        if ($Action -eq 'enable') {
            $durationStr = if ($duration) {
                $totalHours = [int]$duration.TotalHours
                $mins = $duration.Minutes
                " (Duration: ${totalHours}h ${mins}m)"
            } else { "" }
            "Maintenance $Action completed for cluster '$clusterName' ($serverCount servers)$durationStr$dryRunNote. Window: $utcStart -> $utcEnd"
        } elseif ($Action -eq 'disable') {
            "Maintenance $Action completed for cluster '$clusterName' ($serverCount servers)$dryRunNote. Maintenance mode deactivated."
        } else {
            "Validation completed for cluster '$clusterName' ($serverCount servers). Configuration is valid."
        }
    } else {
        "Maintenance $Action finished with errors for cluster '$clusterName'$dryRunNote. Check audit: $auditFile"
    }
    
    if ($overallOk) { Write-Host $detailMessage }
    else { Write-Warning $detailMessage }
    
    # Build per-object results for response
    $allScomObjects = @($scomObjects ?? @())
    $allOneviewObjects = @($oneviewObjects ?? @())
    $allExitObjects = @($scomExitObjects ?? @())
    $allOneviewExitObjects = @($oneviewExitObjects ?? @())

    $actionObjects = if ($Action -eq 'enable') {
        $allScomObjects + $allOneviewObjects
    } else {
        $allExitObjects + $allOneviewExitObjects
    }
    
    $failedObjects = [array]@($actionObjects | Where-Object { $_.Status -eq 'failed' })
    
    return @{ 
        Success = $overallOk
        Message = $detailMessage
        StartTimeUtc = if ($Action -eq 'enable') { $utcStart } else { $null }
        EndTimeUtc = if ($Action -eq 'enable') { $utcEnd } else { $null }
        TargetId = $TargetId
        ClusterName = $clusterName
        ServerCount = $serverCount
        DryRun = [bool]$DryRun
        AuditFile = $auditFile
        ScomObjects = $allScomObjects
        ScomSummary = if ($Action -eq 'enable') { $scomSummary } elseif ($Action -eq 'disable') { $scomExitSummary } else { @{} }
        OneViewObjects = $allOneviewObjects
        OneViewSummary = if ($Action -eq 'enable') { $oneviewSummary } elseif ($Action -eq 'disable') { $oneviewExitSummary } else { @{} }
        FailedObjects = $failedObjects
    }
}

# ---- Constants (always defined so classes referencing them work on dot-source) ----
# Determine base directory using shared utility, with a robust fallback
if (Get-Command Get-ProjectRoot -ErrorAction SilentlyContinue) {
    $Script:BaseDir = Get-ProjectRoot
} else {
    # Fallback: walk up directories to find project root (kilo.json or Makefile)
    $Script:BaseDir = $PSScriptRoot
    $current = $Script:BaseDir
    while ($current -and -not (Test-Path (Join-Path $current 'kilo.json')) -and -not (Test-Path (Join-Path $current 'Makefile'))) {
        $parent = Split-Path $current
        if ($parent -eq $current -or -not $parent) { break }
        $current = $parent
    }
    if (-not $current -or -not (Test-Path $current)) {
        $Script:BaseDir = Get-Location
    } else {
        $Script:BaseDir = (Resolve-Path $current).Path
    }
}

if (-not $Script:ConfigDir) { $Script:ConfigDir = Join-Path $Script:BaseDir 'configs' }
if (-not $Script:MaintLogDir) {
    $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
    $Script:MaintLogDir = Join-Path $Script:BaseDir "generated/logs/$($isTesting ? 'testing' : 'audit')"
}
if (-not $Script:DistList) { $Script:DistList = Join-Path $Script:BaseDir 'maintenance_distribution_list.txt' }

if (-not (Test-Path $Script:MaintLogDir)) { Ensure-DirectoryExists -Path $Script:MaintLogDir }

# ---- Logging ----
Initialize-Logging -LogFile 'maintenance.log'

# ---- Connection validation helpers ----
function Test-ScomConnection {
    param(
        [string]$ManagementServer,
        [string]$Username,
        [string]$Password,
        [string]$ModuleName = 'OperationsManager'
    )
    
    try {
        $scriptContent = @"
Import-Module $ModuleName -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$Password' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$Username', `$securePass)
`$conn = New-SCOMManagementGroupConnection -ComputerName '$ManagementServer' -Credential `$cred -ErrorAction Stop
Write-Output "CONNECTED"
"@
        $result = Invoke-PowerShellScript -Script $scriptContent
        return $result.Success -and ($result.Output -match 'CONNECTED')
    } catch {
        Write-Warning "SCOM connection test failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-OneViewConnection {
    param(
        [string]$Appliance,
        [string]$Username,
        [string]$Password,
        [string]$ModuleName = 'HPOneView.Managed'
    )
    
    try {
        $scriptContent = @"
Import-Module $ModuleName -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$Password' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$Username', `$securePass)
Connect-OVMgmt -Appliance '$Appliance' -Credential `$cred -ErrorAction Stop
Write-Output "CONNECTED"
Disconnect-OVMgmt -ErrorAction SilentlyContinue
"@
        $result = Invoke-PowerShellScript -Script $scriptContent
        return $result.Success -and ($result.Output -match 'CONNECTED')
    } catch {
        Write-Warning "OneView connection test failed: $($_.Exception.Message)"
        return $false
    }
}

# ---- Parse datetime helpers ----
function _Parse-Datetime([string]$s) {
    if ($s.ToLower() -eq 'now') { return [DateTime]::UtcNow }
    
    # Handle relative time offsets like +1hour, +30minutes, +2days
    if ($s -match '^\+([\d]+)(seconds?|minutes?|hours?|days?)$') {
        $value = [int]$Matches[1]
        $unit = $Matches[2].ToLower()
        $offset = switch ($unit) {
            'second' { [TimeSpan]::FromSeconds($value) }
            'seconds' { [TimeSpan]::FromSeconds($value) }
            'minute' { [TimeSpan]::FromMinutes($value) }
            'minutes' { [TimeSpan]::FromMinutes($value) }
            'hour' { [TimeSpan]::FromHours($value) }
            'hours' { [TimeSpan]::FromHours($value) }
            'day' { [TimeSpan]::FromDays($value) }
            'days' { [TimeSpan]::FromDays($value) }
            default { [TimeSpan]::Zero }
        }
        return ([DateTime]::UtcNow).Add($offset)
    }
    
    $s2 = $s.Replace('T', ' ')
    $formats = @('yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm')
    foreach ($fmt in $formats) {
        try { 
            $parsed = [DateTime]::ParseExact($s2, $fmt, $null)
            return [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
        } catch { continue }
    }
    try { 
        $parsed = [DateTime]::Parse($s2)
        return [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
    } catch { Write-Debug "DateTime parse failed" }
    throw "Invalid datetime format '$s'. Use 'now', '+1hour', or 'YYYY-MM-DD HH:MM[:SS]'."
}

function _Compute-DefaultEnd([DateTime]$After) {
    # Default end time: 7am UTC Monday following the start time
    $candidate = $After.Date
    $daysUntilMonday = [int][DayOfWeek]::Monday - [int]$candidate.DayOfWeek
    if ($daysUntilMonday -lt 0) { $daysUntilMonday += 7 }
    $monday = $candidate.AddDays($daysUntilMonday)
    $defaultEnd = $monday.Date.AddHours(7)
    if ($defaultEnd -le $After) { $defaultEnd = $defaultEnd.AddDays(7) }
    return [DateTime]::SpecifyKind($defaultEnd, [DateTimeKind]::Utc)
}

function _Compute-NextWorkStart([hashtable]$Schedule, [DateTime]$After) {
    $workStartStr = $Schedule.Get_Item('work_start') ?? '08:00'
    $workStart = [DateTime]::ParseExact($workStartStr, 'HH:mm', $null).TimeOfDay
    $dayMap = @{ Sun = 0; Mon = 1; Tue = 2; Wed = 3; Thu = 4; Fri = 5; Sat = 6 }
    $workDays = @($Schedule.Get_Item('work_days') ?? @('Mon', 'Tue', 'Wed', 'Thu', 'Fri')) | ForEach-Object { $dayMap[$_] }
    $candidate = $After.Date
    while ($true) {
        if ($candidate.DayOfWeek -in $workDays) {
            $dt = $candidate.Date + $workStart
            if ($dt -gt $After) { return $dt }
        }
        $candidate = $candidate.AddDays(1)
    }
}

function _Save-AuditRecord([hashtable]$Audit, [string]$Path) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    # Add GitLab context if available
    if ($Script:GitlabContext) {
        $Audit.gitlab_context = $Script:GitlabContext
    }
    
    $Audit | ConvertTo-Json -Depth 64 | Set-Content -Path $Path -Encoding UTF8 -Force
    # Append to master log
    $ts = Get-UtcFileTimestamp
    $master = Join-Path $Script:MaintLogDir "maintenance_audit_${ts}_INFO.log"
    $Audit | ConvertTo-Json -Depth 64 | Add-Content $master -Encoding UTF8
}

# ---- SCOMManager ----
class SCOMManager {
    [hashtable] $Config
    [string]    $MgmtServer
    [string]    $ModuleName
    [bool]      $UseWinRM
    [hashtable] $Cred
    [int]       $ScomVersion       # 2012 | 2016 | 2019 | 2025
    [bool]      $RestApiReady      # $true for 2019 UR1+ and 2025

    SCOMManager([hashtable]$Config) {
        $this.Config = $Config
        $this.MgmtServer = $Config.Get_Item('management_server') ?? 'localhost'
        $this.ModuleName = $Config.Get_Item('powershell_module') ?? 'OperationsManager'
        $this.UseWinRM = [bool]($Config.Get_Item('use_winrm') ?? $false)
        $this.Cred = $null
        $this.ScomVersion = 0
        $this.RestApiReady = $false
        $credCfg = $Config.Get_Item('credentials')
        if ($credCfg) {
            $uenv = $credCfg.Get_Item('username_env')
            $penv = $credCfg.Get_Item('password_env')
            if ($uenv -and $penv) {
                $u = [System.Environment]::GetEnvironmentVariable($uenv)
                $p = [System.Environment]::GetEnvironmentVariable($penv)
                if ($u -and $p) { $this.Cred = @{ username = $u; password = $p } }
            }
        }
        # Detect SCOM version and REST-API readiness on first use (lazy, on demand)
    }

    [hashtable] _RunPs([string]$Script) {
        if ($this.UseWinRM) {
            if (-not $this.Cred) { return @{ Success = $false; Output = 'WinRM credentials not configured' } }
            return Invoke-PowerShellWinRM -Script $Script `
                -Server $this.MgmtServer -Username $this.Cred['username'] -Password $this.Cred['password']
        }
        else {
            return Invoke-PowerShellScript -Script $Script
        }
    }

    [void] _DetectVersion() {
        if ($this.ScomVersion -gt 0) { return }
        if (-not $this.Cred) { return }
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$null = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$verLine = (Get-SCOMManagementServer | Select-Object -First 1).Version
`$ver = if (`$verLine) { `$verLine.Trim() } else { 'unknown' }
# Test whether REST /authenticate endpoint responds
`$restOk = `$false
try {
    `$base = "http://$($this.MgmtServer)/OperationsManager"
    `$null = Invoke-WebRequest -Uri "`$base/authenticate" -Method Head `
        -TimeoutSec 5 -UseDefaultCredentials -ErrorAction Stop
    `$restOk = `$true
} catch { `$restOk = `$false }
Write-Output "SCOM_VERSION: `$ver"
Write-Output "SCOM_REST_READY: `$restOk"
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            foreach ($line in ($r.Output -split "`n")) {
                $trimmed = $line.Trim()
                if ($trimmed -match '^SCOM_VERSION:\s*(\d+)')         { $this.ScomVersion = [int]$Matches[1] }
                if ($trimmed -match '^SCOM_REST_READY:\s*(True|true)') { $this.RestApiReady = $true }
            }
        }
        if ($this.ScomVersion -eq 0) { $this.ScomVersion = 2016 }   # safe default
        Write-Verbose "SCOM version detected: $($this.ScomVersion), REST ready: $($this.RestApiReady)"
    }

    [object[]] GetGroupMembers([string]$GroupDisplayName) {
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction SilentlyContinue
if (-not `$group) { Write-Error "Group '$GroupDisplayName' not found"; exit 1 }
`$instances = Get-SCOMClassInstance -Group `$group
`$instances | ForEach-Object { `$_.Name }
"@
        $r = $this._RunPs($script)
        if (-not $r.Success) { return @() }
        return ($r.Output -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
    }

    [hashtable] EnterMaintenance([string]$GroupDisplayName, [TimeSpan]$Duration,
        [string]$Comment, [bool]$DryRun = $false,
        [string[]]$ServerHostnames = $null,
        [bool]$UseClusterMode = $false) {

        if ($DryRun) {
            # Return mock per-object status data for DryRun testing
            # Based on clusters_catalogue.examples-only.json template
            $mockServers = if ($ServerHostnames) { $ServerHostnames } else { @('mock-server-01.example.com', 'mock-server-02.example.com', 'mock-server-03.example.com') }
            $mockObjects = @()
            foreach ($srv in $mockServers) {
                $mockObjects += @{
                    Name = $srv
                    Type = 'WindowsComputer'
                    Action = 'enable'
                    Status = 'success'
                    Message = 'Maintenance mode enabled (DryRun)'
                    NackReason = $null
                    Resolution = $null
                }
            }
            $mockObjects += @{
                Name = $GroupDisplayName
                Type = 'WindowsCluster'
                Action = 'enable'
                Status = 'success'
                Message = 'Cluster maintenance mode enabled (DryRun)'
                NackReason = $null
                Resolution = $null
            }
            $mockSummary = @{
                Total = $mockObjects.Count
                Success = $mockObjects.Count
                AlreadyInMaintenance = 0
                Failed = 0
            }
            Write-Verbose "[DRY RUN] Would enable SCOM maintenance for group '$GroupDisplayName' ($($mockObjects.Count) objects)"
            return @{ Success = $true; Output = @(); Objects = $mockObjects; Summary = $mockSummary }
        }

        $this._DetectVersion()

        $endTimeUtc = [DateTime]::UtcNow.Add($Duration)
        $endTimeStr = $endTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss')
        $safeComment = $Comment.Replace("'", "''")

        # ── SCOM 2019 UR1+ and 2025: use REST API ────────────────────────────
        if ($this.ScomVersion -ge 2019 -and $this.RestApiReady) {
            return $this._EnterMaintenanceRest($endTimeStr, $safeComment, $ServerHostnames, $UseClusterMode)
        }

        # ── 2012 / 2016 / 2019-without-REST: use PowerShell cmdlets ───────────
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -EndTimeStr $endTimeStr -Reason 'PlannedOther' -Comment $safeComment -Operation 'start' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                -EndTimeStr $endTimeStr -Reason 'PlannedOther' -Comment $safeComment -Operation 'start'
        }
        $r = $this._RunPs($script)

        # Parse per-object status and summary from output
        $objects = @()
        $summary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
        foreach ($line in ($r.Output -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^OBJECT_STATUS:(\{.*\})$') {
                try {
                    $obj = $Matches[1] | ConvertFrom-Json
                    $objects += @{
                        Name = $obj.name
                        Type = $obj.type
                        Action = $obj.action
                        Status = $obj.status
                        Message = if ($obj.PSObject.Properties['message']) { $obj.message } else { '' }
                        NackReason = if ($obj.PSObject.Properties['nack_reason']) { $obj.nack_reason } else { $null }
                        Resolution = if ($obj.PSObject.Properties['resolution']) { $obj.resolution } else { $null }
                    }
                    switch ($obj.status) {
                        'success' { $summary.Success++ }
                        'already_in_maintenance' { $summary.AlreadyInMaintenance++ }
                        default { $summary.Failed++ }
                    }
                } catch { continue }
            }
            elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                try {
                    $sum = $Matches[1] | ConvertFrom-Json
                    if ($sum.PSObject.Properties['total_objects']) { $summary.Total = $sum.total_objects }
                } catch { continue }
            }
        }
        $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
        if ($summary.Total -eq 0) { $summary.Total = $objects.Count }

        if ($r.Success) {
            Write-Verbose "SCOM maintenance enabled: $($objects.Count) objects processed"
            return @{ Success = $true; Output = @($r.Output); Objects = $objects; Summary = $summary }
        }
        Write-Error "SCOM maintenance failed: $($r.Output)"
        return @{ Success = $false; Output = @($r.Output); Objects = $objects; Summary = $summary }
    }

    [hashtable] ExitMaintenance([string]$GroupDisplayName, [bool]$DryRun = $false,
        [string[]]$ServerHostnames = $null,
        [bool]$UseClusterMode = $false) {

        if ($DryRun) {
            # Return mock per-object status data for DryRun testing
            $mockServers = if ($ServerHostnames) { $ServerHostnames } else { @('mock-server-01.example.com', 'mock-server-02.example.com', 'mock-server-03.example.com') }
            $mockObjects = @()
            foreach ($srv in $mockServers) {
                $mockObjects += @{
                    Name = $srv
                    Type = 'WindowsComputer'
                    Action = 'disable'
                    Status = 'success'
                    Message = 'Maintenance mode stopped (DryRun)'
                    NackReason = $null
                    Resolution = $null
                }
            }
            $mockObjects += @{
                Name = $GroupDisplayName
                Type = 'WindowsCluster'
                Action = 'disable'
                Status = 'success'
                Message = 'Cluster maintenance mode stopped (DryRun)'
                NackReason = $null
                Resolution = $null
            }
            $mockSummary = @{
                Total = $mockObjects.Count
                Success = $mockObjects.Count
                NotInMaintenance = 0
                Failed = 0
            }
            Write-Verbose "[DRY RUN] Would disable SCOM maintenance for group '$GroupDisplayName' ($($mockObjects.Count) objects)"
            return @{ Success = $true; Output = @(); Objects = $mockObjects; Summary = $mockSummary }
        }

        $this._DetectVersion()

        # ── SCOM 2019 UR1+ and 2025: use REST API ────────────────────────────
        if ($this.ScomVersion -ge 2019 -and $this.RestApiReady) {
            $r = $this._ExitMaintenanceRest($GroupDisplayName, $ServerHostnames, $UseClusterMode)
            $objects = @()
            $summary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
            foreach ($line in ($r.Output -split "`n")) {
                $trimmed = $line.Trim()
                if ($trimmed -match '^OBJECT_STATUS:(\{.*\})$') {
                    try {
                        $obj = $Matches[1] | ConvertFrom-Json
                        $objects += @{
                            Name = $obj.name
                            Type = $obj.type
                            Action = $obj.action
                            Status = $obj.status
                            Message = if ($obj.PSObject.Properties['message']) { $obj.message } else { '' }
                            NackReason = if ($obj.PSObject.Properties['nack_reason']) { $obj.nack_reason } else { $null }
                            Resolution = if ($obj.PSObject.Properties['resolution']) { $obj.resolution } else { $null }
                        }
                        switch ($obj.status) {
                            'success' { $summary.Success++ }
                            'not_in_maintenance' { $summary.NotInMaintenance++ }
                            default { $summary.Failed++ }
                        }
                    } catch { continue }
                }
                elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                    try {
                        $sum = $Matches[1] | ConvertFrom-Json
                        if ($sum.PSObject.Properties['total_objects']) { $summary.Total = $sum.total_objects }
                    } catch { continue }
                }
            }
            $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
            if ($summary.Total -eq 0) { $summary.Total = $objects.Count }
            return @{ Success = $r.Success; Output = @($r.Output); Objects = $objects; Summary = $summary }
        }

        # ── 2012 / 2016 / 2019-without-REST: use PowerShell cmdlets ───────────
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -Comment 'exit' -Operation 'stop' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                -Comment 'exit' -Operation 'stop'
        }
        $r = $this._RunPs($script)

        # Parse per-object status and summary from output
        $objects = @()
        $summary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
        foreach ($line in ($r.Output -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^OBJECT_STATUS:(\{.*\})$') {
                try {
                    $obj = $Matches[1] | ConvertFrom-Json
                    $objects += @{
                        Name = $obj.name
                        Type = $obj.type
                        Action = $obj.action
                        Status = $obj.status
                        Message = if ($obj.PSObject.Properties['message']) { $obj.message } else { '' }
                        NackReason = if ($obj.PSObject.Properties['nack_reason']) { $obj.nack_reason } else { $null }
                        Resolution = if ($obj.PSObject.Properties['resolution']) { $obj.resolution } else { $null }
                    }
                    switch ($obj.status) {
                        'success' { $summary.Success++ }
                        'not_in_maintenance' { $summary.NotInMaintenance++ }
                        default { $summary.Failed++ }
                    }
                } catch { continue }
            }
            elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                try {
                    $sum = $Matches[1] | ConvertFrom-Json
                    if ($sum.PSObject.Properties['total_objects']) { $summary.Total = $sum.total_objects }
                } catch { continue }
            }
        }
        $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
        if ($summary.Total -eq 0) { $summary.Total = $objects.Count }

        Write-Verbose "SCOM maintenance disable output: $($r.Output)"
        return @{ Success = $r.Success; Output = @($r.Output); Objects = $objects; Summary = $summary }
    }

    # ════════════════════════════════════════════════════════════════════════
    # PRIVATE — SCOM REST API helpers (2019 UR1+ and 2025 only)
    # ════════════════════════════════════════════════════════════════════════

    [hashtable] _EnterMaintenanceRest([string]$EndTimeStr, [string]$Comment,
        [string[]]$ServerHostnames, [bool]$UseClusterMode) {

        if (-not $this.Cred) { return @{ Success = $false; Output = 'No SCOM REST credentials' } }

        # The REST script authenticates, resolves monitoring object IDs, calls POST /ScheduleMaintenance
        $serverJson = ($ServerHostnames | ForEach-Object { "`"$($_.Replace('"','\"'))`"" }) -join ","
        $script = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$server     = "$($this.MgmtServer)"
`$user       = "$($this.Cred['username'])"
`$pass       = "$($this.Cred['password'])"
`$baseUrl    = "http://`$server/OperationsManager"
`$endTime    = [DateTime]::Parse('$EndTimeStr')
`$endIso     = `$endTime.ToString('yyyy-MM-ddTHH:mm:ss')
`$comment    = '$Comment'

# ── Authenticate and obtain CSRF token ────────────────────────────────────
`$headers   = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
`$headers.Add('Content-Type','application/json; charset=utf-8')
`$bodyRaw   = "(Network):`$user:`$pass"
`$bytes     = [System.Text.Encoding]::UTF8.GetBytes(`$bodyRaw)
`$encAuth   = [Convert]::ToBase64String(`$bytes)
`$jsonBody  = `$encAuth | ConvertTo-Json
`$session   = `$null
try {
    `$resp = Invoke-WebRequest -Method POST -Uri "`$baseUrl/authenticate" `
        -Headers `$headers -Body `$jsonBody -UseDefaultCredentials -SessionVariable session
} catch {
    Write-Error "SCOM REST authentication failed: `$(`$_.Exception.Message)"
    exit 1
}
`$csrf = `$session.Cookies.GetCookies(`$baseUrl) | Where-Object { `$_.Name -eq 'SCOM-CSRF-TOKEN' }
if (`$csrf) { `$headers.Add('SCOM-CSRF-TOKEN', [System.Web.HttpUtility]::UrlDecode(`$csrf.Value)) }

# ── Resolve monitoring object IDs ─────────────────────────────────────────
`$ids     = [System.Collections.ArrayList]::new()
`$servers = @($serverJson)
foreach (`$srvName in `$servers) {
    try {
        `$bodyCriteria = "DisplayName LIKE '%`$srvName%'" | ConvertTo-Json
        `$classResp = Invoke-WebRequest -Uri "`$baseUrl/data/class/monitors" `
            -Method Post -Body `$bodyCriteria -Headers `$headers -WebSession `$session `
            -ErrorAction Stop
        `$classData = `$classResp.Content | ConvertFrom-Json
        foreach (`$obj in `$classData) {
            if (`$obj.Id) { [void]`$ids.Add([string]`$obj.Id) }
        }
    } catch {
        Write-Warning "Could not resolve ID for `$srvName : `$(`$_.Exception.Message)"
    }
}
if (`$ids.Count -eq 0) {
    Write-Error "No monitoring object IDs resolved for: $($ServerHostnames -join ', ')"
    Write-Error "Please verify the servers are monitored by this SCOM management group."
    exit 1
}

# ── Call POST /ScheduleMaintenance ────────────────────────────────────────
`$durationMin = [int](`$endTime - [DateTime]::UtcNow).TotalMinutes
`$freqType = 8   # 8 = OneTimeSchedule as per REST API docs
`$reqBody = @{
    scheduleName          = 'MaintenanceMode_PowerShell'
    monitoringObjectsId   = @(`$ids)
    startTime             = Get-UtcApiTimestamp
    duration              = [Math]::Max(1, `$durationMin)
    freqType              = `$freqType
    category              = 0
    scheduleEffectiveFrom = Get-UtcApiTimestamp
    recursive             = `$true
    enabled               = `$true
    comment               = `$comment
} | ConvertTo-Json -Depth 5
try {
    `$result = Invoke-WebRequest -Uri "`$baseUrl/ScheduleMaintenance" `
        -Method Post -Body `$reqBody -Headers `$headers -ContentType 'application/json' `
        -WebSession `$session -ErrorAction Stop
    Write-Host "SCOM REST maintenance scheduled. IDs: `$(`$result.Content)"
    exit 0
} catch {
    Write-Error "SCOM REST maintenance failed: `$(`$_.Exception.Message)"
    exit 1
}
"@
        $r = $this._RunPs($script)
        return @{ Success = $r.Success; Output = @($r.Output) }
    }

    [hashtable] _ExitMaintenanceRest([string]$GroupDisplayName, [string[]]$ServerHostnames, [bool]$UseClusterMode) {
        if (-not $this.Cred) { return @{ Success = $false; Output = 'No SCOM REST credentials' } }

        # Exit maintenance for REST SCOM:
        # Use PowerShell cmdlets to disable because the REST API does not expose
        # a direct maintenanceMode 'stop' endpoint.
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -Comment 'exit' -Operation 'stop' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                -Comment 'exit' -Operation 'stop'
        }
        if (-not $script) {
            $serverJson = if ($ServerHostnames) { ($ServerHostnames | ForEach-Object { "`"$($_.Replace('"','\"'))`"" }) -join "," } else { '' }
            $endTimeStr = Get-UtcApiTimestamp
            $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$stopped = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        try { `$inst.StopMaintenanceMode(); `$stopped += `$inst.Name } catch { Write-Warning "`$(`$inst.Name): `$(`$_.Exception.Message)" }
    } else { Write-Host "`$(`$inst.Name) not in maintenance - skipping" }
}
if (`$stopped.Count -gt 0) { Write-Host "Stopped maintenance for `$(`$stopped.Count) instances" } else { Write-Host "No instances were in maintenance" }
"@
        }
        $r = $this._RunPs($script)
        return @{ Success = $r.Success; Output = @($r.Output) }
    }
}

# ---- OneViewClient ----
class OneViewClient {
    [hashtable] $Config
    [string]    $Appliance
    [string]    $ModuleName
    [bool]      $UseWinRM
    [string]    $WinRMServer
    [string]    $Username
    [string]    $Password

    OneViewClient([hashtable]$Config) {
        $ovConfig = $Config.Get_Item('oneview') ?? @{}
        $this.Config = $ovConfig
        $this.Appliance = $ovConfig.Get_Item('appliance') ?? 'oneview.example.com'
        $this.ModuleName = $ovConfig.Get_Item('module_name') ?? 'HPOneView.Managed'
        $this.UseWinRM = [bool]($ovConfig.Get_Item('use_winrm') ?? $false)
        if ($this.UseWinRM) {
            $winrmCfg = $ovConfig.Get_Item('winrm') ?? @{}
            $this.WinRMServer = $winrmCfg.Get_Item('server') ?? $this.Appliance
        }
        $credCfg = $ovConfig.Get_Item('credentials') ?? @{}
        $userEnv = $credCfg.Get_Item('username_env') ?? 'ONEVIEW_USER'
        $passEnv = $credCfg.Get_Item('password_env') ?? 'ONEVIEW_PASSWORD'
        $this.Username = [System.Environment]::GetEnvironmentVariable($userEnv)
        $this.Password = [System.Environment]::GetEnvironmentVariable($passEnv)
        
        # Allow override after construction via direct property assignment
    }

    [hashtable] SetMaintenance([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        if ($this.UseWinRM) {
            return $this._SetViaWinRM($Target, $TargetType, $StartDt, $EndDt, $DryRun)
        }
        return $this._SetViaModule($Target, $TargetType, $StartDt, $EndDt, $DryRun)
    }

    [hashtable] _SetViaModule([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView maintenance for $TargetType '$Target'"; Objects = @() }
        }
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
`$objects = @()
`$success = 0
`$failed = 0
`$alreadyInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{
        Name = `$server.Name
        Type = `$server.Type
        Status = 'unknown'
        Message = ''
    }
    try {
        if (`$server.MaintenanceModeEnabled) {
            `$obj.Status = 'already_in_maintenance'
            `$obj.Message = 'Already in maintenance mode'
            `$alreadyInMaintenance++
        } else {
            Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode enabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
        `$obj.Resolution = 'Check OneView appliance logs and permissions'
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVScope -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{
            Name = `$server.Name
            Type = `$server.Type
            Status = 'unknown'
            Message = ''
        }
        try {
            if (`$server.MaintenanceModeEnabled) {
                `$obj.Status = 'already_in_maintenance'
                `$obj.Message = 'Already in maintenance mode'
                `$alreadyInMaintenance++
            } else {
                Enable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode enabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
            `$obj.Resolution = 'Check OneView appliance logs and permissions'
            `$failed++
        }
        `$objects += `$obj
    }
}
`$result = @{
    Success = (`$failed -eq 0)
    Message = "OneView maintenance: `$success succeeded, `$alreadyInMaintenance already, `$failed failed"
    Objects = `$objects
    Summary = @{ Total = `$objects.Count; Success = `$success; AlreadyInMaintenance = `$alreadyInMaintenance; Failed = `$failed }
}
`$result | ConvertTo-Json -Depth 5
"@
        try {
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent))
                Remove-PSSession $session
            } else {
                $output = Invoke-Expression $scriptContent
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success = $result.Success
                Message = $result.Message
                Objects = @($result.Objects | ForEach-Object { $_ })
                Summary = @{
                    Total = $result.Summary.Total
                    Success = $result.Summary.Success
                    AlreadyInMaintenance = $result.Summary.AlreadyInMaintenance
                    Failed = $result.Summary.Failed
                }
            }
        }
        catch {
            return @{
                Success = $false
                Message = "OneView maintenance failed: $($_.Exception.Message)"
                Objects = @()
                Summary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 1 }
            }
        }
    }

    [hashtable] _SetViaWinRM([object]$Target, [string]$TargetType, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        return $this._SetViaModule($Target, $TargetType, $StartDt, $EndDt, $DryRun)
    }

    [hashtable] DisableMaintenance([object]$Target, [string]$TargetType, [bool]$DryRun) {
        if ($this.UseWinRM) {
            return $this._DisableViaWinRM($Target, $TargetType, $DryRun)
        }
        return $this._DisableViaModule($Target, $TargetType, $DryRun)
    }

    [hashtable] _DisableViaModule([object]$Target, [string]$TargetType, [bool]$DryRun) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        if ($DryRun) {
            return @{ Success = $true; Message = "[DRY RUN] OneView disable maintenance for $TargetType '$Target'"; Objects = @() }
        }
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
`$objects = @()
`$success = 0
`$failed = 0
`$notInMaintenance = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{
        Name = `$server.Name
        Type = `$server.Type
        Status = 'unknown'
        Message = ''
    }
    try {
        if (-not `$server.MaintenanceModeEnabled) {
            `$obj.Status = 'not_in_maintenance'
            `$obj.Message = 'Not in maintenance mode'
            `$notInMaintenance++
        } else {
            Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
            `$obj.Status = 'success'
            `$obj.Message = 'Maintenance mode disabled'
            `$success++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
        `$obj.Resolution = 'Check OneView appliance logs and permissions'
        `$failed++
    }
    `$objects += `$obj
} elseif ('$TargetType' -eq 'Scope') {
    `$scope = Get-OVSCOPE -Name '$Target' -ErrorAction Stop
    `$servers = `$scope.Members | Where-Object { `$_.Type -eq 'ServerHardware' }
    foreach (`$member in `$servers) {
        `$server = Get-OVServer -Name `$member.Name -ErrorAction SilentlyContinue
        if (-not `$server) { continue }
        `$obj = @{
            Name = `$server.Name
            Type = `$server.Type
            Status = 'unknown'
            Message = ''
        }
        try {
            if (-not `$server.MaintenanceModeEnabled) {
                `$obj.Status = 'not_in_maintenance'
                `$obj.Message = 'Not in maintenance mode'
                `$notInMaintenance++
            } else {
                Disable-OVMaintenanceMode -InputObject `$server -ErrorAction Stop | Out-Null
                `$obj.Status = 'success'
                `$obj.Message = 'Maintenance mode disabled'
                `$success++
            }
        } catch {
            `$obj.Status = 'failed'
            `$obj.Message = `$_.Exception.Message
            `$obj.NackReason = 'OneView API error: ' + `$_.Exception.Message
            `$obj.Resolution = 'Check OneView appliance logs and permissions'
            `$failed++
        }
        `$objects += `$obj
    }
}
`$result = @{
    Success = (`$failed -eq 0)
    Message = "OneView disable maintenance: `$success succeeded, `$notInMaintenance not in maintenance, `$failed failed"
    Objects = `$objects
    Summary = @{ Total = `$objects.Count; Success = `$success; NotInMaintenance = `$notInMaintenance; Failed = `$failed }
}
`$result | ConvertTo-Json -Depth 5
"@
        try {
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent))
                Remove-PSSession $session
            } else {
                $output = Invoke-Expression $scriptContent
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success = $result.Success
                Message = $result.Message
                Objects = @($result.Objects | ForEach-Object { $_ })
                Summary = @{
                    Total = $result.Summary.Total
                    Success = $result.Summary.Success
                    NotInMaintenance = $result.Summary.NotInMaintenance
                    Failed = $result.Summary.Failed
                }
            }
        }
        catch {
            return @{
                Success = $false
                Message = "OneView disable maintenance failed: $($_.Exception.Message)"
                Objects = @()
                Summary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 1 }
            }
        }
    }

    [hashtable] _DisableViaWinRM([object]$Target, [string]$TargetType, [bool]$DryRun) {
        return $this._DisableViaModule($Target, $TargetType, $DryRun)
    }

    [hashtable] ResolveTarget([string]$TargetId, [bool]$DryRun) {
        # Return mock data for DryRun mode - allows testing without OneView module
        if ($DryRun) {
            return @{
                Success = $true
                TargetType = 'Scope'
                TargetName = $TargetId
                Message = 'Found scope (cluster) [DRY-RUN]'
            }
        }
        $ovModule = $this.ModuleName
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
Connect-OVMgmt -Appliance '$($this.Appliance)' -Credential `$cred -ErrorAction Stop
`$server = Get-OVServer -Name '$TargetId' -ErrorAction SilentlyContinue
if (`$server) {
    `$result = @{ Success = `$true; TargetType = 'ServerHardware'; TargetName = `$server.Name; Message = 'Found server' }
    `$result | ConvertTo-Json -Depth 3
    return
}
`$scope = Get-OVSCOPE -Name '$TargetId' -ErrorAction SilentlyContinue
if (`$scope) {
    `$result = @{ Success = `$true; TargetType = 'Scope'; TargetName = `$scope.Name; Message = 'Found scope (cluster)' }
    `$result | ConvertTo-Json -Depth 3
    return
}
`$result = @{ Success = `$false; TargetType = 'Unknown'; TargetName = '$TargetId'; Message = 'Not found as server or scope' }
`$result | ConvertTo-Json -Depth 3
"@
        try {
            if ($this.UseWinRM) {
                $session = New-PSSession -ComputerName $this.WinRMServer
                $output = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($scriptContent))
                Remove-PSSession $session
            } else {
                $output = Invoke-Expression $scriptContent
            }
            $result = $output | ConvertFrom-Json
            return @{
                Success = $result.Success
                TargetType = $result.TargetType
                TargetName = $result.TargetName
                Message = $result.Message
            }
        }
        catch {
            return @{
                Success = $false
                TargetType = 'Unknown'
                TargetName = $TargetId
                Message = "Resolve failed: $($_.Exception.Message)"
            }
        }
    }
}

# ---- EmailNotifier ----
class EmailNotifier {
    [hashtable] $Config
    [string]    $SmtpServer
    [int]       $SmtpPort
    [bool]      $UseTls
    [bool]      $UseSsl
    [string]    $FromAddr
    [hashtable] $Templates
    [bool]      $UseSimple
    [string[]]  $SimpleRecipients
    [hashtable] $DistLists

    EmailNotifier([hashtable]$Config) {
        $this.Config = $Config.Get_Item('email') ?? @{}
        $this.SmtpServer = $this.Config.Get_Item('smtp_server') ?? 'localhost'
        $this.SmtpPort = ($this.Config.Get_Item('smtp_port') ?? 25)
        $this.UseTls = [bool]($this.Config.Get_Item('use_tls') ?? $false)
        $this.UseSsl = [bool]($this.Config.Get_Item('use_ssl') ?? $false)
        $this.FromAddr = $this.Config.Get_Item('from_address') ?? 'maintenance-bot@example.com'
        $this.Templates = $this.Config.Get_Item('templates') ?? @{}
        $this.UseSimple = $false
        $this.DistLists = $this.Config.Get_Item('distribution_lists') ?? @{}
        if (Test-Path $Script:DistList) {
            $this.SimpleRecipients = Get-Content $Script:DistList | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() }
            $this.UseSimple = ($this.SimpleRecipients.Count -gt 0)
        }
    }

    [string[]] _GetRecipients([string]$Action) {
        if ($this.UseSimple) { return $this.SimpleRecipients }
        $key = "maintenance_$Action"
        if ($this.DistLists.ContainsKey($key)) { return $this.DistLists[$key] }
        return @()
    }

    [bool] SendMaintenanceNotification([string]$Action, [hashtable]$Cluster, [string[]]$Servers,
        [Nullable[DateTime]]$StartTime, [Nullable[DateTime]]$EndTime, [bool]$DryRun) {
        $recipients = $this._GetRecipients($Action)
        if (-not $recipients) {
            Write-Warning "No distribution list for action '$Action'; skipping email"
            return $false
        }
        $clusterName = $Cluster.Get_Item('display_name') ?? $Cluster.Get_Item('scom_group') ?? 'Unknown'
        $environment = $Cluster.Get_Item('environment') ?? 'unknown'
        $startStr = if ($StartTime -and $StartTime -ne [DateTime]::MinValue) { $StartTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
        $endStr = if ($EndTime -and $EndTime -ne [DateTime]::MinValue) { $EndTime.ToString('yyyy-MM-dd HH:mm:ss') }  else { 'N/A' }
        $tplVars = @{
            cluster_name    = $clusterName
            environment     = $environment
            servers         = ($Servers -join ', ')
            start_time      = $startStr
            end_time        = $endStr
            triggered_by    = 'iRequest'
            additional_info = if ($Action -eq 'enabled') { 'Maintenance mode is now ACTIVE.' }
            elseif ($Action -eq 'disabled') { 'Maintenance mode has ENDED.' }
            else { "Maintenance action: $Action" }
        }
        $subjTpl = $this.Templates.Get_Item("subject_$Action") ?? "Maintenance {action} - {cluster_name} ({environment})"
        $subject = $subjTpl.Replace('{action}', $Action).Replace('{cluster_name}', $clusterName).Replace('{environment}', $environment)
        $bodyTpl = $this.Templates.Get_Item('body_template') ??
        "Dear Team,`n`nMaintenance window for cluster '$clusterName' has $Action.`n`nStart: $startStr`nEnd: $endStr`nServers: $($Servers -join ', ')`n`n$($tplVars['additional_info'])`n`nRegards,`nMaintenance Bot"
        $bodyAction = if ($Action -eq 'enabled') { 'been ENABLED' } elseif ($Action -eq 'disabled') { 'been DISABLED' } else { $Action }
        $body = $bodyTpl.Replace('{action}', $bodyAction)
        foreach ($k in $tplVars.Keys) { $body = $body.Replace("{${k}}", $tplVars[$k]); $subject = $subject.Replace("{${k}}", $tplVars[$k]) }

        if ($DryRun) {
            Write-Verbose "[DRY RUN] Email to: $($recipients -join ', ')"
            Write-Verbose "Subject: $subject"
            Write-Verbose "Body: $body"
            return $true
        }

        try {
            $mailMsg = New-Object System.Net.Mail.MailMessage($this.FromAddr, $recipients[0])
            foreach ($r in $recipients) { $mailMsg.To.Add($r) | Out-Null }
            $mailMsg.Subject = $subject
            $mailMsg.Body = $body
            $mailMsg.IsBodyHtml = $false
            $smtp = if ($this.UseSsl) {
                [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
            }
            else {
                $s = [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
                if ($this.UseTls) { $s.EnableSsl = $true }
                $s
            }
            if ($this.Username) {
                $sec = ConvertTo-SecureString $this.Password -AsPlainText -Force
                $smtp.Credentials = New-Object System.Management.Automation.PSCredential($this.Username, $sec)
            }
            $smtp.Send($mailMsg)
            Write-Verbose "Notification email sent to $($recipients -join ', ')"
            return $true
        }
        catch {
            Write-Error "Failed to send email: $($_.Exception.Message)"
            return $false
        }
    }
}

# ---- Main CLI logic (script mode only) ----
# When invoked with pwsh -File, PowerShell binds the param() block automatically.

if ($MyInvocation.InvocationName -ne '.' -and $null -ne $MyInvocation.PSScriptRoot) {
    $ErrorActionPreference = 'Continue'

    # Enforce mandatory parameters for CLI execution
    if (-not $TargetId -or -not $Mode) {
        Write-Error "TargetId and Mode are required for CLI execution."
        exit 1
    }

    # Debug: show variable state
    Write-Verbose "Script:BaseDir = '$Script:BaseDir'"
    Write-Verbose "Script:ConfigDir = '$Script:ConfigDir'"
    Write-Verbose "PSBoundParameters.ConfigDir = '$(if ($PSBoundParameters.ContainsKey('ConfigDir')) { 'SET' } else { 'NOT SET' })'"
    Write-Verbose "Environment = '$(if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } else { 'NOT SET - will use ENVIRONMENT env var or default to Prod' })'"
    Write-Verbose "ScomHost = '$(if ($PSBoundParameters.ContainsKey('ScomHost')) { $ScomHost } else { 'NOT SET' })'"
    Write-Verbose "OneViewHost = '$(if ($PSBoundParameters.ContainsKey('OneViewHost')) { $OneViewHost } else { 'NOT SET' })'"

    $result = Set-MaintenanceMode @PSBoundParameters

    # Add request metadata for traceability
    $result['request_type'] = "maintenance_$Action"
    $result['timestamp'] = Get-UtcTimestamp
    $result['timestamp_local'] = Get-LocalTimestamp
    $result['source'] = 'direct'

    if ($Json) {
        $result | ConvertTo-Json -Depth 64
        exit $(if ($result.Success) { 0 } else { 1 })
    }

    # Human-readable output
    Write-Host "=== Maintenance Mode Command Audit ==="
    Write-Host "Timestamp (UTC): $($result['timestamp'])"
    Write-Host "Timestamp (Local): $($result['timestamp_local'])"
    Write-Host "Action: $Action"
    Write-Host "Target ID: $TargetId"
    Write-Host "Target Object Name: $($result['ClusterName'] ?? $TargetId)"
    Write-Host "Mode: $Mode"
    if ($PSBoundParameters.ContainsKey('Environment')) {
        Write-Host "Environment: $Environment"
    }
    if ($PSBoundParameters.ContainsKey('ScomHost')) {
        Write-Host "SCOM Host: $ScomHost"
    }
    if ($PSBoundParameters.ContainsKey('OneViewHost')) {
        Write-Host "OneView Host: $OneViewHost"
    }
    if ($PSBoundParameters.ContainsKey('Username')) {
        Write-Host "Username: $Username"
    }
    Write-Host "Post-Disable Wait: ${PostDisableWaitSeconds}s"
    Write-Host "Config Dir: $ConfigDir"
    if ($Action -eq 'enable') {
        Write-Host "Start Time (UTC): $($result['StartTimeUtc'] ?? 'N/A')"
        Write-Host "End Time (UTC): $($result['EndTimeUtc'] ?? 'N/A')"
    }
    Write-Host "Dry Run: $DryRun"
    Write-Host "No Schedule: $NoSchedule"
    Write-Host "==================================="
    Write-Host ""

    # Per-object SCOM status table
    $scomObjects = $result['ScomObjects']
    $scomSummary = $result['ScomSummary']
    if ($scomObjects -and $scomObjects.Count -gt 0) {
        Write-Host "=== SCOM Per-Object Status ==="
        Write-Host "Total Objects: $($scomSummary.Total)"
        Write-Host "Success: $($scomSummary.Success)"
        Write-Host "Already in Maintenance: $($scomSummary.AlreadyInMaintenance ?? $scomSummary.NotInMaintenance ?? 0)"
        Write-Host "Failed: $($scomSummary.Failed)"
        Write-Host ""
        foreach ($obj in $scomObjects) {
            $statusIcon = switch ($obj.Status) {
                'success' { '[OK]' }
                'already_in_maintenance' { '[SKIP]' }
                'not_in_maintenance' { '[SKIP]' }
                default { '[FAIL]' }
            }
            Write-Host "${statusIcon} $($obj.Name) ($($obj.Type)) - $($obj.Status)"
            if ($obj.Message -and $obj.Status -ne 'success' -and $obj.Status -ne 'already_in_maintenance' -and $obj.Status -ne 'not_in_maintenance') {
                Write-Host "  Message: $($obj.Message)"
            }
            if ($obj.NackReason) {
                Write-Host "  NACK Reason: $($obj.NackReason)"
            }
            if ($obj.Resolution) {
                Write-Host "  Resolution: $($obj.Resolution)"
            }
        }
        Write-Host "==============================="
        Write-Host ""
    }

    # NACK summary for troubleshooting
    $failedObjects = $result['FailedObjects']
    if ($failedObjects -and $failedObjects.Count -gt 0) {
        Write-Host "=== NACK Summary (Failed Objects) ===" -ForegroundColor Red
        Write-Host "Total Failed: $($failedObjects.Count)"
        foreach ($obj in $failedObjects) {
            Write-Host "  - $($obj.Name): $($obj.NackReason ?? $obj.Status)"
            if ($obj.Resolution) { Write-Host "    Fix: $($obj.Resolution)" }
        }
        Write-Host "==================================="
        Write-Host ""
    }

    Write-Host "=== Command Result ==="
    Write-Host "Success: $($result.Success)"
    if ($result.Message) { Write-Host "Message: $($result.Message)" }
    if ($result.Error) { Write-Host "Error: $($result.Error)" }
    Write-Host "======================"

    exit $(if ($result.Success) { 0 } else { 1 })
}

# vim: ts=4 sw=4 et
