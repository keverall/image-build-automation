# Get-OneViewServerTarget.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewServerTarget.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Get-OneViewServerTarget — basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Get-OneViewServerTarget -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Get-OneViewServerTarget
        foreach ($p in @('ServerIdentifier','OneViewHost','IdentifierType','MockResult','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Returns MockResult without network call' {
        $r = Get-OneViewServerTarget -ServerIdentifier 'TEST' -MockResult @{
            Success = $true; Server = 'TEST'; Details = @{ serial_number = 'MXQ0000' }
        }
        $r.Success          | Should -Be $true
        $r.Details.serial_number | Should -Be 'MXQ0000'
    }

    It 'Fails when OneViewHost missing and no MockResult' {
        $r = Get-OneViewServerTarget -ServerIdentifier 'TEST'
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'OneViewHost'
    }

    It 'DryRun succeeds' {
        $r = Get-OneViewServerTarget -OneViewHost 'oneview.test.local' -ServerIdentifier 'TEST' -DryRun
        $r.Success | Should -Be $true
        $r.DryRun  | Should -Be $true
    }

    It 'Rejects unknown IdentifierType' {
        { & Get-OneViewServerTarget -ServerIdentifier 'TEST' -IdentifierType 'Bogus' -ErrorAction SilentlyContinue } |
            Should -Throw
    }
}
