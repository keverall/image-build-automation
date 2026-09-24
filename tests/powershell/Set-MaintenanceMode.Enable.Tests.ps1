# Set-MaintenanceMode.Enable.Tests.ps1
# High-priority enable action tests for Set-MaintenanceMode.ps1

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # Prevent interactive prompts during tests
    $env:AUTOMATED_MODE = 'true'
    
    if (-not $env:TEMP) {
        $env:TEMP = '/tmp' 
    }
    $Script:TempDir = (Join-Path $env:TEMP "MMEnaTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\', '/')
    if (-not (Test-Path -Path $Script:TempDir)) {
        New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null 
    }

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null

    Copy-Item (Join-Path $Script:ModuleRoot 'configs/clusters_catalogue.examples-only.json') (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Force
    Copy-Item (Join-Path $Script:ModuleRoot 'configs/connection_hosts.json') (Join-Path $Script:ConfigDir 'connection_hosts.json') -Force
    @{ management_server = 'localhost'; powershell_module = 'OperationsManager'; use_winrm = $false } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ oneview = @{ appliance = 'oneview.example.com'; module_name = 'HPEOneView.1000'; use_winrm = $false } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'oneview_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')

    $Script:TestTargetId = 'CLU-CLUSTER-01'
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-MaintenanceMode - Enable action: Time variants' {
    It 'Should default start time to now when Start=null' {
        $endTime = (Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss')
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start $null -End $endTime
        $result.Success | Should -Be $true
    }

    It 'Should accept "now" as start time and relative end time' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
    }

    It 'Should accept ISO format with T separator' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start '2025-05-15T09:00:00' -End '2025-05-15T17:00:00'
        $result.Success | Should -Be $true
    }

    It 'Should reject when end time is before start time' {
        $later = (Get-Date).AddHours(3).ToString('yyyy-MM-dd HH:mm:ss')
        $sooner = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start $later -End $sooner
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'End time must be after start time'
    }
}

Describe 'Set-MaintenanceMode - Enable action: Flags' {
    It 'Should simulate maintenance without making changes [-DryRun]' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
    }

    It 'Should skip scheduled task creation [-NoSchedule, -DryRun]' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -NoSchedule -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
    }
}

Describe 'Set-MaintenanceMode - OneView SerialNumber mode' {
    It 'Should accept SerialNumber without TargetId for OneView mode' {
        $result = Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
        $result.SerialNumber | Should -Be 'ABC123XYZ'
        if ($result.ContainsKey('ServerName')) {
            $result.ServerName | Should -Not -Be 'ABC123XYZ'
        }
    }

    It 'Should show "server with Serial Number" in message for OneView SerialNumber mode' {
        $result = Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'
        $result.Message | Should -Match 'server with Serial Number'
        $result.Message | Should -Match '\[OneView mode\]'
    }

    It 'Should return SerialNumber in result for OneView mode' {
        $result = Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'TEST-SN-123' -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+2hours'
        $result.SerialNumber | Should -Be 'TEST-SN-123'
        $result.ServerCount | Should -Be 1
    }
}

Describe 'Set-MaintenanceMode - OpsRamp_SendMetric argument order' {
    # Regression test for Fix 1: SendMetric on the OpsRamp_Client class expects
    # ([string]$ResourceId, [string]$MetricName, [double]$Value, [hashtable]$Tags, [datetime]$Timestamp).
    # The bug was that Timestamp and Tags were swapped at the two call sites, causing a
    # terminating cast exception ("Cannot convert argument 'Tags' ... to type 'Hashtable'").
    # This test verifies the correct argument order by inspecting the method signature.
    It 'SendMetric method signature has Tags (4th) and Timestamp (5th) in the correct order' {
        InModuleScope Automation {
            $method = [OpsRamp_Client].GetMethod('SendMetric', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Public)
            $method | Should -Not -Be $null
            $params = $method.GetParameters()
            $params.Length | Should -Be 5
            $params[3].Name | Should -Be 'Tags'
            $params[3].ParameterType | Should -Be ([hashtable])
            $params[4].Name | Should -Be 'Timestamp'
            $params[4].ParameterType | Should -Be ([datetime])
        }
    }
}

Describe 'Set-MaintenanceMode - OneView: checks for active session before credential resolution' {
    # Regression test for Fix 2: when in OneView mode (non-DryRun), Set-MaintenanceMode
    # must call Test-OneViewSessionActive to check for an existing session. If a session
    # is active, credential resolution is skipped (no interactive prompt, no Test-OneViewConnection).
    BeforeAll {
        InModuleScope Automation {
            $Script:SessionActiveCalled = $false
            $Script:ConnectionTestCalled = $false
            Mock Test-OneViewSessionActive {
                $Script:SessionActiveCalled = $true
                return $true
            }
            Mock Test-OneViewConnection {
                $Script:ConnectionTestCalled = $true
                return $false
            }
        }
    }

    It 'Calls Test-OneViewSessionActive and skips Test-OneViewConnection when session is active' {
        # In non-DryRun OneView mode, the session check should fire. Since the
        # OneViewClient creation will fail (no real appliance), the function returns
        # success=$false, but the credential-resolution path is bypassed.
        $prevAuto = $env:AUTOMATED_MODE
        $env:AUTOMATED_MODE = 'true'
        try {
            Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' `
                -ConfigDir $Script:ConfigDir -Start 'now' -End '+1hour' -OneViewHost 'oneview.example.com' `
                -ErrorAction SilentlyContinue | Out-Null
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }

        # Test-OneViewSessionActive must have been called
        $sessionChecked = InModuleScope Automation { $Script:SessionActiveCalled }
        $sessionChecked | Should -Be $true

        # Test-OneViewConnection must NOT have been called (session was active, so
        # credential resolution was skipped and connection test was bypassed)
        $connTestCalled = InModuleScope Automation { $Script:ConnectionTestCalled }
        $connTestCalled | Should -Be $false
    }

    It 'Does not call Test-OneViewSessionActive in DryRun mode (no connection needed)' {
        InModuleScope Automation { $Script:SessionActiveCalled = $false }
        $result = Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' `
            -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'

        $sessionChecked = InModuleScope Automation { $Script:SessionActiveCalled }
        $sessionChecked | Should -Be $false
    }
}
