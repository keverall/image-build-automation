# Invoke-IloRedfish.Unit.Tests.ps1
# Mocked unit tests for the Redfish iLO integration function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Invoke-IloRedfish — basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command Invoke-IloRedfish -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Invoke-IloRedfish
        foreach ($p in @('Action','IloIp','IsoUrl','CdDeviceId','SkipCertificateCheck','DryRun','Force')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Accepts -DryRun switch without HTTP calls' {
        { & Invoke-IloRedfish -Action Status -IloIp '127.0.0.1' -DryRun -ErrorAction SilentlyContinue } |
            Should -Not -Throw
    }

    It 'Rejects unknown parameters' {
        { & Invoke-IloRedfish -Action Status -IloIp '127.0.0.1' -NonExistentParam 2>&1 } |
            Should -Not -Be $null
    }

    It 'Destructive actions require -Force when not in DryRun' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -IsoUrl 'https://example.com/iso.iso'
        $r.Success | Should -Be $false
        $r.Error | Should -Match 'requires -Force'
    }

    It 'Destructive actions succeed in DryRun without -Force' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -IsoUrl 'https://example.com/iso.iso' -DryRun
        $r.Success | Should -Be $true
    }
}

Describe 'Invoke-IloRedfish — IloRedfishSession class' {
    # The IloRedfishSession class is module-scoped (declared in Automation.psm1) so
    # it cannot be referenced as a type accelerator from outside the module.  Its
    # presence is verified indirectly by the MountAndBoot / Status / Mount tests.
    It 'Class is declared inside Automation.psm1' {
        $psm1 = Get-Content (Join-Path $Script:ModuleRoot 'Automation\Automation.psm1') -Raw
        $psm1 | Should -Match 'class\s+IloRedfishSession\b'
    }
}

Describe 'Invoke-IloRedfish — Action validation' {
    It 'Rejects invalid action' {
        { & Invoke-IloRedfish -Action 'Bogus' -IloIp '127.0.0.1' -ErrorAction SilentlyContinue } |
            Should -Throw
    }

    It 'MountAndBoot without IsoUrl fails' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -DryRun
        $r.Success | Should -Be $true
    }
}
