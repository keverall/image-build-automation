# Set-MaintenanceMode.Enable.Tests.ps1
# High-priority enable action tests for Set-MaintenanceMode.ps1

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    if (-not $env:TEMP) { $env:TEMP = '/tmp' }
    $Script:TempDir = (Join-Path $env:TEMP "MMEnaTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir)) { New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null }

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null

    Copy-Item (Join-Path $Script:ModuleRoot 'configs/clusters_catalogue.examples-only.json') (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Force
    @{ management_server = 'localhost'; powershell_module = 'OperationsManager'; use_winrm = $false } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ oneview = @{ appliance = 'oneview.example.com'; module_name = 'HPOneView.Managed'; use_winrm = $false } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'oneview_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')

    $Script:TestTargetId = 'PROD-CLUSTER-01'
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-MaintenanceMode — Enable action: Time variants' {
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
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -Start $later -End $sooner
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'End time must be after start time'
    }
}

Describe 'Set-MaintenanceMode — Enable action: Flags' {
    It 'Should simulate maintenance without making changes [-DryRun]' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
    }

    It 'Should skip scheduled task creation [-NoSchedule, -DryRun]' {
        $result = Set-MaintenanceMode -Action enable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -NoSchedule -Start 'now' -End '+1hour'
        $result.Success | Should -Be $true
    }
}
