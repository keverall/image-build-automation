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
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','DryRun','ExternalIsoPath')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with everything skipped returns Success' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -GuardRail '.*' -DryRun -PassThru -Quiet `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $true
        $r.server  | Should -Be 'TEST'
        $r.audit_file | Should -Not -Be $null
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -DryRun -PassThru -Quiet `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }
}

Describe 'Start-PhysicalServerBuild - aborts when OneView resolution fails' {
    BeforeAll {
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
            Mock Get-OneViewServerTarget {
                return [hashtable]@{
                    Success = $false
                    Server  = 'alp-qlikview-03ilo'
                    Error   = "No connection to OneView at 'h'. could not reach the appliance (check host, network/VPN, and that OneView is online)."
                }
            }
            # If the orchestrator fails to abort on a bad OneView resolution it would
            # fall through to the guard rail - this throws to prove the abort stops it.
            Mock Assert-GuardRail { throw 'Assert-GuardRail must NOT run when OneView resolution failed' }
        }
    }

    It 'Returns failure and never reaches the guard rail / destructive steps when OneView target resolution fails' {
        $prevAuto = $env:AUTOMATED_MODE
        $env:AUTOMATED_MODE = 'true'
        try {
            $r = Start-PhysicalServerBuild -SrvrId 'alp-qlikview-03ilo' -OneViewHost 'h' -GuardRail '.*' -PassThru -Quiet `
                -ExternalIsoPath 'https://artifacts/isos/win.iso' `
                -SkipPreBuild -SkipMount -SkipMonitor -SkipPostBuild
            $r.Success | Should -Be $false
            $r.error   | Should -Match 'OneView resolution failed'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }
}
