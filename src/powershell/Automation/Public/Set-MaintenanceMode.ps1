#
# Set-MaintenanceMode.ps1 - SCOM / OpenView maintenance-mode orchestrator
#
# Contains: Set-MaintenanceMode wrapper function, helper functions, manager classes,
#           and a script-mode guard for direct pwsh invocation.
#

# TODO(refactor): convert to function-mode per the public_commands_function_mode_only
# decision (remove this script-scope param block + bottom Main CLI entry; move
# Initialize-Logging into the function body). Deferred - low priority.
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
    [string] $ManagementHost,
    [string] $SerialNumber,
    [string] $Username,
    [int] $PostDisableWaitSeconds = 120,
    [string] $ConfigDir = 'configs',
    [string] $Start = $null,
    [string] $End = $null,
    [switch] $DryRun,
    [ValidateSet('enable', 'disable', 'partial')][string] $MockMaintenanceState = 'disable',
    [switch] $NoSchedule,
    [switch] $Json,
    [Alias('h', 'help', '?')][switch] $ShowHelp
)

# Handle help flag - display practical help and exit
if ($ShowHelp) {
    Write-Output ""
    Write-Output "NAME"
    Write-Output "    Set-MaintenanceMode"
    Write-Output ""
    Write-Output "SYNOPSIS"
    Write-Output "    Enable, disable, or validate maintenance mode for SCOM or OneView clusters."
    Write-Output ""
    Write-Output "SYNTAX"
    Write-Output "    Set-MaintenanceMode -TargetId <string> -Mode <scom|oneview>"
    Write-Output "        [-Action <enable|disable|validate>] [-Environment <Test|Prod>]"
    Write-Output "        [-ManagementHost <string>] [-SerialNumber <string>] [-Username <string>]"
    Write-Output "        [-Start <datetime>] [-End <datetime>]"
    Write-Output "        [-PostDisableWaitSeconds <int>] [-DryRun] [-NoSchedule] [-Json]"
    Write-Output ""
    Write-Output "DESCRIPTION"
    Write-Output "    Manages maintenance mode for server clusters in SCOM or HPE OneView."
    Write-Output "    Supports environment-based host selection from connection_hosts.json."
    Write-Output ""
    Write-Output "    IMPORTANT: All datetime values are UTC only. No local timezone conversion is performed."
    Write-Output ""
    Write-Output "PARAMETERS"
    Write-Output ""
    Write-Output "  -Action <enable|disable|validate>"
    Write-Output "    Operation to perform (default: enable)"
    Write-Output "    validate - Check actual maintenance mode status from SCOM/OneView"
    Write-Output ""
    Write-Output "  -TargetId <string> [REQUIRED]"
    Write-Output "    Cluster ID (starts with CLU-) or server name"
    Write-Output "    For SCOM: CLU- prefix = cluster mode, no prefix = single server"
    Write-Output "    For OneView: server name or cluster ID from catalogue"
    Write-Output ""
    Write-Output "  -Mode <scom|oneview> [REQUIRED]"
    Write-Output "    scom     - Manage via SCOM (Windows clusters/groups)"
    Write-Output "    oneview  - Manage via HPE OneView (hardware/servers)"
    Write-Output ""
    Write-Output "  -Environment <Test|Prod>"
    Write-Output "    Select environment for host resolution from connection_hosts.json"
    Write-Output "    Valid values: Test, Prod"
    Write-Output "    Default: Reads from `$env:ENVIRONMENT, then defaults to Prod"
    Write-Output ""
    Write-Output "  -ManagementHost <string>"
    Write-Output "    Override management server/appliance (takes precedence over environment config)"
    Write-Output ""
    Write-Output "  -SerialNumber <string>"
    Write-Output "    OneView only: look up server by serial number (Marin's preference)"
    Write-Output "    Invalid for SCOM mode - will return error if used"
    Write-Output ""
    Write-Output "  -Username <string>"
    Write-Output "    Direct username (testing only, not recommended for production)"
    Write-Output ""
    Write-Output "  -Start <datetime> / -End <datetime>"
    Write-Output "    Maintenance window times (UTC ONLY)"
    Write-Output "    Supported formats:"
    Write-Output "      now                    - Current UTC time"
    Write-Output "      +Xhours                - Relative hours (e.g., +2hours, +1hour)"
    Write-Output "      +Xminutes              - Relative minutes (e.g., +30minutes)"
    Write-Output "      +Xdays                 - Relative days (e.g., +1day, +7days)"
    Write-Output "      +Xseconds              - Relative seconds (e.g., +3600seconds)"
    Write-Output "      YYYY-MM-DD HH:MM       - Absolute UTC (e.g., 2026-06-11 22:00)"
    Write-Output "      YYYY-MM-DDTHH:MM:SS    - ISO 8601 UTC (e.g., 2026-06-11T22:00:00)"
    Write-Output ""
    Write-Output "  -PostDisableWaitSeconds <int>"
    Write-Output "    Wait after SCOM disable for stabilization (default: 120, set 0 to skip)"
    Write-Output ""
    Write-Output "  -DryRun"
    Write-Output "    Simulate without making changes"
    Write-Output ""
    Write-Output "  -MockMaintenanceState <enable|disable|partial>"
    Write-Output "    Dry-run only: mock validate status as enable, disable, or partial"
    Write-Output "    Default: disable"
    Write-Output ""
    Write-Output "  -NoSchedule"
    Write-Output "    Skip Windows Task Scheduler creation"
    Write-Output ""
    Write-Output "  -Json"
    Write-Output "    Output as JSON for API/iRequest integration"
    Write-Output ""
    Write-Output "EXAMPLES"
    Write-Output ""
    Write-Output "  # Validate configuration"
    Write-Output "  Set-MaintenanceMode -Action validate -TargetId 'CLU-CLUSTER-01' -Mode scom"
    Write-Output ""
    Write-Output "  # Enable in Test environment with relative time"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom \"
    Write-Output "      -Environment Test -Start 'now' -End '+2hours'"
    Write-Output ""
    Write-Output "  # Enable in Prod with absolute UTC time"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom \"
    Write-Output "      -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'"
    Write-Output ""
    Write-Output "  # Disable with custom stabilization wait"
    Write-Output "  Set-MaintenanceMode -Action disable -TargetId 'CLU-CLUSTER-01' -Mode scom \"
    Write-Output "      -Environment Prod -PostDisableWaitSeconds 60"
    Write-Output ""
    Write-Output "  # Dry run test"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom \"
    Write-Output "      -Environment Test -Start 'now' -End '+1hour' -DryRun"
    Write-Output ""
    Write-Output "  # Host override for emergency"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom \"
    Write-Output "      -Environment Prod -ManagementHost 'backup-server.local' -Start 'now' -End '+4hours'"
    Write-Output ""
    Write-Output "  # OneView with serial number (Marin's preference)"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'server01.ad.example.com' -Mode oneview \"
    Write-Output "      -SerialNumber 'ABC123XYZ' -Environment Test -Start 'now' -End '+1hour'"
    Write-Output ""
    Write-Output "  # SCOM single server (no CLU- prefix)"
    Write-Output "  Set-MaintenanceMode -Action enable -TargetId 'myserver01' -Mode scom \"
    Write-Output "      -Environment Prod -Start 'now' -End '+2hours'"
    Write-Output ""
    Write-Output "CREDENTIALS"
    Write-Output "    Set via environment variables (recommended):"
    Write-Output "      `$env:SCOM_ADMIN_USER / `$env:SCOM_ADMIN_PASSWORD"
    Write-Output "      `$env:ONEVIEW_USER / `$env:ONEVIEW_PASSWORD"
    Write-Output "    Or run interactively - script will prompt if missing"
    Write-Output ""
    Write-Output "MORE INFORMATION"
    Write-Output "    Full docs: Get-Help Set-MaintenanceMode -Full (after importing module)"
    Write-Output "    Testing:   docs/testing.md"
    Write-Output "    Config:    docs/maintenance-mode-environment-config.md"
    Write-Output ""
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

    .PARAMETER ManagementHost
        Optional override for management server/appliance hostname/IP.
        Takes precedence over environment config.
        For SCOM mode: overrides SCOM management server
        For OneView mode: overrides OneView appliance
        Can also be set via $env:MAINTENANCE_HOST

    .PARAMETER SerialNumber
        Optional serial number for OneView mode (Marin's preference).
        Only valid when -Mode is 'oneview'. Will reject if used with SCOM mode.
        When provided, the script will look up the server by serial number in OneView.

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

    .PARAMETER MockMaintenanceState
        Dry-run only: mock validate status as 'enable', 'disable', or 'partial'.
        Default is 'disable'.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .PARAMETER Json
        Output as JSON for API/iRequest integration.

    .RETURNS
        [hashtable] with Success (bool), Message, StartTimeUtc, EndTimeUtc,
        TargetId, ClusterName, ServerCount, DryRun, AuditFile,
        FailedObjects, and mode-specific fields:
        - scom mode only: ScomObjects, ScomSummary
        - oneview mode only: OneViewObjects, OneViewSummary

    .EXAMPLE
        # Validate configuration without making changes
        Set-MaintenanceMode -Action validate -TargetId 'CLU-CLUSTER-01' -Mode scom

    .EXAMPLE
        # Enable maintenance in Test environment with relative time
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+2hours'

    .EXAMPLE
        # Enable maintenance in Prod environment with absolute UTC time
        Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'

    .EXAMPLE
        # Disable maintenance with custom stabilization wait
        Set-MaintenanceMode -Action disable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -PostDisableWaitSeconds 60

    .EXAMPLE
        # Use host override for emergency maintenance
        Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -ManagementHost 'backup-server.local' -Start 'now' -End '+4hours'

    .EXAMPLE
        # Dry run to test configuration
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+1hour' -DryRun

    .EXAMPLE
        # OneView single server maintenance
        Set-MaintenanceMode -Action enable -TargetId 'server01.ad.example.com' -Mode oneview -Environment Test -Start 'now' -End '+1hour'

    .EXAMPLE
        # OneView with serial number (Marin's preference)
        Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' -Environment Test -Start 'now' -End '+1hour'

    .EXAMPLE
        # SCOM single server (no CLU- prefix)
        Set-MaintenanceMode -Action enable -TargetId 'myserver01' -Mode scom -Environment Prod -Start 'now' -End '+2hours'

    .LINK
        https://github.com/yourorg/image-build-automation/docs/testing.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][ValidateSet('enable', 'disable', 'validate')][string] $Action = 'enable',
        [Parameter(Position = 1)][string] $TargetId,
        [Parameter(Mandatory, Position = 2)][ValidateSet('scom', 'oneview')][string] $Mode,
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [string] $ManagementHost,
        [string] $SerialNumber,
        [string] $Username,
        [ValidateRange(0, 3600)][int] $PostDisableWaitSeconds = 120,
        [string] $ConfigDir = 'configs',
        [string] $Start = $null,
        [string] $End = $null,
        [switch] $DryRun,
        [ValidateSet('enable', 'disable', 'partial')][string] $MockMaintenanceState = 'disable',
        [switch] $NoSchedule
    )

    $ErrorActionPreference = 'Continue'

    # Normalize Mode to lowercase for case-insensitive comparison
    if ($Mode) {
        $Mode = $Mode.ToLower() 
    } else {
        return @{ Success = $false; Error = "Mode is required and must be either 'scom' or 'oneview'." }
    }

    # Validate TargetId is not empty (unless using SerialNumber for OneView)
    if ([string]::IsNullOrWhiteSpace($TargetId)) {
        if ($Mode -eq 'oneview' -and $SerialNumber) {
            # OneView mode with SerialNumber - TargetId is optional
            $TargetId = $null
        } else {
            throw "TargetId cannot be empty or whitespace."
        }
    }

    # Use passed ConfigDir param or fall back to project-root configs
    $projRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $EffectiveConfigDir = if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        if (Split-Path $ConfigDir -IsAbsolute) {
            $ConfigDir 
        } else {
            Join-Path (Get-Location) $ConfigDir 
        }
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
    $scomCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'scom_config.json') -Required:$false
    $oneviewCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'oneview_config.json') -Required:$false
    $emailCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'opsramp_config.json') -Required:$false
    $serversCatalogue = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'servers_catalogue.oneview.json') -Required:$false
    $scomClustersCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'clusters_catalogue.scom.json') -Required:$false

    $scomHostnameLookup = @{}
    if ($scomClustersCfg -and $scomClustersCfg.ContainsKey('clusters')) {
        foreach ($entry in $scomClustersCfg['clusters'].GetEnumerator()) {
            $srvList = $entry.Value.Get_Item('servers')
            if (-not $srvList) { continue }
            foreach ($srv in $srvList) {
                $hostname = ($srv.Split('.'))[0].ToLower()
                if (-not $scomHostnameLookup.ContainsKey($hostname)) {
                    $scomHostnameLookup[$hostname] = @{
                        Fqdn = $srv
                        ClusterKey = $entry.Key
                    }
                }
            }
        }
    }

    # Build lookup tables from servers catalogue
    $serialLookup = @{}
    $nameLookup = @{}
    if ($serversCatalogue -and $serversCatalogue.ContainsKey('servers')) {
        foreach ($entry in $serversCatalogue['servers'].GetEnumerator()) {
            $serverInfo = @{
                key           = $entry.Key
                display_name  = $entry.Value['display_name'] ?? $entry.Key
                oneview_name  = $entry.Value['oneview_name'] ?? $entry.Key
                serial_number = $entry.Value['serial_number']
            }
            $sn = $serverInfo['serial_number']
            if ($sn) {
                $serialLookup[$sn] = $serverInfo
            }
            if (-not $nameLookup.ContainsKey($serverInfo['oneview_name'].ToLower())) {
                $nameLookup[$serverInfo['oneview_name'].ToLower()] = $serverInfo
            }
            if (-not $nameLookup.ContainsKey($serverInfo['key'].ToLower())) {
                $nameLookup[$serverInfo['key'].ToLower()] = $serverInfo
            }
        }
    }

    function _Resolve-ServerNameFromSerial([string]$Serial) {
        if (-not $Serial -or -not $serialLookup.ContainsKey($Serial)) {
            return $null
        }
        return $serialLookup[$Serial]['oneview_name']
    }

    function _Resolve-ServerFromName([string]$Name) {
        if (-not $Name) {
            return $null
        }
        $key = $Name.ToLower()
        if ($nameLookup.ContainsKey($key)) {
            return $nameLookup[$key]
        }
        return $null
    }

    function _Resolve-ScomServerToCluster([string]$ServerName, $clustersMap) {
        if (-not $ServerName -or -not $clustersMap) { return $null }
        $lookupKey = $ServerName.ToLower()
        foreach ($entry in $clustersMap.GetEnumerator()) {
            $clusterKey = $entry.Key
            $cDef = $entry.Value
            $srvList = $cDef.Get_Item('servers')
            if (-not $srvList) { continue }
            foreach ($srv in $srvList) {
                if ($srv.ToLower() -eq $lookupKey) {
                    return @{
                        ClusterKey = $clusterKey
                        ClusterDef = $cDef
                        MatchedServer = $srv
                    }
                }
            }
        }
        $hostname = ($ServerName.Split('.'))[0].ToLower()
        if ($scomHostnameLookup.ContainsKey($hostname)) {
            $match = $scomHostnameLookup[$hostname]
            $matchedFqdn = $match.Fqdn
            $scomClusterKey = $match.ClusterKey
            $scomClusterDef = if ($scomClustersCfg -and $scomClustersCfg.ContainsKey('clusters')) {
                $scomClustersCfg['clusters'][$scomClusterKey]
            } else { $null }
            if (-not $scomClusterDef) {
                foreach ($entry in $clustersMap.GetEnumerator()) {
                    $srvList = $entry.Value.Get_Item('servers')
                    if (-not $srvList) { continue }
                    foreach ($srv in $srvList) {
                        if (($srv.Split('.'))[0].ToLower() -eq $hostname) {
                            return @{
                                ClusterKey = $entry.Key
                                ClusterDef = $entry.Value
                                MatchedServer = $matchedFqdn
                            }
                        }
                    }
                }
            } else {
                return @{
                    ClusterKey = $scomClusterKey
                    ClusterDef = $scomClusterDef
                    MatchedServer = $matchedFqdn
                }
            }
        }
        return $null
    }

    # Parse Start / End explicitly if provided, so we can output them even on early errors
    $startDt = $null; $endDt = $null
    $utcStart = $null; $utcEnd = $null
    if ($Action -eq 'enable') {
        if ($Start) {
            $startDt = _Parse-Datetime $Start; $utcStart = Convert-ToUtcIso8601 $startDt 
        } else {
            $startDt = [DateTime]::UtcNow; $utcStart = Convert-ToUtcIso8601 $startDt 
        }
        if ($End) {
            $endDt = _Parse-Datetime $End; $utcEnd = Convert-ToUtcIso8601 $endDt 
        }
    }

    # Validate SerialNumber parameter (only valid for oneview mode)
    if ($SerialNumber -and $Mode -eq 'scom') {
        return @{ 
            Success      = $false
            Error        = "SerialNumber parameter is only valid for OneView mode, not SCOM mode."
            StartTimeUtc = $utcStart
            EndTimeUtc   = $utcEnd
        }
    }

    $resolvedServerName = $null

    # DRYRUN MODE: Skip catalogue validation and use mock data
    if ($DryRun) {
        Write-Verbose "DryRun mode enabled - skipping catalogue validation and using mock data"
        
        if ($Mode -eq 'oneview' -and $SerialNumber) {
            $isDirectServerMode = $true
            $resolvedServerName = _Resolve-ServerNameFromSerial $SerialNumber
            $clusterName = if ($resolvedServerName) { $resolvedServerName } else { "Serial:$SerialNumber" }
            $servers = @($SerialNumber)
        } else {
            $clustersMap = $clustersCfg.Get_Item('clusters')
            if ($clustersMap -and $clustersMap.ContainsKey($TargetId)) {
                $isDirectServerMode = $false
                $clusterDef = $clustersMap[$TargetId]
                $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
                $servers = $clusterDef.Get_Item('servers') ?? @($TargetId)
            } else {
                if ($Mode -eq 'scom') {
                    $scomServerMatch = _Resolve-ScomServerToCluster -ServerName $TargetId -clustersMap $clustersMap
                    if (-not $scomServerMatch) {
                        Write-Verbose "Target '$TargetId' not found in catalogue."
                        return @{ 
                            Success = $false
                            Error   = "Target '$TargetId' not found in catalogue."
                        }
                    }
                    $isDirectServerMode = $true
                    $clusterDef = $scomServerMatch.ClusterDef
                    $clusterName = $clusterDef.Get_Item('display_name') ?? $scomServerMatch.ClusterKey
                    $servers = @($scomServerMatch.MatchedServer)
                } else {
                    $isDirectServerMode = $true
                    $serverFromCatalogue = _Resolve-ServerFromName $TargetId
                    if ($serverFromCatalogue) {
                        $clusterName = $serverFromCatalogue['oneview_name']
                        $resolvedServerName = $serverFromCatalogue['oneview_name']
                        if (-not $SerialNumber -and $serverFromCatalogue['serial_number']) {
                            $SerialNumber = $serverFromCatalogue['serial_number']
                        }
                    } else {
                        $clusterName = $TargetId
                    }
                    $servers = @($TargetId)
                }
            }
        }
    } else {
        # NON-DRYRUN MODE: Load and validate against catalogue
        $clustersMap = $clustersCfg.Get_Item('clusters')

        # Determine target type and resolve cluster/server info
        $isDirectServerMode = $false
        $clusterDef = $null
        $clusterName = $TargetId
        $servers = @()

        if ($Mode -eq 'oneview' -and $SerialNumber) {
            # OneView mode with SerialNumber - resolved via API in non-DryRun, or from catalogue in DryRun
            $isDirectServerMode = $true
            if ($DryRun) {
                $resolvedServerName = _Resolve-ServerNameFromSerial $SerialNumber
                $clusterName = if ($resolvedServerName) { $resolvedServerName } else { $SerialNumber }
            } else {
                # Placeholder; resolved via API after OneViewClient init
                $clusterName = $SerialNumber
            }
            $servers = @($SerialNumber)
        } elseif ($Mode -eq 'oneview') {
            # OneView mode without SerialNumber - check clusters first, then servers catalogue, then raw TargetId
            $isDirectServerMode = $true
            if ($clustersMap -and $clustersMap.ContainsKey($TargetId)) {
                $clusterDef = $clustersMap[$TargetId]
                $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
                $servers = $clusterDef.Get_Item('servers') ?? @($TargetId)
                $isDirectServerMode = $false
            } else {
                $serverFromCatalogue = _Resolve-ServerFromName $TargetId
                if ($serverFromCatalogue) {
                    $clusterName = $serverFromCatalogue['oneview_name']
                    $resolvedServerName = $serverFromCatalogue['oneview_name']
                    if (-not $SerialNumber -and $serverFromCatalogue['serial_number']) {
                        $SerialNumber = $serverFromCatalogue['serial_number']
                    }
                    $servers = @($TargetId)
                } else {
                    $clusterName = $TargetId
                    $servers = @($TargetId)
                }
            }
        } else {
            # SCOM mode - target must exist in catalogue
            if ($clustersMap -and $clustersMap.ContainsKey($TargetId)) {
                $isDirectServerMode = $false
                $clusterDef = $clustersMap[$TargetId]
                $clusterName = $clusterDef.Get_Item('display_name') ?? $TargetId
                
                # Validate cluster definition
                $requiredFields = @('display_name', 'servers', 'scom_group', 'environment')
                $missing = foreach ($f in $requiredFields) {
                    if (-not $clusterDef.ContainsKey($f)) {
                        $f 
                    } 
                }
                if ($missing) { 
                    Write-Verbose "Cluster definition missing required fields: $($missing -join ', ')"
                    $earlyErr = @{ 
                        Success      = $false
                        Error        = "Missing fields: $($missing -join ', ')"
                        ClusterName  = $clusterName
                        StartTimeUtc = $utcStart
                        EndTimeUtc   = $utcEnd
                    }
                    return $earlyErr
                }
                $servers = $clusterDef.Get_Item('servers')
                if (-not ($servers -is [System.Collections.IEnumerable]) -or -not ($servers | Measure-Object).Count) {
                    Write-Verbose "Cluster 'servers' must be a non-empty list."
                    $earlyErr = @{ 
                        Success      = $false
                        Error        = "Cluster 'servers' must be a non-empty list."
                        ClusterName  = $clusterName
                        StartTimeUtc = $utcStart
                        EndTimeUtc   = $utcEnd
                    }
                    return $earlyErr
                }
            } else {
                $scomServerMatch = _Resolve-ScomServerToCluster -ServerName $TargetId -clustersMap $clustersMap
                if (-not $scomServerMatch) {
                    Write-Verbose "Target '$TargetId' not found in catalogue."
                    $earlyErr = @{ 
                        Success      = $false
                        Error        = "Target '$TargetId' not found in catalogue."
                        ClusterName  = $TargetId
                        StartTimeUtc = $utcStart
                        EndTimeUtc   = $utcEnd
                    }
                    return $earlyErr
                }
                $isDirectServerMode = $true
                $clusterDef = $scomServerMatch.ClusterDef
                $clusterName = $clusterDef.Get_Item('display_name') ?? $scomServerMatch.ClusterKey
                $servers = @($scomServerMatch.MatchedServer)
            }
        }
    }

    # Load environment-based connection config (shared by all actions)
    $hostsCfgPath = Join-Path $EffectiveConfigDir 'connection_hosts.json'
    $hostsCfg = if (Test-Path $hostsCfgPath) {
        Import-JsonConfig -Path $hostsCfgPath -Required:$false 
    } else {
        @{} 
    }
    
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
    
    $resolvedHost = if ($PSBoundParameters.ContainsKey('ManagementHost')) {
        $ManagementHost
    } elseif ([System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')) {
        [System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')
    } else {
        if ($Mode -eq 'scom') {
            $scomEnvConfig = $selectedEnv.Get_Item('scom') ?? @{}
            $scomEnvConfig.Get_Item('management_server')
        } else {
            $oneviewEnvConfig = $selectedEnv.Get_Item('oneview') ?? @{}
            $oneviewEnvConfig.Get_Item('appliance')
        }
    }
    
    if (-not $resolvedHost) {
        $envVar = '$env:MAINTENANCE_HOST'
        return @{ Success = $false; Error = "Management host not configured for environment '$effectiveEnv'. Set $envVar, use -ManagementHost parameter, or update connection_hosts.json." }
    }
    
    Write-Verbose "Management host resolved to: $resolvedHost"

    # VALIDATE action - check actual maintenance mode status
    if ($Action -eq 'validate') {
        Write-Verbose "Validating target '$TargetId' and checking maintenance mode status..."
        # hostsCfg, effectiveEnv, resolvedHost already resolved above

        $statusResult = $null
        $maintenanceStatus = $null
        $targetName = $TargetId
        $targetType = 'Scope'
        $groupName = if ($clusterDef) {
            $clusterDef.Get_Item('scom_group') 
        } else {
            $TargetId 
        }

        if ($DryRun) {
            $mockServers = @($servers | ForEach-Object { $_ })
            if ($mockServers.Count -eq 0) {
                $mockServers = @($TargetId) 
            }

            $mockState = $MockMaintenanceState.ToLower()
            $mockInMaintenanceCount = switch ($mockState) {
                'enable' {
                    $mockServers.Count 
                }
                'partial' {
                    [int][Math]::Ceiling($mockServers.Count / 2) 
                }
                default {
                    0 
                }
            }

            $mockObjects = @()
            for ($i = 0; $i -lt $mockServers.Count; $i++) {
                $inMaintenance = $i -lt $mockInMaintenanceCount
                $mockObjects += @{
                    Name              = $mockServers[$i]
                    Type              = if ($Mode -eq 'scom') {
                        'WindowsComputer' 
                    } else {
                        'ServerHardware' 
                    }
                    InMaintenanceMode = $inMaintenance
                    Status            = if ($inMaintenance) {
                        'in_maintenance' 
                    } else {
                        'not_in_maintenance' 
                    }
                    Message           = if ($inMaintenance) {
                        'Maintenance mode enabled (DryRun mock)' 
                    } else {
                        'Maintenance mode disabled (DryRun mock)' 
                    }
                    DryRun            = $true
                }
            }

            $mockSummary = @{
                Total            = $mockObjects.Count
                InMaintenance    = $mockInMaintenanceCount
                NotInMaintenance = ($mockObjects.Count - $mockInMaintenanceCount)
                Failed           = 0
            }

            $mockOverallStatus = _Compute-OverallStatus -InMaintenance $mockInMaintenanceCount -Total $mockObjects.Count
            $stateText = _Format-StatusState $mockOverallStatus
            $statusResult = @{
                Success              = $true
                Objects              = $mockObjects
                Summary              = $mockSummary
                DryRun               = $true
                MockMaintenanceState = $mockState
            }

            if ($Mode -eq 'scom') {
                $maintenanceStatus = @{
                    Mode                 = 'scom'
                    GroupName            = $groupName
                    OverallStatus        = $mockOverallStatus
                    Summary              = $mockSummary
                    Objects              = $mockObjects
                    DryRun               = $true
                    MockMaintenanceState = $mockState
                }
                $message = _Format-StatusMessage -Mode $Mode -OverallStatus $mockOverallStatus -InMaintenance $mockInMaintenanceCount -Total $mockObjects.Count -DryRun $true -MockState $mockState
            } else {
                if ($clusterDef) {
                    $targetName = $TargetId
                    $targetType = 'Scope'
                } elseif ($SerialNumber) {
                    $targetName = $TargetId
                    $targetType = 'ServerHardware'
                } else {
                    $targetName = $TargetId
                    $targetType = 'ServerHardware'
                }

                $maintenanceStatus = @{
                    Mode                 = 'oneview'
                    TargetType           = $targetType
                    TargetName           = $targetName
                    OverallStatus        = $mockOverallStatus
                    Summary              = $mockSummary
                    Objects              = $mockObjects
                    DryRun               = $true
                    MockMaintenanceState = $mockState
                }
                $message = _Format-StatusMessage -Mode $Mode -OverallStatus $mockOverallStatus -InMaintenance $mockInMaintenanceCount -Total $mockObjects.Count -DryRun $true -MockState $mockState
            }
        } else {
            if ($Mode -eq 'scom') {
                try {
                    $scomCfgCopy = $scomCfg.Clone()
                    $scomCfgCopy['management_server'] = $resolvedHost
                    $scomMgr = [SCOMManager]::new($scomCfgCopy)

                    if (-not $groupName) {
                        return @{ Success = $false; Error = "SCOM group name not found for target '$TargetId'" }
                    }

                    Write-Verbose "Querying SCOM maintenance status for group: $groupName"
                    $statusResult = $scomMgr.GetMaintenanceStatus($groupName, $servers, $false)

                    if (-not $statusResult.Success) {
                        return @{ Success = $false; Error = "Failed to query SCOM maintenance status: $($statusResult.Error)" }
                    }

                    $inMaintenanceCount = $statusResult.Summary.InMaintenance
                    $notInMaintenanceCount = $statusResult.Summary.NotInMaintenance
                    $totalCount = $statusResult.Summary.Total

                    $overallStatus = _Compute-OverallStatus -InMaintenance $inMaintenanceCount -Total $totalCount

                    $maintenanceStatus = @{
                        Mode          = 'scom'
                        GroupName     = $groupName
                        OverallStatus = $overallStatus
                        Summary       = $statusResult.Summary
                        Objects       = $statusResult.Objects
                    }

                    $message = _Format-StatusMessage -Mode $Mode -OverallStatus $overallStatus -InMaintenance $inMaintenanceCount -Total $totalCount -DryRun $false -MockState $null
                } catch {
                    return @{ Success = $false; Error = "SCOM validation failed: $($_.Exception.Message)" }
                }
            } elseif ($Mode -eq 'oneview') {
                try {
                    $oneviewCfgCopy = $oneviewCfg.Clone()
                    if (-not $oneviewCfgCopy.ContainsKey('oneview')) {
                        $oneviewCfgCopy['oneview'] = @{}
                    }
                    $oneviewCfgCopy['oneview']['appliance'] = $resolvedHost
                    $oneviewMgr = [OneViewClient]::new($oneviewCfgCopy)

                    if ($clusterDef) {
                        $targetName = $TargetId
                        $targetType = 'Scope'
                    } elseif ($SerialNumber) {
                        $serialResult = $oneviewMgr.ResolveServerBySerial($SerialNumber)
                        if (-not $serialResult.Success) {
                            return @{ Success = $false; Error = "OneView could not resolve server with serial number '$SerialNumber': $($serialResult.Message)" }
                        }
                        $targetName = $serialResult.ServerName
                        $targetType = 'ServerHardware'
                        $resolvedServerName = $serialResult.ServerName
                    } else {
                        $resolveResult = $oneviewMgr.ResolveTarget($TargetId, $false)
                        if (-not $resolveResult.Success) {
                            return @{ Success = $false; Error = "OneView could not resolve '$TargetId' as server or scope: $($resolveResult.Message)" }
                        }
                        $targetName = $resolveResult.TargetName
                        $targetType = $resolveResult.TargetType
                        if ($resolveResult.TargetType -eq 'ServerHardware') {
                            if ($resolveResult.SerialNumber -and -not $SerialNumber) {
                                $SerialNumber = $resolveResult.SerialNumber
                            }
                            $resolvedServerName = $resolveResult.TargetName
                        }
                    }

                    Write-Verbose "Querying OneView maintenance status for ${targetType}: ${targetName}"
                    $statusResult = $oneviewMgr.GetMaintenanceStatus($targetName, $targetType)

                    if (-not $statusResult.Success) {
                        return @{ Success = $false; Error = "Failed to query OneView maintenance status: $($statusResult.Error)" }
                    }

                    $inMaintenanceCount = $statusResult.Summary.InMaintenance
                    $notInMaintenanceCount = $statusResult.Summary.NotInMaintenance
                    $totalCount = $statusResult.Summary.Total

                    $overallStatus = _Compute-OverallStatus -InMaintenance $inMaintenanceCount -Total $totalCount

                    $maintenanceStatus = @{
                        Mode          = 'oneview'
                        TargetType    = $targetType
                        TargetName    = $targetName
                        OverallStatus = $overallStatus
                        Summary       = $statusResult.Summary
                        Objects       = $statusResult.Objects
                    }

                    $message = _Format-StatusMessage -Mode $Mode -OverallStatus $overallStatus -InMaintenance $inMaintenanceCount -Total $totalCount -DryRun $false -MockState $null
                } catch {
                    return @{ Success = $false; Error = "OneView validation failed: $($_.Exception.Message)" }
                }
            }
        }

        if (-not $maintenanceStatus) {
            return @{ Success = $false; Error = "Unable to determine maintenance mode status for target '$TargetId'." }
        }

        # Save audit record
        $validateAuditId = if ($SerialNumber) {
            $SerialNumber 
        } elseif ($TargetId) {
            $TargetId 
        } else {
            "unknown" 
        }
        $audit = @{
            action              = $Action
            mode                = $Mode
            environment         = if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } else { $null }
            target_id           = if ($TargetId) { $TargetId } else { $null }
            serial_number       = if ($SerialNumber) { $SerialNumber } else { $null }
            cluster_name        = if ($isDirectServerMode) { $null } else { $clusterName }
            server_name         = if ($SerialNumber) { $resolvedServerName } elseif ($isDirectServerMode) { $clusterName } else { $null }
            servers             = @($servers | ForEach-Object { $_ })
            server_count        = ($servers | Measure-Object).Count
            dry_run             = [bool]$DryRun
            timestamp_start     = Get-UtcTimestamp
            timestamp_end       = Get-UtcTimestamp
            duration_seconds    = $null
            message             = $message
            steps               = @{
                maintenance_check = @{
                    Success = $true
                    Status  = $maintenanceStatus
                }
            }
            success             = $true
        }
        _Save-AuditRecord $audit (Join-Path $Script:MaintLogDir "validate_${validateAuditId}_$(Get-UtcFileTimestamp).json")

        Write-Host $message
        Write-Host "Servers: $($servers -join ', ')"

        $validateResult = @{
            Success           = $true
            Message           = $message
            TargetId          = if ($TargetId) {
                $TargetId 
            } elseif ($SerialNumber) {
                $SerialNumber 
            } else {
                $null 
            }
            SerialNumber      = if ($SerialNumber) {
                $SerialNumber 
            } else {
                $null 
            }
            ServerCount       = ($servers | Measure-Object).Count
            DryRun            = [bool]$DryRun
            OverallStatus     = $maintenanceStatus.OverallStatus
            StatusText        = $stateText
            MaintenanceStatus = $maintenanceStatus
            FailedObjects     = @()
        }

        if ($Mode -eq 'scom') {
            $validateResult['ScomObjects'] = $statusResult.Objects
            $validateResult['ScomSummary'] = $statusResult.Summary
        } elseif ($Mode -eq 'oneview') {
            $validateResult['OneViewObjects'] = $statusResult.Objects
            $validateResult['OneViewSummary'] = $statusResult.Summary
        }

        return $validateResult
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
            $credPrompt = if ($Mode -eq 'scom') {
                "SCOM" 
            } else {
                "OneView" 
            }
            Write-Host "Enter $credPrompt username:" -ForegroundColor Yellow
            $resolvedUsername = Read-Host
        }
        
        if (-not $resolvedPassword -and -not $isAutomated) {
            $credPrompt = if ($Mode -eq 'scom') {
                "SCOM" 
            } else {
                "OneView" 
            }
            $securePass = Read-Host "Enter $credPrompt password" -AsSecureString
            $resolvedPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
            )
        }
        
if (-not $resolvedUsername -or -not $resolvedPassword) {
        if (-not $DryRun -and -not $isAutomated) {
            $missingCreds = @()
            if (-not $resolvedUsername) {
                $missingCreds += "username" 
            }
            if (-not $resolvedPassword) {
                $missingCreds += "password" 
            }
            return @{ 
                Success = $false
                Error   = "Missing credentials: $($missingCreds -join ', '). Set environment variables, use parameters, or run interactively."
            }
        }
    }
    }

    # configs (clustersCfg, scomCfg, oneviewCfg, emailCfg, opsrampCfg) already loaded above
    # startDt, endDt, utcStart, utcEnd already parsed above

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
            if ($clusterDef) {
                $schedule = $clusterDef.Get_Item('schedule')
                if ($schedule) {
                    $scheduleEnd = _Compute-NextWorkStart $schedule $startDt
                    if ($scheduleEnd -gt $endDt) {
                        $endDt = $scheduleEnd 
                    }
                }
            }
            $utcEnd = Convert-ToUtcIso8601 $endDt
        }

        if ($endDt -le $startDt) { 
            Write-Verbose 'End time must be after start time.'
            return @{ 
                Success      = $false; 
                Error        = 'End time must be after start time.';
                StartTimeUtc = $utcStart;
                EndTimeUtc   = $utcEnd;
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
            $scomCfgCopy = $scomCfg.Clone()
            $scomCfgCopy['management_server'] = $resolvedHost
            $scomMgr = [SCOMManager]::new($scomCfgCopy)
            
            if ($resolvedUsername -and $resolvedPassword) {
                $scomMgr.Cred = @{ username = $resolvedUsername; password = $resolvedPassword }
            }
        } catch {
            Write-Warning "SCOM manager unavailable: $($_.Exception.Message)" 
        }
    }

    if ($Mode -eq 'oneview') {
        try {
            $oneviewCfgCopy = $oneviewCfg.Clone()
            if (-not $oneviewCfgCopy.ContainsKey('oneview')) {
                $oneviewCfgCopy['oneview'] = @{}
            }
            $oneviewCfgCopy['oneview']['appliance'] = $resolvedHost
            $oneviewMgr = [OneViewClient]::new($oneviewCfgCopy)
            
            if ($resolvedUsername -and $resolvedPassword) {
                $oneviewMgr.Username = $resolvedUsername
                $oneviewMgr.Password = $resolvedPassword
            }
            
            # Resolve target for oneview - determine if server or cluster/scope
            if ($oneviewMgr -and $isDirectServerMode -and -not $DryRun) {
                if ($SerialNumber) {
                    $serialLookupResult = $oneviewMgr.ResolveServerBySerial($SerialNumber)
                    if (-not $serialLookupResult.Success) {
                        return @{ Success = $false; SerialNumber = $SerialNumber; Error = "OneView could not resolve server with serial number '$SerialNumber': $($serialLookupResult.Message)" }
                    }
                    $resolvedServerName = $serialLookupResult.ServerName
                    $clusterName = $serialLookupResult.ServerName
                } elseif ($TargetId) {
                    $resolveResult = $oneviewMgr.ResolveTarget($TargetId, [bool]$DryRun)
                    if (-not $resolveResult.Success) {
                        return @{ Success = $false; Error = "OneView could not resolve '$TargetId' as server or cluster: $($resolveResult.Message)" }
                    }
                    $clusterName = $resolveResult.TargetName
                    if ($resolveResult.TargetType -eq 'ServerHardware') {
                        $resolvedServerName = $resolveResult.TargetName
                        if ($resolveResult.SerialNumber -and -not $SerialNumber) {
                            $SerialNumber = $resolveResult.SerialNumber
                        }
                    }
                }
            }
        } catch {
            Write-Warning "OneView client unavailable: $($_.Exception.Message)" 
        }
    }

    $emailer = [EmailNotifier]::new($emailCfg)

    $opsrampClient = $null
    if ($opsrampCfg) {
        try {
            $opsrampClient = [OpsRamp_Client]::new((Join-Path $Script:ConfigDir 'opsramp_config.json')) 
        } catch {
            Write-Debug "OpsRamp init failed" 
        } 
    }

    # Test connection before proceeding (non-dry-run only)
    if (-not $DryRun) {
        if ($Mode -eq 'scom' -and $scomMgr) {
            Write-Verbose "Testing SCOM connection to $($scomMgr.MgmtServer)..."
            $connectionOk = Test-ScomConnection -ManagementServer $scomMgr.MgmtServer -Username $scomMgr.Cred.username -Password $scomMgr.Cred.password
            if (-not $connectionOk) {
                return @{ 
                    Success     = $false
                    Error       = "Failed to connect to SCOM management server '$($scomMgr.MgmtServer)'. Check credentials and network connectivity."
                    ClusterName = $clusterName
                }
            }
            Write-Verbose "SCOM connection verified successfully"
        }
        
        if ($Mode -eq 'oneview' -and $oneviewMgr) {
            Write-Verbose "Testing OneView connection to $($oneviewMgr.Appliance)..."
            $connectionOk = Test-OneViewConnection -Appliance $oneviewMgr.Appliance -Username $oneviewMgr.Username -Password $oneviewMgr.Password -ModuleName $oneviewMgr.ModuleName
            if (-not $connectionOk) {
                $targetNameErr = if ($SerialNumber) {
                    $SerialNumber 
                } elseif ($resolveResult) {
                    $resolveResult.TargetName 
                } else {
                    $TargetId 
                }
                return @{ 
                    Success      = $false
                    Error        = "Failed to connect to OneView appliance '$($oneviewMgr.Appliance)'. Check credentials and network connectivity."
                    TargetId     = $TargetId
                    SerialNumber = $SerialNumber
                }
            }
            Write-Verbose "OneView connection verified successfully"
        }
    }

    # Execute action
    $overallOk = $true
    $auditTargetId = if ($SerialNumber) {
        $SerialNumber 
    } elseif ($TargetId) {
        $TargetId 
    } else {
        "unknown" 
    }
    $auditClusterName = if ($isDirectServerMode) {
        $null 
    } else {
        $clusterName 
    }
    $auditServerName = if ($SerialNumber) {
        $resolvedServerName 
    } elseif ($isDirectServerMode) {
        $clusterName 
    } else {
        $null 
    }
    $audit = @{
        action              = $Action
        mode                = $Mode
        environment         = if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } else { $null }
        target_id           = if ($TargetId) { $TargetId } else { $null }
        serial_number       = if ($SerialNumber) { $SerialNumber } else { $null }
        cluster_name        = $auditClusterName
        server_name         = $auditServerName
        servers             = @($servers | ForEach-Object { $_ })
        server_count        = ($servers | Measure-Object).Count
        dry_run             = [bool]$DryRun
        timestamp_start     = Get-UtcTimestamp
        timestamp_end       = $null
        duration_seconds    = $null
        message             = $null
        steps               = @{}
        success             = $true
    }

    if ($Action -eq 'enable') {
        # Check if already in maintenance mode
        $alreadyEnabled = $false
        if ($Mode -eq 'scom' -and $scomMgr -and $clusterDef -and -not $DryRun) {
            $preCheckGroup = $clusterDef.Get_Item('scom_group')
            $preCheckResult = $scomMgr.GetMaintenanceStatus($preCheckGroup, $servers, $false)
            if ($preCheckResult.Success -and $preCheckResult.Summary.InMaintenance -gt 0) {
                $alreadyEnabled = $true
            }
        } elseif ($Mode -eq 'oneview' -and $oneviewMgr -and -not $DryRun) {
            $targetName = if ($resolveResult) {
                $resolveResult.TargetName 
            } else {
                $TargetId 
            }
            $targetType = if ($resolveResult) {
                $resolveResult.TargetType 
            } else {
                'Scope' 
            }
            $preCheckResult = $oneviewMgr.GetMaintenanceStatus($targetName, $targetType)
            if ($preCheckResult.Success -and $preCheckResult.Summary.InMaintenance -gt 0) {
                $alreadyEnabled = $true
            }
        }
        
        if ($alreadyEnabled -and -not $DryRun) {
            $msg = "Server is already in maintenance mode."
            Write-Host $msg -ForegroundColor Red
            $audit.steps['pre_check'] = @{ Skipped = $true; Reason = $msg }
            $audit.success = $false
            $audit.message = $msg
            $audit.timestamp_end = Get-UtcTimestamp
            $auditFile = Join-Path $Script:MaintLogDir "$($Action)_$($auditTargetId)_$(Get-UtcFileTimestamp).json"
            _Save-AuditRecord $audit $auditFile
            return @{
                Success   = $false
                Error     = $msg
                Mode      = $Mode
                Action    = $Action
                TargetId  = if ($TargetId) { $TargetId } elseif ($SerialNumber) { $SerialNumber } else { $null }
                AuditFile = $auditFile
            }
        }
        
        # SCOM - use group mode to put ALL objects in the SCOM group into maintenance mode
        # (servers, network devices, nodes, cluster objects, everything under the group)
        # Only for 'scom' mode
        $scomOk = $true; $scomInfo = ''; $scomObjects = @(); $scomSummary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
        if ($DryRun -and $Mode -eq 'scom') {
            # In DryRun mode, use mock data instead of calling SCOM API
            $mockServers = @($servers | ForEach-Object { $_ })
            if ($mockServers.Count -eq 0) {
                $mockServers = @($TargetId) 
            }
            
            $mockState = $MockMaintenanceState.ToLower()
            $mockInMaintenanceCount = switch ($mockState) {
                'enable' {
                    $mockServers.Count 
                }
                'partial' {
                    [int][Math]::Ceiling($mockServers.Count / 2) 
                }
                default {
                    $mockServers.Count 
                }
            }
            
            $scomObjects = @()
            for ($i = 0; $i -lt $mockServers.Count; $i++) {
                $inMaintenance = $i -lt $mockInMaintenanceCount
                $scomObjects += @{
                    Name              = $mockServers[$i]
                    Type              = 'WindowsComputer'
                    InMaintenanceMode = $inMaintenance
                    Status            = if ($inMaintenance) {
                        'in_maintenance' 
                    } else {
                        'not_in_maintenance' 
                    }
                    Message           = if ($inMaintenance) {
                        'Maintenance mode enabled (DryRun mock)' 
                    } else {
                        'Maintenance mode disabled (DryRun mock)' 
                    }
                    DryRun            = $true
                }
            }
            
            $scomSummary = @{
                Total                = $scomObjects.Count
                Success              = $mockInMaintenanceCount
                AlreadyInMaintenance = 0
                Failed               = 0
            }
            $scomOk = $true
            $scomInfo = "DryRun mode - no actual SCOM call made"
        } elseif (-not $DryRun -and $scomMgr -and $Mode -eq 'scom') {
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
            $scomInfo = if ($scomRes.Output) {
                ($scomRes.Output -join "`n") 
            } else {
                '' 
            }
        }
        if ($Mode -eq 'scom') {
            $audit.steps['scom'] = @{ Success = $scomOk; Info = $scomInfo; Objects = $scomObjects; Summary = $scomSummary }
            if (-not $scomOk) {
                $overallOk = $false 
            }
        }

        # OneView - for 'oneview' mode
        $oneviewOk = $true; $oneviewMsg = ''; $oneviewObjects = @(); $oneviewSummary = @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
        if ($Mode -eq 'oneview') {
            if ($DryRun) {
                # In DryRun mode, use mock data instead of calling OneView API
                $mockServers = @($servers | ForEach-Object { $_ })
                if ($mockServers.Count -eq 0) {
                    $mockServers = @($TargetId) 
                }
                
                $mockState = $MockMaintenanceState.ToLower()
                $mockInMaintenanceCount = switch ($mockState) {
                    'enable' {
                        $mockServers.Count 
                    }
                    'partial' {
                        [int][Math]::Ceiling($mockServers.Count / 2) 
                    }
                    default {
                        $mockServers.Count 
                    }
                }
                
                $oneviewObjects = @()
                for ($i = 0; $i -lt $mockServers.Count; $i++) {
                    $inMaintenance = $i -lt $mockInMaintenanceCount
                    $mockName = if ($mockServers[$i] -eq $SerialNumber -and $resolvedServerName) {
                        $resolvedServerName 
                    } else {
                        $mockServers[$i] 
                    }
                    $oneviewObjects += @{
                        Name              = $mockName
                        SerialNumber      = $mockServers[$i]
                        Type              = 'ServerHardware'
                        InMaintenanceMode = $inMaintenance
                        Status            = if ($inMaintenance) {
                            'in_maintenance' 
                        } else {
                            'not_in_maintenance' 
                        }
                        Message           = if ($inMaintenance) {
                            'Maintenance mode enabled (DryRun mock)' 
                        } else {
                            'Maintenance mode disabled (DryRun mock)' 
                        }
                        DryRun            = $true
                    }
                }
                
                $oneviewSummary = @{
                    Total                = $oneviewObjects.Count
                    Success              = $mockInMaintenanceCount
                    AlreadyInMaintenance = 0
                    Failed               = 0
                }
                $oneviewOk = $true
                $oneviewMsg = "DryRun mode - no actual OneView call made"
            } elseif ($oneviewMgr) {
                $targetName = if ($resolveResult) {
                    $resolveResult.TargetName 
                } else {
                    $TargetId 
                }
                $targetType = if ($resolveResult) {
                    $resolveResult.TargetType 
                } else {
                    'Scope' 
                }
                $oneviewRes = $oneviewMgr.SetMaintenance($targetName, $targetType, $startDt, $endDt, [bool]$DryRun)
                $oneviewOk = $oneviewRes.Success; $oneviewMsg = $oneviewRes.Message
                $oneviewObjects = $oneviewRes.Objects ?? @()
                $oneviewSummary = $oneviewRes.Summary ?? @{ Total = 0; Success = 0; AlreadyInMaintenance = 0; Failed = 0 }
            } else {
                $oneviewOk = $false; $oneviewMsg = 'OneView client not available'
            }
            $audit.steps['oneview'] = @{ Success = $oneviewOk; Message = $oneviewMsg; Objects = $oneviewObjects; Summary = $oneviewSummary }
            if (-not $oneviewOk) {
                $overallOk = $false 
            }
        }

        # Email
        $emailOk = $emailer.SendMaintenanceNotification('enabled', $clusterDef, $servers, $startDt, $endDt, [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk -and -not $DryRun) {
            $overallOk = $false 
        }

        # OpsRamp
        $opsOk = $false
        if ($opsrampClient -and -not $DryRun) {
            $env = if ($clusterDef) {
                $clusterDef.Get_Item('environment') 
            } else {
                'unknown' 
            }
            $displayName = if ($clusterDef) {
                $clusterDef.Get_Item('display_name') 
            } else {
                $clusterName 
            }
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
            } catch {
                $audit.steps.scheduled_task = @{ Created = $false; Error = $_.Exception.Message }; $overallOk = $false 
            }
        }
        
    } elseif ($Action -eq 'disable') {
        # Check if already out of maintenance mode
        $alreadyDisabled = $false
        if ($Mode -eq 'scom' -and $scomMgr -and $clusterDef) {
            $preCheckGroup = $clusterDef.Get_Item('scom_group')
            $preCheckResult = $scomMgr.GetMaintenanceStatus($preCheckGroup, $servers, $false)
            if ($preCheckResult.Success -and $preCheckResult.Summary.InMaintenance -eq 0) {
                $alreadyDisabled = $true
            }
        } elseif ($Mode -eq 'oneview' -and $oneviewMgr) {
            $targetName = if ($resolveResult) {
                $resolveResult.TargetName 
            } else {
                $TargetId 
            }
            $targetType = if ($resolveResult) {
                $resolveResult.TargetType 
            } else {
                'Scope' 
            }
            $preCheckResult = $oneviewMgr.GetMaintenanceStatus($targetName, $targetType)
            if ($preCheckResult.Success -and $preCheckResult.Summary.InMaintenance -eq 0) {
                $alreadyDisabled = $true
            }
        }
        
        if ($alreadyDisabled -and -not $DryRun) {
            $msg = "Server is already out of maintenance mode."
            Write-Host $msg -ForegroundColor Red
            $audit.steps['pre_check'] = @{ Skipped = $true; Reason = $msg }
            $audit.success = $false
            $audit.message = $msg
            $audit.timestamp_end = Get-UtcTimestamp
            $auditFile = Join-Path $Script:MaintLogDir "$($Action)_$($auditTargetId)_$(Get-UtcFileTimestamp).json"
            _Save-AuditRecord $audit $auditFile
            return @{
                Success   = $false
                Error     = $msg
                Mode      = $Mode
                Action    = $Action
                TargetId  = if ($TargetId) { $TargetId } elseif ($SerialNumber) { $SerialNumber } else { $null }
                AuditFile = $auditFile
            }
        }
        
        # SCOM - exit maintenance mode for ALL objects in the group (group mode, not cluster mode)
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
            if (-not $scomExitOk) {
                $overallOk = $false 
            }

            # Wait/sleep period after disabling SCOM maintenance to allow servers time
            # to reboot, restart services, and stabilize before alerting resumes.
            # This prevents false alerts that support staff report frequently.
            if (-not $DryRun -and $PostDisableWaitSeconds -gt 0) {
                Write-Host "Waiting ${PostDisableWaitSeconds}s for servers to stabilize after SCOM maintenance exit..."
                Start-Sleep -Seconds $PostDisableWaitSeconds
                Write-Host 'Stabilization wait complete. Alerting is now active.'
                $audit.steps['post_disable_wait'] = @{ Seconds = $PostDisableWaitSeconds }
            } else {
                $audit.steps['post_disable_wait'] = @{ Skipped = $true; Reason = if ($DryRun) {
                        'DryRun' 
                    } else {
                        'PostDisableWaitSeconds=0' 
                    } 
                }
            }
        }

        # OneView disable - for 'oneview' mode
        $oneviewExitOk = $true; $oneviewExitMsg = ''; $oneviewExitObjects = @(); $oneviewExitSummary = @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
        if ($Mode -eq 'oneview' -and $oneviewMgr) {
            $targetName = if ($resolveResult) {
                $resolveResult.TargetName 
            } else {
                $TargetId 
            }
            $targetType = if ($resolveResult) {
                $resolveResult.TargetType 
            } else {
                'Scope' 
            }
            $oneviewExitRes = $oneviewMgr.DisableMaintenance($targetName, $targetType, [bool]$DryRun)
            $oneviewExitOk = $oneviewExitRes.Success; $oneviewExitMsg = $oneviewExitRes.Message
            $oneviewExitObjects = $oneviewExitRes.Objects ?? @()
            $oneviewExitSummary = $oneviewExitRes.Summary ?? @{ Total = 0; Success = 0; NotInMaintenance = 0; Failed = 0 }
            $audit.steps['oneview_exit'] = @{ Success = $oneviewExitOk; Message = $oneviewExitMsg; Objects = $oneviewExitObjects; Summary = $oneviewExitSummary }
            if (-not $oneviewExitOk) {
                $overallOk = $false 
            }
        }

        # Email disable notification
        if ($clusterDef) {
            $emailOk = $emailer.SendMaintenanceNotification('disabled', $clusterDef, $servers, $null, [DateTime]::UtcNow, [bool]$DryRun)
            $audit.steps['email'] = @{ Sent = $emailOk }
            if (-not $emailOk) {
                $overallOk = $false 
            }
        }

        # OpsRamp
        if ($opsrampClient -and -not $DryRun) {
            $env = if ($clusterDef) {
                $clusterDef.Get_Item('environment') 
            } else {
                'unknown' 
            }
            $displayName = if ($clusterDef) {
                $clusterDef.Get_Item('display_name') 
            } else {
                $clusterName 
            }
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
            try {
                schtasks /Delete /TN $taskName /F 2>&1 | Out-Null; $audit.steps.scheduled_task_cleanup = @{ Deleted = $true } 
            } catch {
                $audit.steps.scheduled_task_cleanup = @{ Deleted = $false; Error = $_.Exception.Message } 
            }
        }
    }

    $audit.success = $overallOk
    $audit.server_count = ($servers | Measure-Object).Count
    $audit.servers = @($servers | ForEach-Object { $_ })
    $audit.cluster_name = if (-not $isDirectServerMode) { $clusterName } else { $null }
    $audit.server_name = if ($SerialNumber) { $resolvedServerName } elseif ($isDirectServerMode) { $clusterName } else { $null }
    if ($Action -eq 'enable') {
        $audit.timestamp_start = $utcStart
        $audit.timestamp_end = $utcEnd
        $audit.duration_seconds = if ($duration) { [int]$duration.TotalSeconds } else { $null }
    } else {
        $audit.timestamp_end = Get-UtcTimestamp
    }
    $auditFile = Join-Path $Script:MaintLogDir "$($Action)_$($auditTargetId)_$(Get-UtcFileTimestamp).json"

    # Build detailed completion message
    $serverCount = ($servers | Measure-Object).Count
    $dryRunNote = if ($DryRun) {
        " [DRY-RUN]" 
    } else {
        "" 
    }
    
    # Determine if target is a server or cluster based on mode and target type
    $targetEntity = 'cluster'
    $targetName = $clusterName
    
    if ($Mode -eq 'oneview') {
        if ($SerialNumber) {
            $targetEntity = 'server with Serial Number'
            $targetName = $SerialNumber
        } elseif ($resolveResult -and $resolveResult.TargetType -eq 'ServerHardware') {
            $targetEntity = 'server'
            $targetName = $resolveResult.TargetName
        } elseif ($isDirectServerMode -and -not $clusterDef) {
            $targetEntity = 'server'
            $targetName = $TargetId
        }
    } elseif ($Mode -eq 'scom') {
        if ($isDirectServerMode -and -not $clusterDef) {
            $targetEntity = 'server'
            $targetName = $TargetId
        } elseif ($clusterDef) {
            $targetName = $clusterDef.Get_Item('display_name') ?? $TargetId
        }
    }
    
    $modeName = if ($Mode -eq 'oneview') {
        'OneView' 
    } else {
        'SCOM' 
    }
    
    $detailMessage = if ($overallOk) {
        if ($Action -eq 'enable') {
            $durationStr = if ($duration) {
                $totalHours = [int]$duration.TotalHours
                $mins = $duration.Minutes
                " (Duration: ${totalHours}h ${mins}m)"
            } else {
                "" 
            }
            "Maintenance $Action completed for $targetEntity '$targetName' ($serverCount servers) [$modeName mode]$durationStr$dryRunNote. Window: $utcStart -> $utcEnd"
        } elseif ($Action -eq 'disable') {
            "Maintenance $Action completed for $targetEntity '$targetName' ($serverCount servers) [$modeName mode]$dryRunNote. Maintenance mode deactivated."
        } else {
            "Validation completed for $targetEntity '$targetName' ($serverCount servers) [$modeName mode]. Configuration is valid."
        }
    } else {
        "Maintenance $Action finished with errors for $targetEntity '$targetName' [$modeName mode]$dryRunNote. Check audit: $auditFile"
    }
    $audit.message = $detailMessage
    _Save-AuditRecord $audit $auditFile

    if ($overallOk) {
        Write-Host $detailMessage 
    } else {
        Write-Warning $detailMessage 
    }
    
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
    
    $result = @{ 
        Success        = $overallOk
        Message        = $detailMessage
        Action         = $Action
        Mode           = $Mode
        Environment    = if ($PSBoundParameters.ContainsKey('Environment')) {
            $Environment 
        } else {
            $null 
        }
        StartTimeUtc   = if ($Action -eq 'enable') {
            $utcStart 
        } else {
            $null 
        }
        EndTimeUtc     = if ($Action -eq 'enable') {
            $utcEnd 
        } else {
            $null 
        }
        TargetId       = if ($TargetId) {
            $TargetId 
        } elseif ($SerialNumber) {
            $SerialNumber 
        } else {
            $null 
        }
        SerialNumber   = if ($SerialNumber) {
            $SerialNumber 
        } else {
            $null 
        }
        ServerCount    = $serverCount
        DryRun         = [bool]$DryRun
        AuditFile      = $auditFile
        FailedObjects  = $failedObjects
    }

    if ($Mode -eq 'scom') {
        $result['ScomObjects'] = $allScomObjects
        $result['ScomSummary'] = if ($Action -eq 'enable') {
            $scomSummary 
        } elseif ($Action -eq 'disable') {
            $scomExitSummary 
        } else {
            @{} 
        }
    } elseif ($Mode -eq 'oneview') {
        $result['OneViewObjects'] = $allOneviewObjects
        $result['OneViewSummary'] = if ($Action -eq 'enable') {
            $oneviewSummary 
        } elseif ($Action -eq 'disable') {
            $oneviewExitSummary 
        } else {
            @{} 
        }
    }

    if ($SerialNumber) {
        if ($resolvedServerName) {
            $result['ServerName'] = $resolvedServerName
        }
    } elseif ($isDirectServerMode) {
        $result['ServerName'] = $clusterName
    } else {
        $result['ClusterName'] = $clusterName
    }

    return $result
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
        if ($parent -eq $current -or -not $parent) {
            break 
        }
        $current = $parent
    }
    if (-not $current -or -not (Test-Path $current)) {
        $Script:BaseDir = Get-Location
    } else {
        $Script:BaseDir = (Resolve-Path $current).Path
    }
}

if (-not $Script:ConfigDir) {
    $Script:ConfigDir = Join-Path $Script:BaseDir 'configs' 
}
if (-not $Script:MaintLogDir) {
    $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
    $Script:MaintLogDir = Join-Path $Script:BaseDir "generated/logs/$($isTesting ? 'testing' : 'audit')"
}
if (-not $Script:DistList) {
    $Script:DistList = Join-Path $Script:BaseDir 'maintenance_distribution_list.txt' 
}

if (-not (Test-Path $Script:MaintLogDir)) {
    Ensure-DirectoryExists -Path $Script:MaintLogDir 
}

# ---- Logging ----
Initialize-Logging -LogFile 'maintenance.log' -CommandName 'Set-MaintenanceMode'

# ---- Connection validation helpers ----
function Test-ScomConnection {
    <#
    .SYNOPSIS
        Tests scom connection (SCOM mode).
    #>

    param(
        [string]$ManagementServer,
        [string]$Username,
        [string]$Password,
        [string]$ModuleName = 'OperationsManager'
    )
    
    try {
        $escapedPass = $Password -replace "'", "''"
        $escapedUser = $Username -replace "'", "''"
        $escapedServer = $ManagementServer -replace "'", "''"
        $scriptContent = @"
Import-Module $ModuleName -ErrorAction Stop
`$securePass = ConvertTo-SecureString '$escapedPass' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$escapedUser', `$securePass)
`$conn = New-SCOMManagementGroupConnection -ComputerName '$escapedServer' -Credential `$cred -ErrorAction Stop
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
    <#
    .SYNOPSIS
        Tests one view connection.
    #>

    param(
        [string]$Appliance,
        [string]$Username,
        [string]$Password,
        [string]$ModuleName = 'HPEOneView.1000'
    )
    
    try {
        $cred = [System.Management.Automation.PSCredential]::new(
            $Username,
            (ConvertTo-SecureString $Password -AsPlainText -Force))
        $connResult = Connect-OneViewSession -Appliance $Appliance -Credential $cred -ModuleName $ModuleName
        return $connResult.Connected
    } catch {
        Write-Warning "OneView connection test failed: $($_.Exception.Message)"
        return $false
    }
}

# ---- Parse datetime helpers ----
function _Parse-Datetime([string]$s) {
    if ($s.ToLower() -eq 'now') {
        return [DateTime]::UtcNow 
    }
    
    # Handle relative time offsets like +1hour, +30minutes, +2days
    if ($s -match '^\+([\d]+)(seconds?|minutes?|hours?|days?)$') {
        $value = [int]$Matches[1]
        $unit = $Matches[2].ToLower()
        $offset = switch ($unit) {
            'second' {
                [TimeSpan]::FromSeconds($value) 
            }
            'seconds' {
                [TimeSpan]::FromSeconds($value) 
            }
            'minute' {
                [TimeSpan]::FromMinutes($value) 
            }
            'minutes' {
                [TimeSpan]::FromMinutes($value) 
            }
            'hour' {
                [TimeSpan]::FromHours($value) 
            }
            'hours' {
                [TimeSpan]::FromHours($value) 
            }
            'day' {
                [TimeSpan]::FromDays($value) 
            }
            'days' {
                [TimeSpan]::FromDays($value) 
            }
            default {
                [TimeSpan]::Zero 
            }
        }
        return ([DateTime]::UtcNow).Add($offset)
    }
    
    $s2 = $s.Replace('T', ' ')
    $formats = @('yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm')
    foreach ($fmt in $formats) {
        try { 
            $parsed = [DateTime]::ParseExact($s2, $fmt, $null)
            return [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
        } catch {
            continue 
        }
    }
    try { 
        $parsed = [DateTime]::Parse($s2)
        return [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
    } catch {
        Write-Debug "DateTime parse failed" 
    }
    throw "Invalid datetime format '$s'. Use 'now', '+1hour', or 'YYYY-MM-DD HH:MM[:SS]'."
}

function _Compute-DefaultEnd([DateTime]$After) {
    # Default end time: 7am UTC Monday following the start time
    $candidate = $After.Date
    $daysUntilMonday = [int][DayOfWeek]::Monday - [int]$candidate.DayOfWeek
    if ($daysUntilMonday -lt 0) {
        $daysUntilMonday += 7 
    }
    $monday = $candidate.AddDays($daysUntilMonday)
    $defaultEnd = $monday.Date.AddHours(7)
    if ($defaultEnd -le $After) {
        $defaultEnd = $defaultEnd.AddDays(7) 
    }
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
            if ($dt -gt $After) {
                return $dt 
            }
        }
        $candidate = $candidate.AddDays(1)
    }
}


function _Compute-OverallStatus([int]$InMaintenance, [int]$Total) {
    if ($Total -gt 0 -and $InMaintenance -eq $Total) { 'fully_in_maintenance' }
    elseif ($InMaintenance -gt 0) { 'partially_in_maintenance' }
    else { 'not_in_maintenance' }
}

function _Format-StatusState([string]$OverallStatus) {
    switch ($OverallStatus) {
        'fully_in_maintenance'       { 'enabled' }
        'partially_in_maintenance'   { 'partially enabled' }
        default                      { 'disabled' }
    }
}

function _Format-StatusMessage([string]$Mode, [string]$OverallStatus, [int]$InMaintenance, [int]$Total, [bool]$DryRun, [string]$MockState) {
    $stateText = _Format-StatusState $OverallStatus
    $base = "Maintenance mode ${Mode} is currently $stateText ($InMaintenance/$Total objects in maintenance)"
    if ($DryRun -and $MockState) {
        return "$base [DRY-RUN mock: $MockState]"
    }
    return $base
}

function _Save-AuditRecord([hashtable]$Audit, [string]$Path) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null 
    }
    
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
                if ($u -and $p) {
                    $this.Cred = @{ username = $u; password = $p } 
                }
            }
        }
        # Detect SCOM version and REST-API readiness on first use (lazy, on demand)
    }

    [hashtable] _RunPs([string]$Script) {
        if ($this.UseWinRM) {
            if (-not $this.Cred) {
                return @{ Success = $false; Output = 'WinRM credentials not configured' } 
            }
            return Invoke-PowerShellWinRM -Script $Script `
                -Server $this.MgmtServer -Username $this.Cred['username'] -Password $this.Cred['password']
        } else {
            return Invoke-PowerShellScript -Script $Script
        }
    }

    [void] _DetectVersion() {
        if ($this.ScomVersion -gt 0) {
            return 
        }
        if (-not $this.Cred) {
            return 
        }
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
                if ($trimmed -match '^SCOM_VERSION:\s*(\d+)') {
                    $this.ScomVersion = [int]$Matches[1] 
                }
                if ($trimmed -match '^SCOM_REST_READY:\s*(True|true)') {
                    $this.RestApiReady = $true 
                }
            }
        }
        if ($this.ScomVersion -eq 0) {
            $this.ScomVersion = 2016 
        }   # safe default
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
        if (-not $r.Success) {
            return @() 
        }
        return ($r.Output -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
    }

    [hashtable] EnterMaintenance([string]$GroupDisplayName, [TimeSpan]$Duration,
        [string]$Comment, [bool]$DryRun = $false,
        [string[]]$ServerHostnames = $null,
        [bool]$UseClusterMode = $false) {

        if ($DryRun) {
            # Return mock per-object status data for DryRun testing
            # Based on clusters_catalogue.examples-only.json template
            $mockServers = if ($ServerHostnames) {
                $ServerHostnames 
            } else {
                @('mock-server-01.example.com', 'mock-server-02.example.com', 'mock-server-03.example.com') 
            }
            $mockObjects = @()
            foreach ($srv in $mockServers) {
                $mockObjects += @{
                    Name       = $srv
                    Type       = 'WindowsComputer'
                    Action     = 'enable'
                    Status     = 'success'
                    Message    = 'Maintenance mode enabled (DryRun)'
                    NackReason = $null
                    Resolution = $null
                }
            }
            $mockObjects += @{
                Name       = $GroupDisplayName
                Type       = 'WindowsCluster'
                Action     = 'enable'
                Status     = 'success'
                Message    = 'Cluster maintenance mode enabled (DryRun)'
                NackReason = $null
                Resolution = $null
            }
            $mockSummary = @{
                Total                = $mockObjects.Count
                Success              = $mockObjects.Count
                AlreadyInMaintenance = 0
                Failed               = 0
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
                        Name       = $obj.name
                        Type       = $obj.type
                        Action     = $obj.action
                        Status     = $obj.status
                        Message    = if ($obj.PSObject.Properties['message']) {
                            $obj.message 
                        } else {
                            '' 
                        }
                        NackReason = if ($obj.PSObject.Properties['nack_reason']) {
                            $obj.nack_reason 
                        } else {
                            $null 
                        }
                        Resolution = if ($obj.PSObject.Properties['resolution']) {
                            $obj.resolution 
                        } else {
                            $null 
                        }
                    }
                    switch ($obj.status) {
                        'success' {
                            $summary.Success++ 
                        }
                        'already_in_maintenance' {
                            $summary.AlreadyInMaintenance++ 
                        }
                        default {
                            $summary.Failed++ 
                        }
                    }
                } catch {
                    continue 
                }
            } elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                try {
                    $sum = $Matches[1] | ConvertFrom-Json
                    if ($sum.PSObject.Properties['total_objects']) {
                        $summary.Total = $sum.total_objects 
                    }
                } catch {
                    continue 
                }
            }
        }
        $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
        if ($summary.Total -eq 0) {
            $summary.Total = $objects.Count 
        }

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
            $mockServers = if ($ServerHostnames) {
                $ServerHostnames 
            } else {
                @('mock-server-01.example.com', 'mock-server-02.example.com', 'mock-server-03.example.com') 
            }
            $mockObjects = @()
            foreach ($srv in $mockServers) {
                $mockObjects += @{
                    Name       = $srv
                    Type       = 'WindowsComputer'
                    Action     = 'disable'
                    Status     = 'success'
                    Message    = 'Maintenance mode stopped (DryRun)'
                    NackReason = $null
                    Resolution = $null
                }
            }
            $mockObjects += @{
                Name       = $GroupDisplayName
                Type       = 'WindowsCluster'
                Action     = 'disable'
                Status     = 'success'
                Message    = 'Cluster maintenance mode stopped (DryRun)'
                NackReason = $null
                Resolution = $null
            }
            $mockSummary = @{
                Total            = $mockObjects.Count
                Success          = $mockObjects.Count
                NotInMaintenance = 0
                Failed           = 0
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
                            Name       = $obj.name
                            Type       = $obj.type
                            Action     = $obj.action
                            Status     = $obj.status
                            Message    = if ($obj.PSObject.Properties['message']) {
                                $obj.message 
                            } else {
                                '' 
                            }
                            NackReason = if ($obj.PSObject.Properties['nack_reason']) {
                                $obj.nack_reason 
                            } else {
                                $null 
                            }
                            Resolution = if ($obj.PSObject.Properties['resolution']) {
                                $obj.resolution 
                            } else {
                                $null 
                            }
                        }
                        switch ($obj.status) {
                            'success' {
                                $summary.Success++ 
                            }
                            'not_in_maintenance' {
                                $summary.NotInMaintenance++ 
                            }
                            default {
                                $summary.Failed++ 
                            }
                        }
                    } catch {
                        continue 
                    }
                } elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                    try {
                        $sum = $Matches[1] | ConvertFrom-Json
                        if ($sum.PSObject.Properties['total_objects']) {
                            $summary.Total = $sum.total_objects 
                        }
                    } catch {
                        continue 
                    }
                }
            }
            $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
            if ($summary.Total -eq 0) {
                $summary.Total = $objects.Count 
            }
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
                        Name       = $obj.name
                        Type       = $obj.type
                        Action     = $obj.action
                        Status     = $obj.status
                        Message    = if ($obj.PSObject.Properties['message']) {
                            $obj.message 
                        } else {
                            '' 
                        }
                        NackReason = if ($obj.PSObject.Properties['nack_reason']) {
                            $obj.nack_reason 
                        } else {
                            $null 
                        }
                        Resolution = if ($obj.PSObject.Properties['resolution']) {
                            $obj.resolution 
                        } else {
                            $null 
                        }
                    }
                    switch ($obj.status) {
                        'success' {
                            $summary.Success++ 
                        }
                        'not_in_maintenance' {
                            $summary.NotInMaintenance++ 
                        }
                        default {
                            $summary.Failed++ 
                        }
                    }
                } catch {
                    continue 
                }
            } elseif ($trimmed -match '^SUMMARY:(\{.*\})$') {
                try {
                    $sum = $Matches[1] | ConvertFrom-Json
                    if ($sum.PSObject.Properties['total_objects']) {
                        $summary.Total = $sum.total_objects 
                    }
                } catch {
                    continue 
                }
            }
        }
        $summary.Failed = @($objects | Where-Object { $_.Status -eq 'failed' }).Count
        if ($summary.Total -eq 0) {
            $summary.Total = $objects.Count 
        }

        Write-Verbose "SCOM maintenance disable output: $($r.Output)"
        return @{ Success = $r.Success; Output = @($r.Output); Objects = $objects; Summary = $summary }
    }

    # ════════════════════════════════════════════════════════════════════════
    # PRIVATE - SCOM REST API helpers (2019 UR1+ and 2025 only)
    # ════════════════════════════════════════════════════════════════════════

    [hashtable] _EnterMaintenanceRest([string]$EndTimeStr, [string]$Comment,
        [string[]]$ServerHostnames, [bool]$UseClusterMode) {

        if (-not $this.Cred) {
            return @{ Success = $false; Output = 'No SCOM REST credentials' } 
        }

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
    Write-Output "SCOM REST maintenance scheduled. IDs: `$(`$result.Content)"
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
        if (-not $this.Cred) {
            return @{ Success = $false; Output = 'No SCOM REST credentials' } 
        }

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
            $serverJson = if ($ServerHostnames) {
                ($ServerHostnames | ForEach-Object { "`"$($_.Replace('"','\"'))`"" }) -join "," 
            } else {
                '' 
            }
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
    } else { Write-Output "`$(`$inst.Name) not in maintenance - skipping" }
}
if (`$stopped.Count -gt 0) { Write-Output "Stopped maintenance for `$(`$stopped.Count) instances" } else { Write-Output "No instances were in maintenance" }
"@
        }
        $r = $this._RunPs($script)
        return @{ Success = $r.Success; Output = @($r.Output) }
    }

    [hashtable] GetMaintenanceStatus([string]$GroupDisplayName, [string[]]$ServerHostnames = $null, [bool]$UseClusterMode = $false) {
        $this._DetectVersion()

        # For SCOM 2019+ with REST API ready
        if ($this.ScomVersion -ge 2019 -and $this.RestApiReady) {
            return $this._GetMaintenanceStatusRest($GroupDisplayName, $ServerHostnames, $UseClusterMode)
        }

        # For older versions or when REST is not ready, use PowerShell cmdlets
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction SilentlyContinue
if (-not `$group) { Write-Error "Group '$GroupDisplayName' not found"; exit 1 }
`$instances = Get-SCOMClassInstance -Group `$group
`$objects = @()
`$inMaintenance = 0
`$notInMaintenance = 0
`$failed = 0
foreach (`$inst in `$instances) {
    `$obj = @{
        Name = `$inst.DisplayName
        Type = `$inst.ClassName
        InMaintenanceMode = `$false
        MaintenanceModeStartTime = $null
        MaintenanceModeEndTime = $null
        Status = 'unknown'
    }
    try {
        if (`$inst.InMaintenanceMode) {
            `$obj.InMaintenanceMode = `$true
            `$obj.MaintenanceModeStartTime = `$inst.MaintenanceModeStartTime
            `$obj.MaintenanceModeEndTime = `$inst.MaintenanceModeEndTime
            `$obj.Status = 'in_maintenance'
            `$inMaintenance++
        } else {
            `$obj.InMaintenanceMode = `$false
            `$obj.Status = 'not_in_maintenance'
            `$notInMaintenance++
        }
    } catch {
        `$obj.Status = 'failed'
        `$obj.Message = `$_.Exception.Message
        `$failed++
    }
    `$objects += `$obj
}
`$result = @{
    Success = `$true
    GroupName = "$GroupDisplayName"
    Objects = `$objects
    Summary = @{
        Total = `$objects.Count
        InMaintenance = `$inMaintenance
        NotInMaintenance = `$notInMaintenance
        Failed = `$failed
    }
}
`$result | ConvertTo-Json -Depth 5
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            try {
                $result = $r.Output | ConvertFrom-Json
                return @{
                    Success   = $true
                    GroupName = $result.GroupName
                    Objects   = @($result.Objects | ForEach-Object { $_ })
                    Summary   = @{
                        Total            = $result.Summary.Total
                        InMaintenance    = $result.Summary.InMaintenance
                        NotInMaintenance = $result.Summary.NotInMaintenance
                        Failed           = $result.Summary.Failed
                    }
                }
            } catch {
                return @{ Success = $false; Error = "Failed to parse SCOM maintenance status: $($_.Exception.Message)" }
            }
        }
        return @{ Success = $false; Error = "Failed to query SCOM maintenance status: $($r.Output)" }
    }

    [hashtable] _GetMaintenanceStatusRest([string]$GroupDisplayName, [string[]]$ServerHostnames, [bool]$UseClusterMode) {
        if (-not $this.Cred) {
            return @{ Success = $false; Error = 'No SCOM REST credentials' } 
        }

        $script = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$server     = "$($this.MgmtServer)"
`$user       = "$($this.Cred['username'])"
`$pass       = "$($this.Cred['password'])"
`$baseUrl    = "http://`$server/OperationsManager"

# Authenticate
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

# Get group and its members
`$bodyCriteria = "DisplayName LIKE '%$GroupDisplayName%'" | ConvertTo-Json
try {
    `$classResp = Invoke-WebRequest -Uri "`$baseUrl/data/class/monitors" `
        -Method Post -Body `$bodyCriteria -Headers `$headers -WebSession `$session `
        -ErrorAction Stop
    `$classData = `$classResp.Content | ConvertFrom-Json
} catch {
    Write-Error "Failed to query group: `$(`$_.Exception.Message)"
    exit 1
}

`$objects = @()
`$inMaintenance = 0
`$notInMaintenance = 0
`$failed = 0

foreach (`$obj in `$classData) {
    `$objInfo = @{
        Name = `$obj.DisplayName
        Type = `$obj.ClassName
        InMaintenanceMode = `$false
        MaintenanceModeStartTime = $null
        MaintenanceModeEndTime = $null
        Status = 'unknown'
    }
    try {
        # Check if object is in maintenance mode via REST API
        `$maintResp = Invoke-WebRequest -Uri "`$baseUrl/data/maintenance/object/$(`$obj.Id)" `
            -Method Get -Headers `$headers -WebSession `$session `
            -ErrorAction SilentlyContinue
        if (`$maintResp.StatusCode -eq 200) {
            `$maintData = `$maintResp.Content | ConvertFrom-Json
            `$objInfo.InMaintenanceMode = `$true
            `$objInfo.MaintenanceModeStartTime = `$maintData.StartTime
            `$objInfo.MaintenanceModeEndTime = `$maintData.ScheduledEndTime
            `$objInfo.Status = 'in_maintenance'
            `$inMaintenance++
        } else {
            `$objInfo.InMaintenanceMode = `$false
            `$objInfo.Status = 'not_in_maintenance'
            `$notInMaintenance++
        }
    } catch {
        `$objInfo.Status = 'not_in_maintenance'
        `$notInMaintenance++
    }
    `$objects += `$objInfo
}

`$result = @{
    Success = `$true
    GroupName = "$GroupDisplayName"
    Objects = `$objects
    Summary = @{
        Total = `$objects.Count
        InMaintenance = `$inMaintenance
        NotInMaintenance = `$notInMaintenance
        Failed = `$failed
    }
}
`$result | ConvertTo-Json -Depth 5
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            try {
                $result = $r.Output | ConvertFrom-Json
                return @{
                    Success   = $true
                    GroupName = $result.GroupName
                    Objects   = @($result.Objects | ForEach-Object { $_ })
                    Summary   = @{
                        Total            = $result.Summary.Total
                        InMaintenance    = $result.Summary.InMaintenance
                        NotInMaintenance = $result.Summary.NotInMaintenance
                        Failed           = $result.Summary.Failed
                    }
                }
            } catch {
                return @{ Success = $false; Error = "Failed to parse SCOM REST maintenance status: $($_.Exception.Message)" }
            }
        }
        return @{ Success = $false; Error = "Failed to query SCOM REST maintenance status: $($r.Output)" }
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
        $this.ModuleName = $ovConfig.Get_Item('module_name')
        if (-not $this.ModuleName) {
            $this.ModuleName = $this._DetectRecommendedModule($this.Appliance)
        }
        $this._ValidateModuleCompat($this.ModuleName, $this.Appliance)
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

    hidden static [hashtable[]] $OneViewModuleApplianceMap = @(
        @{ Module = 'HPEOneView.1000'; MinAppliance = '10.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.910'; MinAppliance = '9.10'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.900'; MinAppliance = '9.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.860'; MinAppliance = '8.60'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.840'; MinAppliance = '8.40'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.830'; MinAppliance = '8.30'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.800'; MinAppliance = '8.00'; PsVersion = '7.0'; Note = 'Requires PS 7+' },
        @{ Module = 'HPEOneView.720'; MinAppliance = '7.20'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' },
        @{ Module = 'HPEOneView.710'; MinAppliance = '7.10'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' },
        @{ Module = 'HPEOneView.700'; MinAppliance = '7.00'; PsVersion = '5.1'; Note = 'PS 5.1/7 compatible' }
    )

    [string] _DetectRecommendedModule([string]$Appliance) {
        $availableModules = Get-Module -ListAvailable HPEOneView.* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        if (-not $availableModules) {
            $availableModules = Get-Module -ListAvailable HPOneView.* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        }
        
        if ($availableModules) {
            $sortedModules = $availableModules | Sort-Object { 
                if ($_ -match 'HPEOneView\.(\d+)') { [int]$matches[1] }
                elseif ($_ -match 'HPOneView\.(\d+)') { [int]$matches[1] }
                else { 0 }
            } -Descending
            $recommended = $sortedModules[0]
            Write-Information "HPE OneView module detected: $recommended" -InformationAction Continue
            return $recommended
        }
        
        return 'HPEOneView.1000'
    }

    [void] _ValidateModuleCompat([string]$ModuleName, [string]$Appliance) {
        $moduleInfo = $null
        if ($ModuleName -match 'HPEOneView\.(\d+)') {
            $moduleInfo = [OneViewClient]::OneViewModuleApplianceMap | Where-Object { $_.Module -eq $ModuleName }
        } elseif ($ModuleName -match 'HPOneView\.(\d+)') {
            $moduleInfo = [OneViewClient]::OneViewModuleApplianceMap | Where-Object { $_.Module -eq $ModuleName }
            if (-not $moduleInfo) {
                Write-Warning "Legacy module name detected: '$ModuleName'. Consider updating config to HPEOneView.Xxx format."
            }
        }
        
        if ($moduleInfo -and $moduleInfo.Note -match 'PS 7\+') {
            $psVerTable = Get-Variable -Name PSVersionTable -Scope Global -ErrorAction SilentlyContinue
            if ($psVerTable -and $psVerTable.Value.PSVersion.Major -lt 7) {
                $psVer = $psVerTable.Value.PSVersion.ToString()
                Write-Warning "Module '$ModuleName' requires PowerShell 7.0+. Current: $psVer. Use HPEOneView.720 or earlier for PS 5.1 compatibility."
            }
        }
        
        Write-Verbose "OneView module selected: $ModuleName"
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
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
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
                    Total                = $result.Summary.Total
                    Success              = $result.Summary.Success
                    AlreadyInMaintenance = $result.Summary.AlreadyInMaintenance
                    Failed               = $result.Summary.Failed
                }
            }
        } catch {
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
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
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
                    Total            = $result.Summary.Total
                    Success          = $result.Summary.Success
                    NotInMaintenance = $result.Summary.NotInMaintenance
                    Failed           = $result.Summary.Failed
                }
            }
        } catch {
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
        if ($DryRun) {
            return @{
                Success    = $true
                TargetType = 'Scope'
                TargetName = $TargetId
                SerialNumber = $null
                MaintenanceModeEnabled = $null
                Message    = 'Found scope (cluster) [DRY-RUN]'
            }
        }
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$server = Get-OVServer -Name '$TargetId' -ErrorAction SilentlyContinue
if (`$server) {
    `$result = @{ Success = `$true; TargetType = 'ServerHardware'; TargetName = `$server.Name; SerialNumber = `$server.serialNumber; MaintenanceModeEnabled = [bool]`$server.MaintenanceModeEnabled; Model = `$server.model; State = `$server.state; Message = 'Found server' }
    `$result | ConvertTo-Json -Depth 5
    return
}
`$scope = Get-OVSCOPE -Name '$TargetId' -ErrorAction SilentlyContinue
if (`$scope) {
    `$result = @{ Success = `$true; TargetType = 'Scope'; TargetName = `$scope.Name; SerialNumber = `$null; MaintenanceModeEnabled = `$null; Message = 'Found scope (cluster)' }
    `$result | ConvertTo-Json -Depth 5
    return
}
`$result = @{ Success = `$false; TargetType = 'Unknown'; TargetName = '$TargetId'; SerialNumber = `$null; MaintenanceModeEnabled = `$null; Message = 'Not found as server or scope' }
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
                Success                = $result.Success
                TargetType             = $result.TargetType
                TargetName             = $result.TargetName
                SerialNumber           = $result.SerialNumber
                MaintenanceModeEnabled = $result.MaintenanceModeEnabled
                Model                  = $result.Model
                State                  = $result.State
                Message                = $result.Message
            }
        } catch {
            return @{
                Success                = $false
                TargetType             = 'Unknown'
                TargetName             = $TargetId
                SerialNumber           = $null
                MaintenanceModeEnabled = $null
                Model                  = $null
                State                  = $null
                Message                = "Resolve failed: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] GetMaintenanceStatus([object]$Target, [string]$TargetType) {
        if ($this.UseWinRM) {
            return $this._GetMaintenanceStatusViaWinRM($Target, $TargetType)
        }
        return $this._GetMaintenanceStatusViaModule($Target, $TargetType)
    }

    [hashtable] _GetMaintenanceStatusViaModule([object]$Target, [string]$TargetType) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}
`$objects = @()
`$inMaintenance = 0
`$notInMaintenance = 0
`$failed = 0
if ('$TargetType' -eq 'ServerHardware') {
    `$server = Get-OVServer -Name '$Target' -ErrorAction Stop
    `$obj = @{
        Name = `$server.Name
        Type = `$server.Type
        InMaintenanceMode = `$server.MaintenanceModeEnabled
        Status = if (`$server.MaintenanceModeEnabled) { 'in_maintenance' } else { 'not_in_maintenance' }
        Message = if (`$server.MaintenanceModeEnabled) { 'Server is in maintenance mode' } else { 'Server is not in maintenance mode' }
    }
    if (`$server.MaintenanceModeEnabled) {
        `$inMaintenance++
    } else {
        `$notInMaintenance++
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
            InMaintenanceMode = `$server.MaintenanceModeEnabled
            Status = if (`$server.MaintenanceModeEnabled) { 'in_maintenance' } else { 'not_in_maintenance' }
            Message = if (`$server.MaintenanceModeEnabled) { 'Server is in maintenance mode' } else { 'Server is not in maintenance mode' }
        }
        if (`$server.MaintenanceModeEnabled) {
            `$inMaintenance++
        } else {
            `$notInMaintenance++
        }
        `$objects += `$obj
    }
}
`$result = @{
    Success = `$true
    TargetType = '$TargetType'
    TargetName = '$Target'
    Objects = `$objects
    Summary = @{
        Total = `$objects.Count
        InMaintenance = `$inMaintenance
        NotInMaintenance = `$notInMaintenance
        Failed = `$failed
    }
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
                Success    = $result.Success
                TargetType = $result.TargetType
                TargetName = $result.TargetName
                Objects    = @($result.Objects | ForEach-Object { $_ })
                Summary    = @{
                    Total            = $result.Summary.Total
                    InMaintenance    = $result.Summary.InMaintenance
                    NotInMaintenance = $result.Summary.NotInMaintenance
                    Failed           = $result.Summary.Failed
                }
            }
        } catch {
            return @{
                Success = $false
                Error   = "OneView maintenance status check failed: $($_.Exception.Message)"
                Objects = @()
                Summary = @{ Total = 0; InMaintenance = 0; NotInMaintenance = 0; Failed = 1 }
            }
        }
    }

    [hashtable] _GetMaintenanceStatusViaWinRM([object]$Target, [string]$TargetType) {
        return $this._GetMaintenanceStatusViaModule($Target, $TargetType)
    }

    [hashtable] ResolveServerBySerial([string]$SerialNumber) {
        $ovModule = $this.ModuleName
        $ovAppliance = $this.Appliance
        $scriptContent = @"
Import-Module $ovModule -ErrorAction Stop
`$existingSession = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
if (-not `$existingSession) {
    `$securePass = ConvertTo-SecureString '$($this.Password)' -AsPlainText -Force
    `$cred = New-Object System.Management.Automation.PSCredential('$($this.Username)', `$securePass)
    Connect-OVMgmt -Appliance '$ovAppliance' -Credential `$cred -ErrorAction Stop
}

`$server = `$null

`$session = `$null
try {
    `$session = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true -and `$_.Name -like '*$ovAppliance*' } | Select-Object -First 1
    if (-not `$session) {
        `$session = `$ConnectedSessions | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
    }
} catch {
    try {
        `$session = Get-OVApplianceSession | Where-Object { `$_.Connected -eq `$true } | Select-Object -First 1
    } catch { }
}

`$applianceVersion = `$null
`$apiVersion = `$null
if (`$session) {
    `$applianceVersion = try { [version]`$session.ApplianceVersion } catch { `$null }
    if (`$applianceVersion) {
        `$apiVersion = switch (`$true) {
            (`$applianceVersion.Major -ge 10) { 2400 }
            (`$applianceVersion.Major -ge 9 -and `$applianceVersion.Minor -ge 10) { 2200 }
            (`$applianceVersion.Major -ge 9) { 2000 }
            (`$applianceVersion.Major -ge 8 -and `$applianceVersion.Minor -ge 60) { 1800 }
            (`$applianceVersion.Major -ge 8 -and `$applianceVersion.Minor -ge 40) { 1400 }
            (`$applianceVersion.Major -ge 8 -and `$applianceVersion.Minor -ge 10) { 1200 }
            (`$applianceVersion.Major -ge 8) { 1000 }
            (`$applianceVersion.Major -ge 7 -and `$applianceVersion.Minor -ge 20) { 400 }
            (`$applianceVersion.Major -ge 7 -and `$applianceVersion.Minor -ge 10) { 300 }
            (`$applianceVersion.Major -ge 7) { 200 }
            default { 0 }
        }
    }
}

`$restOk = `$false
if (`$apiVersion -and `$apiVersion -ge 200) {
    try {
        `$sessionId = `$null
        if (`$session.SessionID) {
            `$sessionId = `$session.SessionID
        } elseif (`$session -and `$session.GetType().Name -eq 'AuthSession') {
            `$sessionId = `$session.Id
        }
        `$ovAuthVar = Get-Variable -Name 'OVDefaultAuth' -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        if (-not `$sessionId -and `$ovAuthVar.SessionID) {
            `$sessionId = `$ovAuthVar.SessionID
        }

        if (`$sessionId) {
            `$headers = @{
                'Accept'       = 'application/json'
                'Content-Type' = 'application/json'
                'auth'         = `$sessionId
                'X-API-Version'= [string]`$apiVersion
            }
            `$restUri = "https://`$(`$session.Name)/rest/server-hardware?filter=serialNumber='`$using:SerialNumber'"
            `$resp = Invoke-RestMethod -Uri `$restUri -Headers `$headers -Method GET -ErrorAction Stop
            if (`$resp.members -and `$resp.members.Count -gt 0) {
                `$restMember = `$resp.members[0]
                `$server = @{
                    Name         = `$restMember.name
                    SerialNumber = `$restMember.serialNumber
                    Model        = `$restMember.model
                    State        = `$restMember.state
                }
                `$restOk = `$true
            }
        }
    } catch {
        Write-Verbose "REST serial lookup failed (API v`$apiVersion): `$(`$_.Exception.Message)"
    }
}

if (-not `$restOk) {
    try {
        `$cmd = Get-Command Get-OVServer -ErrorAction Stop
        if (`$cmd.Parameters.ContainsKey('SerialNumber')) {
            `$ovServer = Get-OVServer -SerialNumber '$SerialNumber' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (`$ovServer) {
                `$server = @{
                    Name         = `$ovServer.name
                    SerialNumber = `$ovServer.serialNumber
                    Model        = `$ovServer.model
                    State        = `$ovServer.state
                }
            }
        } else {
            `$allServers = Get-OVServer -ErrorAction Stop
            `$ovServer = `$allServers | Where-Object { `$_.serialNumber -eq '$SerialNumber' } | Select-Object -First 1
            if (`$ovServer) {
                `$server = @{
                    Name         = `$ovServer.name
                    SerialNumber = `$ovServer.serialNumber
                    Model        = `$ovServer.model
                    State        = `$ovServer.state
                }
            }
        }
    } catch {
        Write-Verbose "Module cmdlet fallback failed: `$(`$_.Exception.Message)"
    }
}

if (`$server) {
    `$out = @{ Success = `$true; ServerName = `$server.Name; SerialNumber = `$server.SerialNumber; Model = `$server.Model; State = `$server.State; ApiVersion = `$apiVersion; Message = "Resolved via OneView API (v`$apiVersion)" }
    `$out | ConvertTo-Json -Depth 5
} else {
    `$out = @{ Success = `$false; ServerName = `$null; SerialNumber = '$SerialNumber'; ApiVersion = `$apiVersion; Message = "No server found with serial number '$SerialNumber' in OneView appliance '$ovAppliance' (module $ovModule, API version resolved: `$apiVersion)" }
    `$out | ConvertTo-Json -Depth 3
}
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
                Success      = $result.Success
                ServerName   = $result.ServerName
                SerialNumber = $result.SerialNumber
                Model        = $result.Model
                State        = $result.State
                ApiVersion   = $result.ApiVersion
                Message      = $result.Message
            }
        } catch {
            return @{
                Success      = $false
                ServerName   = $null
                SerialNumber = $SerialNumber
                ApiVersion   = $null
                Message      = "Resolve by serial failed: $($_.Exception.Message)"
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
        if ($this.UseSimple) {
            return $this.SimpleRecipients 
        }
        $key = "maintenance_$Action"
        if ($this.DistLists.ContainsKey($key)) {
            return $this.DistLists[$key] 
        }
        return @()
    }

    [bool] SendMaintenanceNotification([string]$Action, [hashtable]$Cluster, [string[]]$Servers,
        [Nullable[DateTime]]$StartTime, [Nullable[DateTime]]$EndTime, [bool]$DryRun) {
        $recipients = $this._GetRecipients($Action)
        if (-not $recipients) {
            Write-Warning "No distribution list for action '$Action'; skipping email"
            return $false
        }
        $clusterName = if ($Cluster) {
            $Cluster.Get_Item('display_name') ?? $Cluster.Get_Item('scom_group') ?? 'Unknown' 
        } else {
            'Unknown' 
        }
        $environment = if ($Cluster) {
            $Cluster.Get_Item('environment') ?? 'unknown' 
        } else {
            'unknown' 
        }
        $startStr = if ($StartTime -and $StartTime -ne [DateTime]::MinValue) {
            $StartTime.ToString('yyyy-MM-dd HH:mm:ss') 
        } else {
            'N/A' 
        }
        $endStr = if ($EndTime -and $EndTime -ne [DateTime]::MinValue) {
            $EndTime.ToString('yyyy-MM-dd HH:mm:ss') 
        } else {
            'N/A' 
        }
        $tplVars = @{
            cluster_name    = $clusterName
            environment     = $environment
            servers         = ($Servers -join ', ')
            start_time      = $startStr
            end_time        = $endStr
            triggered_by    = 'iRequest'
            additional_info = if ($Action -eq 'enabled') {
                'Maintenance mode is now ACTIVE.' 
            } elseif ($Action -eq 'disabled') {
                'Maintenance mode has ENDED.' 
            } else {
                "Maintenance action: $Action" 
            }
        }
        $subjTpl = $this.Templates.Get_Item("subject_$Action") ?? "Maintenance {action} - {cluster_name} ({environment})"
        $subject = $subjTpl.Replace('{action}', $Action).Replace('{cluster_name}', $clusterName).Replace('{environment}', $environment)
        $bodyTpl = $this.Templates.Get_Item('body_template') ??
        "Dear Team,`n`nMaintenance window for cluster '$clusterName' has $Action.`n`nStart: $startStr`nEnd: $endStr`nServers: $($Servers -join ', ')`n`n$($tplVars['additional_info'])`n`nRegards,`nMaintenance Bot"
        $bodyAction = if ($Action -eq 'enabled') {
            'been ENABLED' 
        } elseif ($Action -eq 'disabled') {
            'been DISABLED' 
        } else {
            $Action 
        }
        $body = $bodyTpl.Replace('{action}', $bodyAction)
        foreach ($k in $tplVars.Keys) {
            $body = $body.Replace("{${k}}", $tplVars[$k]); $subject = $subject.Replace("{${k}}", $tplVars[$k]) 
        }

        if ($DryRun) {
            Write-Verbose "[DRY RUN] Email to: $($recipients -join ', ')"
            Write-Verbose "Subject: $subject"
            Write-Verbose "Body: $body"
            return $true
        }

        try {
            $mailMsg = New-Object System.Net.Mail.MailMessage($this.FromAddr, $recipients[0])
            foreach ($r in $recipients) {
                $mailMsg.To.Add($r) | Out-Null 
            }
            $mailMsg.Subject = $subject
            $mailMsg.Body = $body
            $mailMsg.IsBodyHtml = $false
            $smtp = if ($this.UseSsl) {
                [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
            } else {
                $s = [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
                if ($this.UseTls) {
                    $s.EnableSsl = $true 
                }
                $s
            }
            if ($this.Username) {
                $sec = ConvertTo-SecureString $this.Password -AsPlainText -Force
                $smtp.Credentials = New-Object System.Management.Automation.PSCredential($this.Username, $sec)
            }
            $smtp.Send($mailMsg)
            Write-Verbose "Notification email sent to $($recipients -join ', ')"
            return $true
        } catch {
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
    # For OneView mode, either TargetId or SerialNumber is required
    # For SCOM mode, TargetId is always required
    if (-not $Mode) {
        Write-Error "Mode is required for CLI execution."
        exit 1
    }
    
    if ($Mode -eq 'oneview' -and -not $TargetId -and -not $SerialNumber) {
        Write-Error "For OneView mode, either TargetId or SerialNumber is required."
        exit 1
    }
    
    if ($Mode -eq 'scom' -and -not $TargetId) {
        Write-Error "TargetId is required for SCOM mode."
        exit 1
    }

    # Debug: show variable state
    Write-Verbose "Script:BaseDir = '$Script:BaseDir'"
    Write-Verbose "Script:ConfigDir = '$Script:ConfigDir'"
    Write-Verbose "PSBoundParameters.ConfigDir = '$(if ($PSBoundParameters.ContainsKey('ConfigDir')) { 'SET' } else { 'NOT SET' })'"
    Write-Verbose "Environment = '$(if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } else { 'NOT SET - will use ENVIRONMENT env var or default to Prod' })'"
    Write-Verbose "ManagementHost = '$(if ($PSBoundParameters.ContainsKey('ManagementHost')) { $ManagementHost } else { 'NOT SET' })'"

    $result = Set-MaintenanceMode @PSBoundParameters

    # Check if function returned an error (e.g., SerialNumber with SCOM mode)
    if (-not $result.ContainsKey('Success') -or -not $result.Success) {
        Write-Output "=== Maintenance Mode Command Audit ==="
        Write-Output "Timestamp (UTC): $(Get-UtcTimestamp)"
        Write-Output "Timestamp (Local): $(Get-LocalTimestamp)"
        Write-Output "Action: $Action"
        Write-Output "Target ID: $TargetId"
        Write-Output "Mode: $Mode"
        if ($PSBoundParameters.ContainsKey('Environment')) {
            Write-Output "Environment: $Environment"
        }
        if ($PSBoundParameters.ContainsKey('SerialNumber')) {
            Write-Output "Serial Number: $SerialNumber"
        }
        if ($Action -eq 'enable') {
            Write-Output "Start Time (UTC): $($result['StartTimeUtc'] ?? 'N/A')"
            Write-Output "End Time (UTC): $($result['EndTimeUtc'] ?? 'N/A')"
        }
        Write-Output ""
        Write-Output "=== Command Result ==="
        Write-Output "Success: False"
        Write-Output "Error: $($result.Error)"
        Write-Output "======================"
        exit 1
    }

    # Add request metadata for traceability
    $result['request_type'] = "maintenance_$Action"
    $result['timestamp'] = Get-UtcTimestamp
    $result['timestamp_local'] = Get-LocalTimestamp
    $result['source'] = 'direct'

    if ($Json) {
        $result | ConvertTo-Json -Depth 64
        exit $(if ($result.Success) {
                0 
            } else {
                1 
            })
    }

    # Human-readable output
    Write-Output "=== Maintenance Mode Command Audit ==="
    Write-Output "Timestamp (UTC): $($result['timestamp'])"
    Write-Output "Timestamp (Local): $($result['timestamp_local'])"
    Write-Output "Action: $Action"
    if ($TargetId) {
        Write-Output "Target ID: $TargetId"
    } elseif ($SerialNumber) {
        Write-Output "Serial Number: $SerialNumber"
    }
    Write-Output "Target Object Name: $($result['ClusterName'] ?? $TargetId ?? $SerialNumber)"
    Write-Output "Mode: $Mode"
    if ($PSBoundParameters.ContainsKey('Environment')) {
        Write-Output "Environment: $Environment"
    }
    if ($PSBoundParameters.ContainsKey('ManagementHost')) {
        Write-Output "Management Host: $ManagementHost"
    }
    if ($PSBoundParameters.ContainsKey('Username')) {
        Write-Output "Username: $Username"
    }
    Write-Output "Post-Disable Wait: ${PostDisableWaitSeconds}s"
    Write-Output "Config Dir: $ConfigDir"
    if ($Action -eq 'enable') {
        Write-Output "Start Time (UTC): $($result['StartTimeUtc'] ?? 'N/A')"
        Write-Output "End Time (UTC): $($result['EndTimeUtc'] ?? 'N/A')"
    }
    Write-Output "Dry Run: $DryRun"
    Write-Output "No Schedule: $NoSchedule"
    if ($Action -eq 'validate') {
        Write-Output "Overall Maintenance Status: $($result['OverallStatus'])"
    }
    Write-Output "==================================="
    Write-Output ""

    # Per-object SCOM status table
    $scomObjects = $result['ScomObjects']
    $scomSummary = $result['ScomSummary']
    if ($scomObjects -and $scomObjects.Count -gt 0) {
        Write-Output "=== SCOM Per-Object Status ==="
        Write-Output "Total Objects: $($scomSummary.Total)"
        Write-Output "Success: $($scomSummary.Success)"
        Write-Output "In Maintenance: $($scomSummary.InMaintenance ?? $scomSummary.AlreadyInMaintenance ?? $scomSummary.NotInMaintenance ?? 0)"
        Write-Output "Failed: $($scomSummary.Failed)"
        Write-Output ""
        foreach ($obj in $scomObjects) {
            $statusIcon = switch ($obj.Status) {
                'success' {
                    '[OK]' 
                }
                'already_in_maintenance' {
                    '[SKIP]' 
                }
                'not_in_maintenance' {
                    '[SKIP]' 
                }
                default {
                    '[FAIL]' 
                }
            }
            Write-Output "${statusIcon} $($obj.Name) ($($obj.Type)) - $($obj.Status)"
            if ($obj.Message -and $obj.Status -ne 'success' -and $obj.Status -ne 'already_in_maintenance' -and $obj.Status -ne 'not_in_maintenance') {
                Write-Output "  Message: $($obj.Message)"
            }
            if ($obj.NackReason) {
                Write-Output "  NACK Reason: $($obj.NackReason)"
            }
            if ($obj.Resolution) {
                Write-Output "  Resolution: $($obj.Resolution)"
            }
        }
        Write-Output "==============================="
        Write-Output ""
    }

    $oneviewObjects = $result['OneViewObjects']
    $oneviewSummary = $result['OneViewSummary']
    if ($oneviewObjects -and $oneviewObjects.Count -gt 0) {
        Write-Output "=== OneView Per-Object Status ==="
        Write-Output "Total Objects: $($oneviewSummary.Total)"
        Write-Output "Success: $($oneviewSummary.Success)"
        Write-Output "In Maintenance: $($oneviewSummary.AlreadyInMaintenance ?? $oneviewSummary.InMaintenance ?? $oneviewSummary.NotInMaintenance ?? 0)"
        Write-Output "Failed: $($oneviewSummary.Failed)"
        Write-Output ""
        foreach ($obj in $oneviewObjects) {
            $statusIcon = switch ($obj.Status) {
                'success' {
                    '[OK]' 
                }
                'already_in_maintenance' {
                    '[SKIP]' 
                }
                'not_in_maintenance' {
                    '[SKIP]' 
                }
                default {
                    '[FAIL]' 
                }
            }
            Write-Output "${statusIcon} $($obj.Name) ($($obj.Type)) - $($obj.Status)"
            if ($obj.Message -and $obj.Status -ne 'success' -and $obj.Status -ne 'already_in_maintenance' -and $obj.Status -ne 'not_in_maintenance') {
                Write-Output "  Message: $($obj.Message)"
            }
            if ($obj.NackReason) {
                Write-Output "  NACK Reason: $($obj.NackReason)"
            }
            if ($obj.Resolution) {
                Write-Output "  Resolution: $($obj.Resolution)"
            }
        }
        Write-Output "================================="
        Write-Output ""
    }

    # NACK summary for troubleshooting
    $failedObjects = $result['FailedObjects']
    if ($failedObjects -and $failedObjects.Count -gt 0) {
        Write-Host "=== NACK Summary (Failed Objects) ===" -ForegroundColor Red
        Write-Output "Total Failed: $($failedObjects.Count)"
        foreach ($obj in $failedObjects) {
            Write-Output "  - $($obj.Name): $($obj.NackReason ?? $obj.Status)"
            if ($obj.Resolution) {
                Write-Output "    Fix: $($obj.Resolution)" 
            }
        }
        Write-Output "==================================="
        Write-Output ""
    }

    Write-Output "=== Command Result ==="
    Write-Output "Success: $($result.Success)"
    if ($result.Message) {
        $message = $result.Message
        if ($result.StatusText) {
            $bold = if ($PSStyle) {
                $PSStyle.Bold 
            } else {
                '' 
            }
            $reset = if ($PSStyle) {
                $PSStyle.Reset 
            } else {
                '' 
            }
            $message = $message -replace "currently $([regex]::Escape($result.StatusText))", "currently ${bold}$($result.StatusText)${reset}"
        }
        Write-Output "Message: $message"
    }
    if ($result.Error) {
        Write-Output "Error: $($result.Error)" 
    }
    Write-Output "======================"

    exit $(if ($result.Success) {
            0 
        } else {
            1 
        })
}

# vim: ts=4 sw=4 et
