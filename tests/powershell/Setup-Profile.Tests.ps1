#
# Setup-Profile.Tests.ps1 - Integration tests for profile-based module loading.
#
# These tests guard against the exact failure where `Connect-OneView` (and all
# Automation commands) are "not recognized" in a real shell because the profile
# produced by Setup-Profile.ps1 does not import the Automation module. They do
# NOT touch the operator's real $PROFILE - Setup-Profile.ps1 is driven with
# -ProfileRoot so every write lands under a temp directory, and the generated
# profile is sourced in a *fresh* pwsh to prove the command is actually published.
#
# Shared state uses environment variables (not $script:) because the variables
# must be visible inside It blocks AND inherited by the child pwsh processes.

BeforeAll {
    $env:SETUPPROFILE_REPOROOT = (Resolve-Path (Join-Path $PSScriptRoot '../../')).Path
    $env:SETUPPROFILE_SETUP     = Join-Path $env:SETUPPROFILE_REPOROOT 'scripts/Setup-Profile.ps1'
    $env:SETUPPROFILE_TEMP      = Join-Path ([System.IO.Path]::GetTempPath()) ("SetupProfileTest_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $env:SETUPPROFILE_TEMP -Force | Out-Null
}

AfterAll {
    if (Test-Path $env:SETUPPROFILE_TEMP) {
        Remove-Item $env:SETUPPROFILE_TEMP -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Setup-Profile - injects the Automation module import (regression for published-but-unavailable commands)' {

    It 'Should write a live profile under -ProfileRoot that imports the Automation module' {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $env:SETUPPROFILE_SETUP -ProfileRoot $env:SETUPPROFILE_TEMP | Out-Null

        $profile = Join-Path $env:SETUPPROFILE_TEMP $(
            if ($IsWindows -or $null -eq $IsWindows) {
                'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
            } else {
                '.config/powershell/Microsoft.PowerShell_profile.ps1'
            })
        $profile | Should -Exist

        $content = Get-Content $profile -Raw
        # This is the single line that makes Connect-OneView resolvable in a new shell.
        $content | Should -Match '# Image Build Automation module'
        $content | Should -Match 'Automation\.psd1'
        $content | Should -Match 'Import-Module'
    }

    It 'Should pre-load HPEOneView.1000 only on Windows (guarded by $IsWindows)' {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $env:SETUPPROFILE_SETUP -ProfileRoot $env:SETUPPROFILE_TEMP | Out-Null

        $profile = Join-Path $env:SETUPPROFILE_TEMP $(
            if ($IsWindows -or $null -eq $IsWindows) {
                'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
            } else {
                '.config/powershell/Microsoft.PowerShell_profile.ps1'
            })
        $content = Get-Content $profile -Raw
        $content | Should -Match 'HPEOneView\.1000'
        # Must be guarded so it never runs on Linux/macOS where the module cannot load.
        $content | Should -Match 'if\s*\(\s*\$IsWindows'
    }
}

Describe 'Setup-Profile - a fresh shell that sources the profile can resolve Connect-OneView' {

    It 'Should make Connect-OneView available (catches "term not recognized" regression)' {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $env:SETUPPROFILE_SETUP -ProfileRoot $env:SETUPPROFILE_TEMP | Out-Null

        $profile = Join-Path $env:SETUPPROFILE_TEMP $(
            if ($IsWindows -or $null -eq $IsWindows) {
                'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
            } else {
                '.config/powershell/Microsoft.PowerShell_profile.ps1'
            })
        $profile | Should -Exist

        # Source the generated profile in a brand-new pwsh (no module pre-imported)
        # and verify the published command actually resolves and runs. -OneViewHost
        # is supplied so no interactive host prompt fires; -DryRun makes no real
        # connection. AUTOMATED_MODE is also set as belt-and-suspenders against any
        # credential prompt. The child is run as a job with a hard timeout so a hang
        # can never freeze the run.
        $checker = Join-Path $env:SETUPPROFILE_TEMP 'check.ps1'
        @"
. '$($profile)'
`$env:AUTOMATED_MODE = 'true'
`$cmd = Get-Command Connect-OneView -ErrorAction SilentlyContinue
if (-not `$cmd) { Write-Output 'MISSING'; exit 2 }
Write-Output 'RESOLVED'
Connect-OneView -OneViewHost 'localhost' -DryRun | Out-Null
Write-Output 'DRYRUN_OK'
"@ | Set-Content $checker

        $job = Start-Job -ScriptBlock { & pwsh -NoProfile -ExecutionPolicy Bypass -File $using:checker }
        if (-not ($job | Wait-Job -Timeout 120)) {
            $job | Stop-Job -ErrorAction SilentlyContinue
            throw "Setup-Profile checker timed out (possible interactive prompt or module-load hang)."
        }
        $result = Receive-Job $job
        $result | Should -Contain 'RESOLVED'
        $result | Should -Contain 'DRYRUN_OK'
    }
}

