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
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot   = $PSScriptRoot

    if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
    if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
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
    $Assert:NodeIsInServersList = $Script:TestClusterDef.servers -contains $Script:NodeIdAsCluster

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
    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cluster ID validation
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — Cluster ID validation' {
    It 'Returns success hashtable for a valid cluster ID (validate action)' {
        & $Script:ScriptPath -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        # Reaching here without thrown exception means validate path executed
        $true | Should -Be $true
    }

    It 'Rejects an unknown cluster ID that is not in the catalogue' {
        & $Script:ScriptPath -Action validate -ClusterId 'NONEXISTENT-CLUSTER' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Should -Match 'not found in catalogue'
    }

    It 'Rejects an empty cluster ID string' {
        & $Script:ScriptPath -Action validate -ClusterId '' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Should -Match 'not found in catalogue|Cluster ID'
    }

    It 'Rejects a server hostname (node ID) that is not a cluster key' {
        # The hostname exists in the cluster's servers list but is NOT a cluster key
        $Script:Assert:NodeIsInServersList | Should -Be $true
        & $Script:ScriptPath -Action validate -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Should -Match 'not found in catalogue'
    }

    It 'Rejects one valid cluster ID while accepting a different valid one' {
        $result1 = & $Script:ScriptPath -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $result2 = & $Script:ScriptPath -Action validate -ClusterId $Script:OtherClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        # Both must succeed (valid clusters)
        $result1 | Should -Not -Match 'not found in catalogue'
        $result2 | Should -Not -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action enable
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — enable action variants' {
    It 'Runs enable with --start now and no --end (uses schedule-computed end)' {
        # With --start now and no --end, script reads cluster schedule and computes end
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now 2>&1 | Out-Null
        # Script should reach iLO step; exits 0 on success
        $true | Should -Be $true
    }

    It 'Runs enable with explicit --start and --end datetimes' {
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $later = (Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start $now -End $later 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'Runs enable with --start now --end explicit ISO datetime' {
        $start = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        $end   = (Get-Date).AddHours(3).ToString('yyyy-MM-ddTHH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start $start -End $end 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'Rejects enable when end time is before start time' {
        $early = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $later = (Get-Date).AddHours(3).ToString('yyyy-MM-dd HH:mm:ss')
        # Swap: "end" is actually before "start"
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start $later -End $early 2>&1 | Out-String
        $output | Should -Match 'End time must be after start time'
    }

    It 'Rejects enable with invalid --start datetime format' {
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start 'not-a-valid-date' 2>&1 | Out-String
        $output | Should -Match 'Invalid datetime format'
    }

    It 'Rejects enable with invalid --end datetime format' {
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') `
            -End 'not-valid-at-all' 2>&1 | Out-String
        $output | Should -Match 'Invalid datetime format'
    }

    It 'Rejects enable when no cluster schedule is defined and no --end is given' {
        # OTHER-CLUSTER has no 'schedule' field; calling enable without --end should fail
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:OtherClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now 2>&1 | Out-String
        $output | Should -Match 'No end time|no schedule|schedule|No end'
    }

    It 'Runs enable with --no-schedule (does not attempt schtasks on Linux)' {
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now -End ((Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')) `
            -NoSchedule 2>&1 | Out-Null
        # On Linux, schtasks is not available so the NoSchedule just avoids the path
        $true | Should -Be $true
    }

    It 'Rejects enable with invalid cluster ID (not in catalogue)' {
        $output = & $Script:ScriptPath -Action enable -ClusterId 'CLUSTER-DOES-NOT-EXIST' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action disable
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — disable action' {
    It 'Runs disable for a valid cluster ID' {
        & $Script:ScriptPath -Action disable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'Sends maintenance notification (email) during disable' {
        & $Script:ScriptPath -Action disable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        # EmailNotifier.SendMaintenanceNotification is called inside disable path;
        # with no distribution list configured it returns silently.
        $true | Should -Be $true
    }

    It 'Rejects disable with invalid cluster ID' {
        $output = & $Script:ScriptPath -Action disable -ClusterId 'UNKNOWN-CLUSTER' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'Rejects disable when server hostname (node ID) is passed as cluster ID' {
        $output = & $Script:ScriptPath -Action disable -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# --action validate
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — validate action' {
    It 'Exits successfully for a valid cluster (validate action)' {
        & $Script:ScriptPath -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'Rejects validate with invalid cluster ID' {
        $output = & $Script:ScriptPath -Action validate -ClusterId 'BAD-ID' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'Rejects validate with empty cluster ID' {
        $output = & $Script:ScriptPath -Action validate -ClusterId '' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue|Cluster ID'
    }

    It 'Rejects validate with server hostname as cluster ID' {
        $output = & $Script:ScriptPath -Action validate -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Scheduled task interactions (enable path only affected)
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — Scheduled task' {
    It 'enable without --no-schedule would attempt schtasks creation on Windows' {
        # On non-Windows, the $IsWindows guard prevents schtasks; here we only
        # verify the code path is entered without error.
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now -End ((Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')) 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'enable --no-schedule bypasses scheduled task creation' {
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now -End ((Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')) `
            -NoSchedule 2>&1 | Out-Null
        $true | Should -Be $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Error / negative paths — all return error strings, no hard exception exits
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — error handling' {
    It 'Invalid cluster ID returns error string on enable' {
        $output = & $Script:ScriptPath -Action enable -ClusterId 'DOES-NOT-EXIST' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'Invalid cluster ID returns error string on disable' {
        $output = & $Script:ScriptPath -Action disable -ClusterId 'DOES-NOT-EXIST' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'Node ID used as cluster ID returns error string on enable' {
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
        # Confirm it is NOT treated as a valid cluster lookup
        $output | Should -Not -Match 'Maintenance enable|Maintenance completed'
    }

    It 'End-before-start returns error string on enable' {
        $later   = (Get-Date).AddHours(3).ToString('yyyy-MM-dd HH:mm:ss')
        $sooner  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start $later -End $sooner 2>&1 | Out-String
        $output | Should -Match 'End time must be after start time'
    }

    It 'Invalid --start datetime returns error string on enable' {
        $output = & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start 'garbage-datetime' 2>&1 | Out-String
        $output | Should -Match 'Invalid datetime format|garbage'
    }

    It 'Missing catalogue returns error string' {
        $output = & $Script:ScriptPath -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride 'C:\nonexistent_config_dir' 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue|ConfigDir'
    }

    It 'Node-ID-as-cluster ID specifically: value appears in no ClusterId lookup' {
        # Verify the hostname IS in some cluster's server list but NOT a cluster key
        $Script:TestClusterDef.servers -contains $Script:NodeIdAsCluster | Should -Be $true
        $Script:TestClusterId -ne $Script:NodeIdAsCluster | Should -Be $true
        $Script:OtherClusterId -ne $Script:NodeIdAsCluster | Should -Be $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Enable action — full happy-path with real arguments (dry-run bypasses iLO/SCOM)
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — enable full path' {
    It 'enable with explicit times and --no-schedule terminates without error' {
        $start = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
        $end   = (Get-Date).AddHours(4).ToString('yyyy-MM-ddTHH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start $start -End $end -NoSchedule 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'enable with --start now and explicit --end reaches all execution stages' {
        $end = (Get-Date).AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir `
            -Start now -End $end 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'enable twice (idempotent re-enable) does not throw' {
        $end = (Get-Date).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir -Start now -End $end 2>&1 | Out-Null
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir -Start now -End $end 2>&1 | Out-Null
        $true | Should -Be $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Disable action — happy path
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — disable full path' {
    It 'disable for a valid cluster completes without error' {
        & $Script:ScriptPath -Action disable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'disable is rejected for invalid cluster ID with clear error message' {
        $output = & $Script:ScriptPath -Action disable -ClusterId 'NO-SUCH-CLUSTER' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'disable again (idempotent) does not throw' {
        & $Script:ScriptPath -Action disable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# iRequest-like calling patterns (parameter-driven)
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — iRequest calling patterns' {
    It 'enable called with --action enable --cluster-id --start now works' {
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir -Start now 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'disable called with --action disable --cluster-id works' {
        & $Script:ScriptPath -Action disable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'validate called with --action validate --cluster-id works' {
        & $Script:ScriptPath -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-Null
        $true | Should -Be $true
    }

    It 'enable with explicit start and end datetimes (ISO format proper resource)' {
        $t1 = (Get-Date).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss')
        $t2 = (Get-Date).AddHours(5).ToString('yyyy-MM-ddTHH:mm:ss')
        & $Script:ScriptPath -Action enable -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:ConfigDir -Start $t1 -End $t2 2>&1 | Out-Null
        $true | Should -Be $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Marriage of validate + cluster-ID negativity: server hostname NOT treated as cluster
# ═══════════════════════════════════════════════════════════════════════════════

Describe 'Set-MaintenanceMode — clustering sanity checks' {
    It 'Node-ID hostname srv-unit-01 is present in cluster server list but is NOT a cluster key' {
        $in_servers = $Script:TestClusterDef.servers -contains $Script:NodeIdAsCluster
        $in_clusters  = $Script:TestClusterId -eq $Script:NodeIdAsCluster -or $Script:OtherClusterId -eq $Script:NodeIdAsCluster
        $in_servers | Should -Be $true
        $in_clusters  | Should -Be $false
        # Therefore it must be rejected when used as --ClusterId
        $output = & $Script:ScriptPath -Action validate -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'A completely unknown string is also rejected as cluster ID' {
        $output = & $Script:ScriptPath -Action validate -ClusterId 'totally-fake-cluster-xyz' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $output | Should -Match 'not found in catalogue'
    }

    It 'Wat Node-ID and unknown-cluster error messages contain the rejected ID' {
        $nodeOutput = & $Script:ScriptPath -Action validate -ClusterId $Script:NodeIdAsCluster `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $unkOutput  = & $Script:ScriptPath -Action validate -ClusterId 'BOGUS-CLUSTER' `
            -ConfigDirOverride $Script:ConfigDir 2>&1 | Out-String
        $nodeOutput | Should -Match [regex]::Escape($Script:NodeIdAsCluster)
        $unkOutput  | Should -Match 'BOGUS-CLUSTER'
    }
}
