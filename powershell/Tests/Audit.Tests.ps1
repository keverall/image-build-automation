# Audit.Tests.ps1 — Tests for Audit.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'
    Ensure-DirectoryExists -Path $Script:AuditDir
    # Remove any leftover master log
    Remove-Item (Join-Path $Script:AuditDir 'audit.log') -ErrorAction SilentlyContinue
}

Describe 'New-AuditLogger / AuditLogger' {
    $audit = $null
    BeforeEach { $Script:audit = New-AuditLogger -Category 'unittest' -LogDir $Script:AuditDir }

    It 'Creates an AuditLogger with given category' {
        $audit.Category | Should -Be 'unittest'
    }

    It 'Records an entry on Log() call' {
        $entry = $audit.Log('test_action', 'INFO', 'srv01', 'details here')
        $entry.action | Should -Be 'test_action'
        $entry.status | Should -Be 'INFO'
        $entry.server  | Should -Be 'srv01'
        $audit.Entries.Count | Should -Be 1
    }

    It 'Log returns the record that was appended' {
        $e = $audit.Log('action_a', 'SUCCESS', '', 'info')
        $e.action  | Should -Be 'action_a'
        $e.status  | Should -Be 'SUCCESS'
    }

    It 'Save() creates a classified JSON file' {
        $audit.Log('x','INFO','','d')
        $f = $audit.Save()
        Test-Path $f | Should -Be $true
        (Get-Content $f -Raw) | Should -Match 'category'
    }

    It 'Save() auto-generates filename when none provided' {
        $audit.Log('x','INFO')
        $f = $audit.Save()
        $f | Should -Match '^.*unittest_\d+\.json$'
    }

    It 'AppendToMaster() appends to the master log file' {
        $audit.Log('master_test','INFO')
        $audit.AppendToMaster()
        $master = Join-Path $Script:AuditDir 'audit.log'
        Test-Path $master | Should -Be $true
        $content = Get-Content $master -Raw
        $content | Should -Match 'master_test'
    }

    It 'Clear() empties the in-memory entries list' {
        $audit.Log('a','INFO'); $audit.Log('b','INFO')
        $audit.Entries.Count | Should -Be 2
        $audit.Clear()
        $audit.Entries.Count | Should -Be 0
    }
}
