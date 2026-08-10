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
        foreach ($p in @('SrvrId','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','ExternalIsoPath','FirmwareFolders',
                         'FirmwareConfig','SkipConfirmation','InMaintenanceWindow','Force')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with SkipPreBuild and SkipConfirmation returns Success and server identity' {
        $r = Configure-PhysicalBuild -SrvrId 'TEST' -GuardRail '.*' -SkipPreBuild -SkipConfirmation -SkipOneView
        $r.Success | Should -Be $true
        $r.Server | Should -Be 'TEST'
    }

    It 'Returns firmware folder details when supplied' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' -FirmwareFolders @('C:\fw1','C:\fw2') `
            -SkipPreBuild -SkipOneView -SkipConfirmation
        $r.FirmwareFolders | Should -Be @('C:\fw1','C:\fw2')
    }

    It 'Resolves external ISO URL when -ExternalIsoPath is an HTTPS URL' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -SkipConfirmation
        $r.IsoUrl | Should -Be 'https://artifacts/isos/win.iso'
    }

    It 'Sets cancelled=true when operator does not confirm (non-SkipConfirmation)' {
        # AUTOMATED_MODE prevents interactive prompt
        $env:AUTOMATED_MODE = 'true'
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -GuardRail '.*' -SkipPreBuild -SkipOneView
        $env:AUTOMATED_MODE = $null
        $r.Cancelled | Should -Be $true
        $r.Success | Should -Be $false
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = Configure-PhysicalBuild -SrvrId 'srv01' -SkipPreBuild -SkipOneView -SkipConfirmation
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }
}
