#
# AutomationCommandLogging.Unit.Tests.ps1 - Validates that every automation
# command which should log is actually wired to the centralized logging
# subsystem (Initialize-Logging / Get-Logger) and that commands produce real
# log files.
#
# Coverage:
#   * Wiring (source-level): each known logging command calls
#     `Initialize-Logging -LogFile` so a regression that drops logging is caught.
#   * Functional: Test-ServerConnectivity writes a real connectivity log file;
#     the in-function logging commands (New-IsoBuild, Update-Firmware,
#     Update-WindowsSecurity) are shown to call Initialize-Logging with the
#     expected log file name at runtime.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    $Script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $Script:PublicDir  = Join-Path $Script:ModuleRoot 'Automation\Public'
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

# Automation commands that must initialise logging (with their expected log file).
$Script:LoggingCommands = @(
    @{ Name = 'Set-MaintenanceMode';     File = 'Set-MaintenanceMode.ps1';     LogFile = 'maintenance.log' }
    @{ Name = 'New-IsoBuild';            File = 'New-IsoBuild.ps1';            LogFile = 'iso_build.log' }
    @{ Name = 'Start-InstallMonitor';    File = 'Start-InstallMonitor.ps1';    LogFile = 'monitoring.log' }
    @{ Name = 'Update-Firmware';         File = 'Update-Firmware.ps1';         LogFile = 'firmware_updater.log' }
    @{ Name = 'Update-WindowsSecurity';  File = 'Update-WindowsSecurity.ps1';  LogFile = 'windows_patcher.log' }
    @{ Name = 'Test-ServerConnectivity'; File = 'Test-ServerConnectivity.ps1'; LogFile = 'connectivity.log' }
)

Describe 'Every automation command that should log is wired to Initialize-Logging' {

    It "calls Initialize-Logging with a LogFile" -ForEach $Script:LoggingCommands {
        $path = Join-Path $Script:PublicDir $_.File
        $content = Get-Content -Path $path -Raw
        $content | Should -Match "Initialize-Logging\s+-LogFile"
    }
}

Describe 'Logging is functional: commands initialise and write logs' {

    It 'Test-ServerConnectivity writes a real connectivity log file (DryRun)' {
        $logDirs = @(
            (Join-Path $Script:RepoRoot 'generated/logs/testing'),
            (Join-Path $Script:RepoRoot 'generated/logs/production'),
            (Join-Path $Script:RepoRoot 'generated/logs/commands/Test-ServerConnectivity')
        )
        $before = foreach ($d in $logDirs) {
            if (Test-Path $d) { Get-ChildItem $d -Filter 'Test-ServerConnectivity*.log' -ErrorAction SilentlyContinue }
        }
        Test-ServerConnectivity -ManagementHost 'test-ov.local' -DryRun
        $after = foreach ($d in $logDirs) {
            if (Test-Path $d) { Get-ChildItem $d -Filter 'Test-ServerConnectivity*.log' -ErrorAction SilentlyContinue }
        }
        $new = $after | Where-Object { $_.FullName -notin ($before.FullName) }
        $new.Count | Should -BeGreaterThan 0
        $content = Get-Content $new[0].FullName
        ($content | Where-Object { $_ -match 'Connectivity test for' }) | Should -Not -BeNullOrEmpty
    }

    It 'New-IsoBuild initialises logging with iso_build.log' {
        $rec = InModuleScope Automation {
            $script:_logCalls = [System.Collections.ArrayList]::new()
            Mock Initialize-Logging -MockWith { $script:_logCalls.Add([PSCustomObject]@{ File = $LogFile; Level = $Level }) | Out-Null }
            try { New-IsoBuild -SiteCode 'ABC' -ManagementPoint 'mp' -DistributionPoint 'dp' -DryRun } catch { }
            ,$script:_logCalls
        }
        ($rec | Where-Object { $_.File -eq 'iso_build.log' }) | Should -Not -BeNullOrEmpty
    }

    It 'Update-Firmware initialises logging with firmware_updater.log' {
        $rec = InModuleScope Automation {
            $script:_logCalls = [System.Collections.ArrayList]::new()
            Mock Initialize-Logging -MockWith { $script:_logCalls.Add([PSCustomObject]@{ File = $LogFile; Level = $Level }) | Out-Null }
            try { Update-Firmware -Server 'srv1' -DryRun } catch { }
            ,$script:_logCalls
        }
        ($rec | Where-Object { $_.File -eq 'firmware_updater.log' }) | Should -Not -BeNullOrEmpty
    }

    It 'Update-WindowsSecurity initialises logging with windows_patcher.log' {
        $rec = InModuleScope Automation {
            $script:_logCalls = [System.Collections.ArrayList]::new()
            Mock Initialize-Logging -MockWith { $script:_logCalls.Add([PSCustomObject]@{ File = $LogFile; Level = $Level }) | Out-Null }
            try { Invoke-WindowsSecurityUpdate -BaseIsoPath 'x' -Server 'srv1' -DryRun } catch { }
            ,$script:_logCalls
        }
        ($rec | Where-Object { $_.File -eq 'windows_patcher.log' }) | Should -Not -BeNullOrEmpty
    }
}
