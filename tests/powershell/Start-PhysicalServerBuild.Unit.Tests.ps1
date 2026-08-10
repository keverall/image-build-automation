# Start-PhysicalServerBuild.Unit.Tests.ps1
# Mocked unit tests for the end-to-end orchestrator.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Start-PhysicalServerBuild - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Start-PhysicalServerBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Start-PhysicalServerBuild
        foreach ($p in @('SrvrId','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','DryRun','Mock')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with everything skipped returns Success' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -GuardRail '.*' -DryRun `
            -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $true
        $r.server  | Should -Be 'TEST'
        $r.audit_file | Should -Not -Be $null
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -DryRun `
            -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }
}
