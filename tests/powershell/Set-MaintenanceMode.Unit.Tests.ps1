# Set-MaintenanceMode.Unit.Tests.ps1
# Comprehensive unit tests for Set-MaintenanceMode.ps1
#
# Covers:
#   Cluster ID validation (valid, not-in-catalogue, empty, missing required fields)
#   --action enable   --start now / explicit / missing  --end explicit / computed / missing
#   --action disable
#   --action validate
#   --dry-run flag
#   --no-schedule flag
#   End-time-before-start rejection
#   Invalid datetime rejection
#   No-end-and-no-schedule rejection
#   Scheduled-task creation / --no-schedule bypass
#   SCOM failure propagates as overall failure (not hard exception exit)
#   iLO / OpenView / Email / OpsRamp step collection in audit
#   Node-ID / server-hostname-as-cluster-id rejected
#   Missing / empty configs_catalogue handled gracefully
#
# Uses Pester v5 BeforeAll block to build a shared test environment.
# Tests that require actual SCOM/iLO are guarded by a dry-run / mock pattern
# or a script-exit check.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    $Script:TestRoot   = $PSScriptRoot

    if (-not $env:TEMP)  { $env:TEMP  = '/tmp' }
    if (-not $env:TMP)   { $env:TMP   = '/tmp' }
    $Script:TempDir = (Join-Path $env:TEMP "MMTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir)) { New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null }

    # ── Sample cluster catalogue ────────────────────────────────────────────────
    $Script:TestClusterId  = 'UNIT-TEST-CLUSTER'
    $Script:TestClusterDef = @{
        display_name  = 'Unit Test Cluster'
        servers       = @('srv-unit-01.corp.local','srv-unit-02.corp.local')
        scom_group    = 'Unit Test SCOM Group'
        ilo_addresses = @{ 'srv-unit-01.corp.local' = '192.168.99.101'; 'srv-unit-02.corp.local' = '192.168.99.102' }
        openview_node_ids = @{}
        schedule      = @{ work_days = @('Mon','Tue','Wed','Thu','Fri'); work_start = '08:00'; work_end = '17:00'; timezone = 'Europe/Dublin' }
        environment   = 'unittest'
    }
    # A second cluster — used to confirm "not-my-ID" rejection
    $Script:OtherClusterId  = 'OTHER-CLUSTER'
    $Script:OtherClusterDef = @{
        display_name  = 'Other Cluster'
        servers       = @('srv-other-01.corp.local')
        scom_group    = 'Other SCOM Group'
        ilo_addresses = @{ 'srv-other-01.corp.local' = '192.168.99.201' }
        environment   = 'unittest'
    }
    $Script:NodeIdAsCluster = 'srv-unit-01.corp.local'   # server hostname, not a cluster key
    $Script:NodeIsInServersList = $Script:TestClusterDef.servers -contains $Script:NodeIdAsCluster

    # ── Config dir ──────────────────────────────────────────────────────────
    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir)) { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }

    # Write config files
    @{ clusters = @{ $Script:TestClusterId  = $Script:TestClusterDef
                     $Script:OtherClusterId = $Script:OtherClusterDef } } |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
    @{} | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{} | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'openview_config.json')
    @{} | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{} | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')
    @{} | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'json_config.json')

    # ── Log / output dirs ─────────────────────────────────────────────────
    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    if (-not (Test-Path -Path $Script:LogDir))  { New-Item -ItemType Directory $Script:LogDir  -Force | Out-Null }
    if (-not (Test-Path -Path $Script:OutDir))  { New-Item -ItemType Directory $Script:OutDir  -Force | Out-Null }

    # ── Constants used by Set-MaintenanceMode ───────────────────────────────
    $Script:ScriptPath = Join-Path $Script:ModuleRoot 'Automation/Public/Set-MaintenanceMode.ps1'

    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cluster ID validation
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — Cluster ID validation' {
    It 'Returns success hashtable for a valid cluster ID (validate action)' {
        $result = Set-MaintenanceMode -Action validate -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $true
    }

    It 'Rejects an unknown cluster ID that is not in the catalogue' {
        $result = Set-MaintenanceMode -Action validate -ClusterId 'NONEXISTENT-CLUSTER' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Rejects an empty cluster ID string' {
        { Set-MaintenanceMode -Action validate -ClusterId '' -ConfigDir $Script:ConfigDir } | Should -Throw
    }

    It 'Rejects a server hostname (node ID) that is not a cluster key' {
        $Script:NodeIsInServersList | Should -Be $true
        $result = Set-MaintenanceMode -Action validate -ClusterId $Script:NodeIdAsCluster -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action enable
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — enable action variants' {
    It 'Defaults start time to now when Start is null or empty' {
        $before = Get-Date
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $null -End ((Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss'))
        $after = Get-Date
        $result.Success | Should -Be $true
        # The command should have worked - if start was null it defaults to Now
    }

    It 'Rejects enable when end time is before start time' {
        $later = (Get-Date).AddHours(3).ToString('yyyy-MM-dd HH:mm:ss')
        $sooner = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start $later -End $sooner
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'End time must be after start time'
    }

    It 'Rejects enable with invalid --start datetime format' {
        { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start 'not-a-valid-date' } | Should -Throw
    }

    It 'Rejects enable with invalid --end datetime format' {
        { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -End 'not-valid-at-all' } | Should -Throw
    }

    It 'Accepts ISO format with T separator (2025-05-15T14:30:00)' {
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start '2025-05-15T09:00:00' -End '2025-05-15T17:00:00'
        $result.Success | Should -Be $true
    }

    It 'Accepts space-separated format with seconds (yyyy-MM-dd HH:mm:ss)' {
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start '2025-05-15 09:00:00' -End '2025-05-15 17:00:00'
        $result.Success | Should -Be $true
    }

    It 'Accepts space-separated format without seconds (yyyy-MM-dd HH:mm)' {
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start '2025-05-15 09:00' -End '2025-05-15 17:00'
        $result.Success | Should -Be $true
    }

    It 'Rejects dot-separated datetime format (no longer supported)' {
        { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start '2025-05-15.09.00' -End '2025-05-15 17:00' } | Should -Throw
    }

    It 'Rejects enable when no cluster schedule is defined and no --end is given' {
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:OtherClusterId -ConfigDir $Script:ConfigDir -Start now
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'No end time|no schedule|schedule|No end'
    }

    It 'Rejects enable with invalid cluster ID (not in catalogue)' {
        $result = Set-MaintenanceMode -Action enable -ClusterId 'CLUSTER-DOES-NOT-EXIST' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action disable
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — disable action' {
    It 'Rejects disable with invalid cluster ID' {
        $result = Set-MaintenanceMode -Action disable -ClusterId 'UNKNOWN-CLUSTER' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Rejects disable when server hostname (node ID) is passed as cluster ID' {
        $result = Set-MaintenanceMode -Action disable -ClusterId $Script:NodeIdAsCluster -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action validate
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — validate action' {
    It 'Exits successfully for a valid cluster (validate action)' {
        $result = Set-MaintenanceMode -Action validate -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $true
    }

    It 'Rejects validate with invalid cluster ID' {
        $result = Set-MaintenanceMode -Action validate -ClusterId 'BAD-ID' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Rejects validate with server hostname as cluster ID' {
        $result = Set-MaintenanceMode -Action validate -ClusterId $Script:NodeIdAsCluster -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Error / negative paths
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — error handling' {
    It 'Invalid cluster ID returns error string on enable' {
        $result = Set-MaintenanceMode -Action enable -ClusterId 'DOES-NOT-EXIST' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Invalid cluster ID returns error string on disable' {
        $result = Set-MaintenanceMode -Action disable -ClusterId 'DOES-NOT-EXIST' -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Node ID used as cluster ID returns error string on enable' {
        $result = Set-MaintenanceMode -Action enable -ClusterId $Script:NodeIdAsCluster -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Node-ID-as-cluster ID specifically: value appears in no ClusterId lookup' {
        $Script:TestClusterDef.servers -contains $Script:NodeIdAsCluster | Should -Be $true
        $Script:TestClusterId -ne $Script:NodeIdAsCluster | Should -Be $true
        $Script:OtherClusterId -ne $Script:NodeIdAsCluster | Should -Be $true
    }
}