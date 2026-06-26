# New-IsoBuild.Unit.Tests.ps1
# Dedicated unit tests for the New-IsoBuild public function (ConfigMgr rewrite).

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'New-IsoBuild - basic invocation and parameter validation' {
    It 'Function is exported and has expected parameters' {
        $cmd = Get-Command New-IsoBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        foreach ($p in @('SiteCode','ManagementPoint','DistributionPoint','BootImageName','OutputPath','DryRun','MockIsoPath')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun returns Success without ConfigMgr call' {
        $r = New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp.test' -DistributionPoint 'dp.test' -DryRun
        $r.Success | Should -Be $true
        $r.DryRun  | Should -Be $true
        $r.IsoPath | Should -Match 'WinSrv2025_HPE_BootableMedia_v\d+\.\d+\.iso$'
    }

    It 'MockIsoPath copies placeholder ISO without ConfigMgr call' {
        $tmpSrc = Join-Path ([System.IO.Path]::GetTempPath()) "mock_src_$(Get-Random).iso"
        Set-Content -Path $tmpSrc -Value 'MOCK' -Encoding UTF8
        $tmpDst = Join-Path ([System.IO.Path]::GetTempPath()) "mock_dst_$(Get-Random).iso"
        try {
            $r = New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp.test' -DistributionPoint 'dp.test' `
                -MockIsoPath $tmpSrc -OutputPath $tmpDst
            $r.Success | Should -Be $true
            $r.Mocked  | Should -Be $true
            Test-Path $tmpDst | Should -Be $true
            Get-Content (Join-Path (Split-Path $tmpDst -Parent) 'deployment_metadata.json') -Raw |
                Should -Match 'bootable_iso'
        } finally {
            Remove-Item $tmpSrc,$tmpDst -Force -ErrorAction SilentlyContinue
        }
    }
}
