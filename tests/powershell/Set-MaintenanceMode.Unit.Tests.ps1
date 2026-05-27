# Set-MaintenanceMode.Unit.Tests.ps1
# Comprehensive unit tests for Set-MaintenanceMode.ps1
#
# Enhanced test output features:
# - Test descriptions include command args and parameters
# - Colored output: Purple for successful responses, Red for failures
# - Detailed maintenance completion messages showing what changed
#
# Test Structure (Jest/Pytest-style):
# - Describe blocks group related tests
# - It blocks contain individual test cases
# - Clear, descriptive test names: "Should <expected> when <condition>"
# - Proper setup/teardown with BeforeAll/AfterAll
# - Boundary and edge case coverage

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $Script:TestRoot  = $PSScriptRoot

    # Import test output helper for colored/detailed output
    Import-Module (Join-Path $PSScriptRoot 'TestOutputHelper.psm1') -Force -ErrorAction SilentlyContinue

    if (-not $env:TEMP)  { $env:TEMP  = '/tmp' }
    if (-not $env:TMP)   { $env:TMP   = '/tmp' }
    $Script:TempDir = (Join-Path $env:TEMP "MMTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir)) { New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null }

    # ---- Sample cluster catalogue ----
    $Script:TestClusterId  = 'UNIT-TEST-CLUSTER'
    $Script:TestClusterDef = @{
        display_name  = 'Unit Test Cluster'
        servers       = @('srv-unit-01.corp.local','srv-unit-02.corp.local')
        scom_group    = 'Unit Test SCOM Group'
        openview_node_ids = @{}
        schedule      = @{ work_days = @('Mon','Tue','Wed','Thu','Fri'); work_start = '08:00'; work_end = '17:00'; timezone = 'Europe/Dublin' }
        environment   = 'unittest'
    }
    $Script:OtherClusterId  = 'OTHER-CLUSTER'
    $Script:OtherClusterDef = @{
        display_name  = 'Other Cluster'
        servers       = @('srv-other-01.corp.local')
        scom_group    = 'Other SCOM Group'
        environment   = 'unittest'
    }
    $Script:NodeIdAsCluster = 'srv-unit-01.corp.local'

    # ---- Config dir ----
    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir)) { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }

    # Write config files using examples-only.json as template
    Copy-Item (Join-Path $Script:ModuleRoot 'configs/clusters_catalogue.examples-only.json') (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Force
    # Use example cluster definitions for tests
    $Script:TestClusterId  = 'PROD-CLUSTER-01'
    $Script:TestClusterDef = $null
    $Script:OtherClusterId = 'STAGING-CLUSTER-01'
    $Script:OtherClusterDef = $null

    @{ management_server = 'localhost'; powershell_module = 'OperationsManager'; use_winrm = $false } |
        ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ openview = @{ method = 'rest'; api = @{ base_url = 'https://openview.example.com/api' } } } |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'openview_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'json_config.json')

    # ---- Log / output dirs ----
    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    if (-not (Test-Path -Path $Script:LogDir))  { New-Item -ItemType Directory $Script:LogDir  -Force | Out-Null }
    if (-not (Test-Path -Path $Script:OutDir))  { New-Item -ItemType Directory $Script:OutDir  -Force | Out-Null }

    # ---- Import module ----
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    
    # Import the Automation module which provides all functions including Set-MaintenanceMode
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}


AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# =============================================================================
# Helper function to format params for test descriptions
# =============================================================================
function Get-TestParamsString {
    param([hashtable]$Params)
    $parts = @()
    foreach ($k in ($Params.Keys | Sort-Object)) {
        $v = $Params[$k]
        if ($v -is [switch]) { 
            if ($v.IsPresent) { $parts += "-$k" }
        } elseif ($null -ne $v -and "$v" -ne "") {
            $displayVal = if ("$v".Length -gt 30) { "$v".Substring(0,27) + "..." } else { "$v" }
            $parts += "-$k '$displayVal'"
        }
    }
    return ($parts -join " ")
}

# =============================================================================
# Cluster ID validation
# =============================================================================

Describe 'Set-MaintenanceMode — Cluster ID validation' {
    Context 'When validating cluster existence' {
        It 'Should return success for valid cluster ID [Action=validate, ClusterId=UNIT-TEST-CLUSTER]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should reject unknown cluster ID [Action=validate, ClusterId=NONEXISTENT-CLUSTER]' {
            $params = @{ Action = 'validate'; ClusterId = 'NONEXISTENT-CLUSTER'; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should reject empty cluster ID string [Action=validate, ClusterId=""]' {
            $params = @{ Action = 'validate'; ClusterId = ''; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            { Set-MaintenanceMode @params } | Should -Throw
            Write-TestResponse -Success $true -ExpectedSuccess $true -Message "Correctly threw exception for empty ClusterId"
        }

        It 'Should reject server hostname as cluster ID [Action=validate, ClusterId=srv-unit-01.corp.local]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:NodeIdAsCluster; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }
    }
}

# =============================================================================
# --action enable: Start time variants
# =============================================================================

Describe 'Set-MaintenanceMode — enable action: Start time variants' {
    Context 'When specifying start time' {
        It 'Should default start time to now when Start=null [Action=enable, Start=$null]' {
            $endTime = (Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = $null; End = $endTime }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $null -End $endTime
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept "now" as start time [Action=enable, Start=now, End=+1hour]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept ISO format with T separator [Start=2025-05-15T09:00:00]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = '2025-05-15T09:00:00'; End = '2025-05-15T17:00:00' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept space-separated format with seconds [Start=2025-05-15 09:00:00]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = '2025-05-15 09:00:00'; End = '2025-05-15 17:00:00' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept space-separated format without seconds [Start=2025-05-15 09:00]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = '2025-05-15 09:00'; End = '2025-05-15 17:00' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --action enable: Relative time parsing
# =============================================================================

Describe 'Set-MaintenanceMode — enable action: Relative time parsing' {
    Context 'When using relative time offsets' {
        It 'Should parse +1hour relative offset [End=+1hour]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse +24hours relative offset [End=+24hours]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+24hours' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse +30minutes relative offset [End=+30minutes]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+30minutes' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse +2days relative offset [End=+2days]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+2days' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse +90seconds relative offset [End=+90seconds]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+90seconds' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse singular form +1hour [End=+1hour]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse singular form +1day [End=+1day]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1day' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse singular form +1minute [End=+1minute]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1minute' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should parse singular form +1second [End=+1second]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1second' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --action enable: End time validation
# =============================================================================

Describe 'Set-MaintenanceMode — enable action: End time validation' {
    Context 'When end time is before start time' {
        It 'Should reject when end time is before start time [End < Start]' {
            $later = (Get-Date).AddHours(3).ToString('yyyy-MM-dd HH:mm:ss')
            $sooner = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Start = $later; End = $sooner }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start $later -End $sooner
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'End time must be after start time'
        }

        It 'Should accept when end equals start plus one second (boundary) [Duration=1s]' {
            $start = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date).AddSeconds(1).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $start -End $end
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When end time format is invalid' {
        It 'Should throw when --start datetime format is invalid [Start=not-a-valid-date]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Start = 'not-a-valid-date' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start 'not-a-valid-date' } | Should -Throw
            Write-TestResponse -Success $true -ExpectedSuccess $true -Message "Correctly threw exception for invalid start date format"
        }

        It 'Should throw when --end datetime format is invalid [End=not-valid-at-all]' {
            $startDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Start = $startDate; End = 'not-valid-at-all' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start $startDate -End 'not-valid-at-all' } | Should -Throw
            Write-TestResponse -Success $true -ExpectedSuccess $true -Message "Correctly threw exception for invalid end date format"
        }

        It 'Should reject dot-separated datetime format [Start=2025-05-15.09.00]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Start = '2025-05-15.09.00'; End = '2025-05-15 17:00' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Start '2025-05-15.09.00' -End '2025-05-15 17:00' } | Should -Throw
            Write-TestResponse -Success $true -ExpectedSuccess $true -Message "Correctly rejected unsupported dot-separated datetime format"
        }
    }
}

# =============================================================================
# --action enable: Schedule and missing end
# =============================================================================

Describe 'Set-MaintenanceMode — enable action: Schedule handling' {
    Context 'When no end time is provided' {
        It 'Should compute end time when no --end provided (uses schedule or defaults to 7am UTC Monday) [ClusterId=OTHER-CLUSTER]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:OtherClusterId; ConfigDir = $Script:ConfigDir; Start = 'now'; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
            $result.EndTimeUtc | Should -Not -BeNullOrEmpty
            $result.EndTimeUtc | Should -BeGreaterThan $result.StartTimeUtc
        }

        It 'Should compute end time from cluster schedule when schedule exists [ClusterId=UNIT-TEST-CLUSTER]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --action enable: DryRun and NoSchedule flags
# =============================================================================

Describe 'Set-MaintenanceMode — enable action: Flags' {
    Context 'When DryRun flag is set' {
        It 'Should simulate maintenance without making changes [-DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When NoSchedule flag is set' {
        It 'Should skip scheduled task creation [-NoSchedule, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; NoSchedule = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --action disable
# =============================================================================

Describe 'Set-MaintenanceMode — disable action' {
    Context 'When disabling maintenance' {
        It 'Should reject with invalid cluster ID [Action=disable, ClusterId=UNKNOWN-CLUSTER]' {
            $params = @{ Action = 'disable'; ClusterId = 'UNKNOWN-CLUSTER'; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should reject when server hostname passed as cluster ID [Action=disable, ClusterId=srv-unit-01]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:NodeIdAsCluster; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should succeed with valid cluster ID in dry-run mode [Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --action validate
# =============================================================================

Describe 'Set-MaintenanceMode — validate action' {
    Context 'When validating cluster configuration' {
        It 'Should exit successfully for a valid cluster [Action=validate, ClusterId=UNIT-TEST-CLUSTER]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should reject with invalid cluster ID [Action=validate, ClusterId=BAD-ID]' {
            $params = @{ Action = 'validate'; ClusterId = 'BAD-ID'; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should reject with server hostname as cluster ID [Action=validate, ClusterId=srv-unit-01]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:NodeIdAsCluster; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }
    }
}

# =============================================================================
# Error handling and negative paths
# =============================================================================

Describe 'Set-MaintenanceMode — error handling' {
    Context 'When cluster ID is invalid' {
        It 'Should return error on enable for non-existent cluster [Action=enable, ClusterId=DOES-NOT-EXIST]' {
            $params = @{ Action = 'enable'; ClusterId = 'DOES-NOT-EXIST'; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should return error on disable for non-existent cluster [Action=disable, ClusterId=DOES-NOT-EXIST]' {
            $params = @{ Action = 'disable'; ClusterId = 'DOES-NOT-EXIST'; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }

        It 'Should return error on enable for node ID used as cluster ID [Action=enable, ClusterId=srv-unit-01]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:NodeIdAsCluster; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }
    }

    Context 'When cluster definition is missing required fields' {
        It 'Should validate cluster with all required fields present [ClusterId=UNIT-TEST-CLUSTER]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true  # Our test cluster is valid
        }
    }
}

# =============================================================================
# Input field variants and edge cases
# =============================================================================

Describe 'Set-MaintenanceMode — input field variants' {
    Context 'When Action parameter varies' {
        It 'Should accept "enable" action (default) [Action=enable, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept "disable" action [Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept "validate" action [Action=validate]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When ConfigDir parameter varies' {
        It 'Should use provided ConfigDir parameter [ConfigDir=<temp>/configs]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When DryRun parameter varies' {
        It 'Should accept -DryRun switch [-DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept -WhatIf as alias for DryRun [-DryRun (WhatIf alias)]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When NoSchedule parameter varies' {
        It 'Should accept -NoSchedule switch [-NoSchedule, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; NoSchedule = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# Boundary tests
# =============================================================================

Describe 'Set-MaintenanceMode — boundary tests' {
    Context 'When crossing day boundaries' {
        It 'Should handle maintenance window crossing midnight [23:00 -> 02:00 next day]' {
            $start = (Get-Date '2025-01-15 23:00:00').ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date '2025-01-16 02:00:00').ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $start -End $end
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should handle long duration maintenance (over 24 hours) [Duration=48h]' {
            $start = (Get-Date '2025-01-15 00:00:00').ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date '2025-01-17 00:00:00').ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $start -End $end
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When using minimum time values' {
        It 'Should handle one-second duration maintenance [Duration=1s]' {
            $start = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date).AddSeconds(1).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -DryRun -Start $start -End $end
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# --mode parameter: Mode variants
# =============================================================================

Describe 'Set-MaintenanceMode — mode parameter: SCOM only mode' {
    Context 'When Mode is set to scom' {
        It 'Should enable SCOM-only maintenance mode [Mode=scom, Action=enable, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should disable SCOM-only maintenance mode [Mode=scom, Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should validate cluster with scom mode [Mode=scom, Action=validate]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Mode = 'scom' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with scom mode and NoSchedule flag [Mode=scom, -NoSchedule, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; NoSchedule = $true; Start = 'now'; End = '+2hours' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with scom mode and explicit time window [Mode=scom, Start/End explicit]' {
            $start = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date).AddHours(4).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with scom mode and relative time [Mode=scom, End=+30minutes]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = 'now'; End = '+30minutes' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should reject unknown cluster with scom mode [Mode=scom, ClusterId=NONEXISTENT]' {
            $params = @{ Action = 'enable'; ClusterId = 'NONEXISTENT'; ConfigDir = $Script:ConfigDir; Mode = 'scom' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }
    }
}

# =============================================================================
# --mode parameter: All mode (SCOM + OpenView)
# =============================================================================

Describe 'Set-MaintenanceMode — mode parameter: All mode (SCOM + OpenView)' {
    Context 'When Mode is set to all (default)' {
        It 'Should enable all-systems maintenance mode by default [Mode=all (default), -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should explicitly enable all-systems maintenance mode [Mode=all, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should disable all-systems maintenance mode [Mode=all, Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should validate cluster with all mode [Mode=all, Action=validate]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; Mode = 'all' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with all mode and NoSchedule [Mode=all, -NoSchedule, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; NoSchedule = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with all mode and schedule-based end time [Mode=all, schedule]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; Start = 'now' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with all mode and explicit time window [Mode=all, Start/End explicit]' {
            $start = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $end = (Get-Date).AddHours(6).ToString('yyyy-MM-dd HH:mm:ss')
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; Start = $start; End = $end }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should reject unknown cluster with all mode [Mode=all, ClusterId=NONEXISTENT]' {
            $params = @{ Action = 'enable'; ClusterId = 'NONEXISTENT'; ConfigDir = $Script:ConfigDir; Mode = 'all' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found in catalogue'
        }
    }
}

# =============================================================================
# --mode parameter: Mode comparison tests
# =============================================================================

Describe 'Set-MaintenanceMode — mode parameter: Comparison between scom and all' {
    Context 'When comparing mode behaviors' {
        It 'Should succeed with scom mode in dry-run [Mode=scom vs Mode=all comparison]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = 'now'; End = '+1hour' }
            $result_scom = Set-MaintenanceMode @params
            
            $params['Mode'] = 'all'
            $result_all = Set-MaintenanceMode @params
            
            $result_scom.Success | Should -Be $true
            $result_all.Success | Should -Be $true
        }

        It 'Should handle same cluster with different modes independently' {
            $scomParams = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = 'now'; End = '+1hour' }
            $allParams  = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; Start = 'now'; End = '+1hour' }
            
            $scomResult = Set-MaintenanceMode @scomParams
            $allResult  = Set-MaintenanceMode @allParams
            
            $scomResult.Success | Should -Be $true
            $allResult.Success | Should -Be $true
            $scomResult.ClusterId | Should -Be $allResult.ClusterId
        }
    }
}

# =============================================================================
# --mode parameter: Negative tests
# =============================================================================

Describe 'Set-MaintenanceMode — mode parameter: Negative and edge cases' {
    Context 'When invalid mode values are provided' {
        It 'Should reject invalid mode value "ilo" [Mode=ilo - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode 'ilo' -Start 'now' -End '+1hour' } | Should -Throw
        }

        It 'Should reject invalid mode value "openview" [Mode=openview - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode 'openview' -Start 'now' -End '+1hour' } | Should -Throw
        }

        It 'Should reject invalid mode value "both" [Mode=both - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode 'both' -Start 'now' -End '+1hour' } | Should -Throw
        }

        It 'Should reject invalid mode value "none" [Mode=none - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode 'none' -Start 'now' -End '+1hour' } | Should -Throw
        }

        It 'Should reject invalid mode value empty string [Mode="" - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode '' -Start 'now' -End '+1hour' } | Should -Throw
        }

        It 'Should reject invalid mode value with typo "scomm" [Mode=scomm - invalid]' {
            { Set-MaintenanceMode -Action enable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -Mode 'scomm' -Start 'now' -End '+1hour' } | Should -Throw
        }
    }

    Context 'When mode is combined with error conditions' {
        It 'Should fail gracefully when scom mode used with invalid cluster [Mode=scom, invalid cluster]' {
            $params = @{ Action = 'enable'; ClusterId = 'INVALID-CLUSTER'; ConfigDir = $Script:ConfigDir; Mode = 'scom' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
        }

        It 'Should fail gracefully when all mode used with invalid cluster [Mode=all, invalid cluster]' {
            $params = @{ Action = 'enable'; ClusterId = 'INVALID-CLUSTER'; ConfigDir = $Script:ConfigDir; Mode = 'all' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
        }

        It 'Should compute default end time when scom mode used with no explicit end [Mode=scom, no end]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:OtherClusterId; ConfigDir = $Script:ConfigDir; Mode = 'scom'; Start = 'now'; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
            $result.EndTimeUtc | Should -Not -BeNullOrEmpty
        }

        It 'Should compute default end time when all mode used with no explicit end [Mode=all, no end]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:OtherClusterId; ConfigDir = $Script:ConfigDir; Mode = 'all'; Start = 'now'; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
            $result.EndTimeUtc | Should -Not -BeNullOrEmpty
        }
    }
}

# =============================================================================
# PostDisableWaitSeconds parameter tests
# =============================================================================

Describe 'Set-MaintenanceMode — PostDisableWaitSeconds parameter' {
    Context 'When disabling maintenance with PostDisableWaitSeconds' {
        It 'Should accept default PostDisableWaitSeconds (120s) on disable [Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept custom PostDisableWaitSeconds value [PostDisableWaitSeconds=60, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept PostDisableWaitSeconds=0 to skip wait [PostDisableWaitSeconds=0, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; PostDisableWaitSeconds = 0 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept large PostDisableWaitSeconds value [PostDisableWaitSeconds=300, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; PostDisableWaitSeconds = 300 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with scom mode and PostDisableWaitSeconds [Mode=scom, PostDisableWaitSeconds=60, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with all mode and PostDisableWaitSeconds [Mode=all, PostDisableWaitSeconds=60, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should work with NoSchedule and PostDisableWaitSeconds [-NoSchedule, PostDisableWaitSeconds=60, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; NoSchedule = $true; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }

    Context 'When PostDisableWaitSeconds has negative values' {
        It 'Should reject negative PostDisableWaitSeconds [PostDisableWaitSeconds=-1]' {
            { Set-MaintenanceMode -Action disable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -PostDisableWaitSeconds -1 } | Should -Throw
        }

        It 'Should reject very large PostDisableWaitSeconds [PostDisableWaitSeconds=99999999]' {
            { Set-MaintenanceMode -Action disable -ClusterId $Script:TestClusterId -ConfigDir $Script:ConfigDir -PostDisableWaitSeconds 99999999 } | Should -Throw
        }
    }

    Context 'When PostDisableWaitSeconds is used with enable action' {
        It 'Should accept PostDisableWaitSeconds with enable (no-op but valid) [Action=enable, PostDisableWaitSeconds=60, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour'; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }

        It 'Should accept PostDisableWaitSeconds with validate action (no-op but valid) [Action=validate, PostDisableWaitSeconds=60]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; PostDisableWaitSeconds = 60 }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
        }
    }
}

# =============================================================================
# Per-Object Status Reporting tests
# =============================================================================

Describe 'Set-MaintenanceMode — per-object status reporting' {
    Context 'When enable action is executed (DryRun)' {
        It 'Should return ScomObjects field as array in response [Action=enable, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
            $result.Keys | Should -Contain 'ScomObjects'
            $result.ScomObjects -is [array] | Should -Be $true
        }

        It 'Should return ScomSummary object with expected fields [Action=enable, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            
            $result = Set-MaintenanceMode @params
            
            $result.Keys | Should -Contain 'ScomSummary'
            $result.ScomSummary -is [hashtable] | Should -Be $true
        }

        It 'Should return FailedObjects field as array in response [Action=enable, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Start = 'now'; End = '+1hour' }
            
            $result = Set-MaintenanceMode @params
            
            $result.Keys | Should -Contain 'FailedObjects'
            $result.FailedObjects -is [array] | Should -Be $true
        }
    }

    Context 'When disable action is executed (DryRun)' {
        It 'Should return ScomObjects field as array in response [Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $true
            $result.Success | Should -Be $true
            $result.Keys | Should -Contain 'ScomObjects'
        }

        It 'Should return ScomSummary with expected fields for disable [Action=disable, -DryRun]' {
            $params = @{ Action = 'disable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true }
            
            $result = Set-MaintenanceMode @params
            
            $result.Keys | Should -Contain 'ScomSummary'
        }
    }

    Context 'When validate action is executed' {
        It 'Should return ScomObjects field for validate [Action=validate]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            
            $result = Set-MaintenanceMode @params
            
            $result.Keys | Should -Contain 'ScomObjects'
            $result.ScomObjects.Count | Should -Be 0
        }

        It 'Should return FailedObjects field for validate [Action=validate]' {
            $params = @{ Action = 'validate'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir }
            
            $result = Set-MaintenanceMode @params
            
            $result.Keys | Should -Contain 'FailedObjects'
            $result.FailedObjects.Count | Should -Be 0
        }
    }

    Context 'When mode parameter varies (DryRun)' {
        It 'Should return per-object status fields with scom mode [Mode=scom, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'scom'; Start = 'now'; End = '+1hour' }
            
            $result = Set-MaintenanceMode @params
            
            $result.Success | Should -Be $true
            $result.Keys | Should -Contain 'ScomObjects'
            $result.Keys | Should -Contain 'ScomSummary'
            $result.Keys | Should -Contain 'FailedObjects'
        }

        It 'Should return per-object status fields with all mode [Mode=all, -DryRun]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:TestClusterId; ConfigDir = $Script:ConfigDir; DryRun = $true; Mode = 'all'; Start = 'now'; End = '+1hour' }
            
            $result = Set-MaintenanceMode @params
            
            $result.Success | Should -Be $true
            $result.Keys | Should -Contain 'ScomObjects'
            $result.Keys | Should -Contain 'ScomSummary'
            $result.Keys | Should -Contain 'FailedObjects'
        }
    }
}
