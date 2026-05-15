# Executor.Tests.ps1 — Tests for Executor.psm1 (CommandResult, Invoke-Command, New-CommandResult, Invoke-CommandWithRetry)
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'New-CommandResult' {
    It 'Creates a CommandResult with Success=$true for RC=0' {
        $r = New-CommandResult -ReturnCode 0 -StandardOutput 'ok' -StandardError ''
        $r.Success | Should -Be $true
        $r.ReturnCode  | Should -Be 0
        $r.StandardOutput | Should -Be 'ok'
        $r.get_Output()   | Should -Be 'ok'
    }

    It 'Creates a CommandResult with Success=$false for RC>0' {
        $r = New-CommandResult -ReturnCode 1 -StandardOutput '' -StandardError 'error'
        $r.Success     | Should -Be $false
        $r.ReturnCode  | Should -Be 1
        $r.get_Output() | Should -Be 'error'
    }
}

Describe 'Invoke-Command' {
    It 'Executes a simple command and returns Success=$true' {
        $r = Invoke-Command -Command @('cmd.exe','/c','echo hello_world')
        $r.Success    | Should -Be $true
        $r.StandardOutput.Trim() | Should -Be 'hello_world'
    }

    It 'Returns Success=$false for a non-existent command' {
        $r = Invoke-Command -Command @('nonexistent_cmd_xyz')
        $r.Success | Should -Be $false
    }

    It 'Captures stderr for a failing command' {
        $r = Invoke-Command -Command @('cmd.exe','/c','echo error_out >&2')
        $r.StandardError.Trim() | Should -Be 'error_out'
    }
}

Describe 'Invoke-CommandWithRetry' {
    It 'Returns success on first attempt for a valid command' {
        $r = Invoke-CommandWithRetry -Command @('cmd.exe','/c','echo ok') -MaxAttempts 1
        $r.Success | Should -Be $true
    }

    It 'Throws error for invalid command (PowerShell fails on empty $args[-1])' {
        $r = Invoke-CommandWithRetry -Command @('nonexistent_cmd_xyz') -MaxAttempts 2 -DelaySeconds 0
        $r.Success | Should -Be $false
    }
}
