# New-ScomMaintenanceScript.Unit.Tests.ps1
# Updated tests for New-ScomMaintenanceScript with EndTime/Reason parameters
# and new cluster-aware mode (server-hostname loop + Microsoft.Windows.Cluster).

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'New-ScomMaintenanceScript — parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts EndTimeStr parameter' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'EndTimeStr'
    }

    It 'Accepts Reason parameter with default PlannedOther' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'Reason'
    }

    It 'Accepts ServerHostnames parameter' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'ServerHostnames'
    }

    It 'Accepts UseClusterMode switch parameter' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters['UseClusterMode'] | Should -Not -Be $null
        $cmd.Parameters['UseClusterMode'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Should -Be $null
    }

    It 'DurationSeconds parameter is removed' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Not -Contain 'DurationSeconds'
    }

    It 'Accepts GroupDisplayName, Comment, Operation as before' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'GroupDisplayName'
        $cmd.Parameters.Keys | Should -Contain 'Comment'
        $cmd.Parameters.Keys | Should -Contain 'Operation'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & New-ScomMaintenanceScript -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}

Describe 'New-ScomMaintenanceScript — Group mode script output' {
    It 'Generates a start script with the correct end time and comment for Group mode' {
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'TEST_GROUP' `
            -EndTimeStr '2026-05-22T06:00:00' -Reason 'PlannedOther' -Comment 'test maintenance'
        $ps | Should -Match 'TEST_GROUP'
        $ps | Should -Match '2026-05-22T06:00:00'
        $ps | Should -Match 'test maintenance'
        $ps | Should -Match 'ScheduleMaintenanceMode'
    }

    It 'Generates a stop script for Group mode' {
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'TEST_GROUP' `
            -EndTimeStr '2026-05-22T06:00:00' -Reason 'PlannedOther' -Comment 'test' -Operation 'stop'
        $ps | Should -Match 'StopMaintenanceMode'
    }

    It 'Default Reason is PlannedOther when not supplied' {
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'G' `
            -EndTimeStr '2026-05-22T06:00:00' -Comment 'c'
        $ps | Should -Match 'PlannedOther'
    }

    It 'Custom Reason is emitted into the script' {
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'G' `
            -EndTimeStr '2026-05-22T06:00:00' -Reason 'PlannedApplicationInstallation' -Comment 'c'
        $ps | Should -Match 'PlannedApplicationInstallation'
    }

    It 'Quotes in comments are escaped' {
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'G' `
            -EndTimeStr '2026-05-22T06:00:00' -Comment "O'Reilly Patch"
        $ps | Should -Match "O''Reilly Patch"
    }
}

Describe 'New-ScomMaintenanceScript — Cluster mode script output' {
    It 'Generates a cluster start script with agent/cluster detection blocking' {
        $ps = New-ScomMaintenanceScript -EndTimeStr '2026-05-22T06:00:00' `
            -Reason 'PlannedOther' -Comment 'cluster test' `
            -ServerHostnames @('srv01.corp.local','srv02.corp.local') -UseClusterMode
        $ps | Should -Match 'Microsoft\.Windows\.Cluster'
        $ps | Should -Match 'GetRelatedMonitoringObjects'
        $ps | Should -Match 'Recursive'
        $ps | Should -Match 'srv01\.corp\.local'
        $ps | Should -Match 'srv02\.corp\.local'
        $ps | Should -Match 'ScheduleMaintenanceMode'
    }

    It 'Generates a cluster stop script with cluster node maintenance stopping' {
        $ps = New-ScomMaintenanceScript -EndTimeStr '2026-05-22T06:00:00' `
            -Reason 'PlannedOther' -Comment 'cluster test' `
            -ServerHostnames @('srv01.corp.local') -UseClusterMode -Operation 'stop'
        $ps | Should -Match 'Microsoft\.Windows\.Cluster'
        $ps | Should -Match 'StopMaintenanceMode'
    }

    It 'Embeds all server hostnames in the generated script' {
        $servers = @('alpha.corp.local','beta.corp.local','gamma.corp.local')
        $ps = New-ScomMaintenanceScript -EndTimeStr '2026-05-22T06:00:00' `
            -Reason 'PlannedOther' -Comment 'c' -ServerHostnames $servers -UseClusterMode
        foreach ($s in $servers) {
            $escaped = [regex]::Escape($s)
            $ps -match $escaped | Should -Be $true
        }
    }

    It 'Cluster script handles both cluster-managed and standalone agents' {
        $ps = New-ScomMaintenanceScript -EndTimeStr '2026-05-22T06:00:00' `
            -Reason 'PlannedOther' -Comment 'c' `
            -ServerHostnames @('standalone.corp.local') -UseClusterMode
        $ps | Should -Match 'Standalone server'
        $ps | Should -Match 'Cluster'
    }

    It 'Cluster script uses PlannedOther as default reason' {
        $ps = New-ScomMaintenanceScript -EndTimeStr '2026-05-22T06:00:00' `
            -Comment 'c' -ServerHostnames @('x.corp.local') -UseClusterMode
        $ps | Should -Match 'PlannedOther'
    }
}
