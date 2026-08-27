# Configure-PhysicalBuild.Unit.Tests.ps1
# Mocked unit tests for the build configuration review / 4-eye validation command.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Configure-PhysicalBuild - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Configure-PhysicalBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Configure-PhysicalBuild
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','ExternalIsoPath',
                         'InMaintenanceWindow','Force','Deploy','GuardRail')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with SkipPreBuild returns Success and server identity' {
        $r = Configure-PhysicalBuild -SrvrId 'TEST' -GuardRail '.*' -SkipPreBuild -SkipOneView -DryRun -PassThru
        $r.Success | Should -Be $true
        $r.Server | Should -Be 'TEST'
    }

    It 'Resolves external ISO URL when -ExternalIsoPath is an HTTPS URL' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -DryRun -PassThru
        $r.IsoUrl | Should -Be 'https://artifacts/isos/win.iso'
    }

    It 'Resolves single-slash UNC external ISO path (/server/share) gracefully' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' `
            -ExternalIsoPath '/fileserver/share/win.iso' `
            -SkipPreBuild -SkipOneView -DryRun -PassThru
        $r.Success | Should -Be $true
        $r.IsoUrl  | Should -Be 'cifs://fileserver/share/win.iso'
    }

    It 'Returns a graceful error when -ExternalIsoPath is a local path' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' `
            -ExternalIsoPath 'C:\local\win.iso' `
            -SkipPreBuild -SkipOneView -DryRun -PassThru
        $r.Success | Should -Be $false
        $r.Reason  | Should -Match 'Failed to resolve'
    }

    It 'Sets cancelled=true when operator does not confirm (non-interactive)' {
        # AUTOMATED_MODE prevents interactive prompt
        $env:AUTOMATED_MODE = 'true'
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' -SkipPreBuild -SkipOneView -PassThru
        $env:AUTOMATED_MODE = $null
        $r.Cancelled | Should -Be $true
        $r.Success | Should -Be $false
    }

    It 'Deploys immediately when -Deploy is passed (non-interactive authorization)' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -Deploy -PassThru
        $r.Success | Should -Be $true
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -SkipPreBuild -SkipOneView -DryRun -PassThru
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }
}

Describe 'Configure-PhysicalBuild - aborts when OneView resolution fails' {
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
            # If the command fails to abort on a bad OneView resolution it would fall
            # through to the guard rail - this throws to prove the abort actually stops it.
            Mock Assert-GuardRail { throw 'Assert-GuardRail must NOT run when OneView resolution failed' }
        }
        $env:AUTOMATED_MODE = 'true'
    }
    AfterAll { $env:AUTOMATED_MODE = $null }

    It 'Returns failure and never reaches the guard rail / deploy plan when OneView target resolution fails' {
        $r = Configure-PhysicalBuild -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'h' -GuardRail '.*' -PassThru
        $r.Success       | Should -Be $false
        $r.ServerIdentity | Should -BeNullOrEmpty
    }
}
