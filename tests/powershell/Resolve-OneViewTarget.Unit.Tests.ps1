# Resolve-OneViewTarget.Unit.Tests.ps1
# Unit tests for the shared serial/name -> OneView target resolver.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Resolve-OneViewTarget - accepts server name or serial number' {
    It 'Is exported from the module' {
        $cmd = Get-Command Resolve-OneViewTarget -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.Parameters.Keys | Should -Contain 'SerialNumber'
        $cmd.Parameters.Keys | Should -Contain 'OneViewHost'
    }

    It 'Passes a server name through unchanged' {
        $r = Resolve-OneViewTarget -ServerName 'srv01.corp.local'
        $r.Success    | Should -Be $true
        $r.Identifier | Should -Be 'srv01.corp.local'
        $r.ResolvedBy | Should -Be 'Name'
    }

    It 'Resolves a serial number to a target via OneView (DryRun)' {
        # In -DryRun the downstream OneView lookup is mocked by Get-OneViewServerTarget
        # itself, so we can verify the resolver normalises the serial into a target.
        $r = Resolve-OneViewTarget -SerialNumber 'MXQ123' -OneViewHost 'oneview.ad.example.com' -DryRun
        $r.Success    | Should -Be $true
        $r.ResolvedBy | Should -Be 'Serial'
        # DryRun OneView stub returns Server = the identifier supplied
        $r.Identifier | Should -Be 'MXQ123'
    }

    It 'Fails when serial supplied without OneViewHost' {
        $r = Resolve-OneViewTarget -SerialNumber 'MXQ123'
        $r.Success | Should -Be $false
        $r.Error | Should -Match 'OneViewHost'
    }

    It 'Fails when neither identifier is supplied' {
        $r = Resolve-OneViewTarget
        $r.Success | Should -Be $false
    }
}
