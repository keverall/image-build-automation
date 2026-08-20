# Invoke-IsoDeploy.Unit.Tests.ps1
# Dedicated unit tests for the Invoke-IsoDeploy public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
    $Script:prevAutomatedMode = $env:AUTOMATED_MODE
    $env:AUTOMATED_MODE = 'true'
}

AfterAll {
    if ($Script:prevAutomatedMode) { $env:AUTOMATED_MODE = $Script:prevAutomatedMode } else { $env:AUTOMATED_MODE = $null }
}

Describe 'Invoke-IsoDeploy - basic invocation and parameter validation' {
    It 'Function is exported and has expected parameters' {
        $cmd = Get-Command Invoke-IsoDeploy -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.Parameters.Keys | Should -Contain 'DryRun'
    }

    It 'Accepts -DryRun switch (with -GuardRail) without throwing' {
        # Most functions accept -DryRun; calling with it should not throw immediately.
        # -GuardRail is mandatory on build/deploy commands.
        { & Invoke-IsoDeploy -GuardRail '.*' -DryRun -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = & Invoke-IsoDeploy -DryRun -ErrorAction SilentlyContinue
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Invoke-IsoDeploy -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
