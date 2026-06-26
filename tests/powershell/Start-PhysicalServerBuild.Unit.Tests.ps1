# Start-PhysicalServerBuild.Unit.Tests.ps1
# Mocked unit tests for the end-to-end orchestrator.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Start-PhysicalServerBuild - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Start-PhysicalServerBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Start-PhysicalServerBuild
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','DryRun','Mock')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with everything skipped returns Success' {
        $r = Start-PhysicalServerBuild -ServerIdentifier 'TEST' -DryRun `
            -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $true
        $r.server  | Should -Be 'TEST'
        $r.audit_file | Should -Not -Be $null
    }
}
