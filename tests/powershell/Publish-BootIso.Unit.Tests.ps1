# Publish-BootIso.Unit.Tests.ps1
# Mocked unit tests for the Publish-BootIso function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Publish-BootIso — basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Publish-BootIso -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Publish-BootIso
        foreach ($p in @('IsoPath','RepoBaseUrl','RepoLocalPath','SkipVerify','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Fails when IsoPath does not exist' {
        $r = Publish-BootIso -IsoPath '/tmp/nonexistent.iso' -RepoBaseUrl 'https://example.com/isos/'
        $r.Success | Should -Be $false
        $r.Error    | Should -Match 'not found'
    }

    It 'Fails when RepoBaseUrl not provided and no env var' {
        $tmpIso = Join-Path ([System.IO.Path]::GetTempPath()) "test_$(Get-Random).iso"
        Set-Content -Path $tmpIso -Value 'MOCKISO' -Encoding UTF8
        $env:ISO_REPO_BASE_URL = $null
        try {
            $r = Publish-BootIso -IsoPath $tmpIso
            $r.Success | Should -Be $false
            $r.Error    | Should -Match 'RepoBaseUrl'
        } finally { Remove-Item $tmpIso -Force -ErrorAction SilentlyContinue }
    }

    It 'DryRun succeeds without copying' {
        $tmpIso = Join-Path ([System.IO.Path]::GetTempPath()) "test_$(Get-Random).iso"
        Set-Content -Path $tmpIso -Value 'MOCKISO' -Encoding UTF8
        try {
            $r = Publish-BootIso -IsoPath $tmpIso -RepoBaseUrl 'https://example.com/isos/' -DryRun
            $r.Success  | Should -Be $true
            $r.DryRun   | Should -Be $true
            $r.PublicUrl | Should -Match 'test_'
        } finally { Remove-Item $tmpIso -Force -ErrorAction SilentlyContinue }
    }
}
