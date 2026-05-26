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
        ilo_addresses = @{ 'srv-unit-01.corp.local' = '192.168.99.101'; 'srv-unit-02.corp.local' = '192.168.99.102' }
        openview_node_ids = @{}
        schedule      = @{ work_days = @('Mon','Tue','Wed','Thu','Fri'); work_start = '08:00'; work_end = '17:00'; timezone = 'Europe/Dublin' }
        environment   = 'unittest'
    }
    $Script:OtherClusterId  = 'OTHER-CLUSTER'
    $Script:OtherClusterDef = @{
        display_name  = 'Other Cluster'
        servers       = @('srv-other-01.corp.local')
        scom_group    = 'Other SCOM Group'
        ilo_addresses = @{ 'srv-other-01.corp.local' = '192.168.99.201' }
        environment   = 'unittest'
    }
    $Script:NodeIdAsCluster = 'srv-unit-01.corp.local'

    # ---- Config dir ----
    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir)) { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }

    # Write config files
    @{ clusters = @{ $Script:TestClusterId  = $Script:TestClusterDef
                     $Script:OtherClusterId = $Script:OtherClusterDef } } |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'openview_config.json')
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
        It 'Should reject when no cluster schedule defined and no --end [ClusterId=OTHER-CLUSTER]' {
            $params = @{ Action = 'enable'; ClusterId = $Script:OtherClusterId; ConfigDir = $Script:ConfigDir; Start = 'now' }
            Write-TestCommand -Command "Set-MaintenanceMode" -Params $params
            
            $result = Set-MaintenanceMode @params
            
            Write-MaintenanceResult -Result $result -InputParams $params -ExpectedSuccess $false
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'No end time|no schedule|schedule|No end'
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
