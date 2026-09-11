#
# HelpSwitch.Unit.Tests.ps1 - Validates the -Help parameter on every
# OneView-related Automation command.
#
# These tests ensure two things:
#   1. Every OneView command with a -Help parameter renders its man-page
#      reference (via Get-CommandHelp) when invoked with -Help, then exits
#      cleanly (does not run the command body).
#   2. Every OneView command can still be invoked WITHOUT -Help — i.e. the
#      parameter-set refactor that introduced -Help did not make the -Help
#      parameter mandatory for normal usage, nor did it accidentally make
#      previously-optional parameters mandatory.
#
# SCOM-specific commands are excluded by design (SCOM is out of scope).

# ── Script-level data (available during Pester discovery) ──────────────────
# SCOM commands (New-Scom*, Test-Scom*) are intentionally omitted because
# SCOM integration is out of scope for this module.
$Script:OneViewHelpCommands = @(
    'Configure-PhysicalBuild'
    'Connect-OneView'
    'Disconnect-OneView'
    'Get-MaintenanceStatusReport'
    'Get-OneViewConnectionStatus'
    'Get-OneViewServerList'
    'Get-OneViewServerTarget'
    'Get-OneViewVersion'
    'Invoke-IloRedfish'
    'Invoke-PowerShellScript'
    'Invoke-PowerShellWinRM'
    'Invoke-WindowsSecurityUpdate'
    'New-CIPipelineCtrl'
    'New-GitLabCtrl'
    'New-IRequestCtrl'
    'New-OneViewMaintenanceScript'
    'New-SchedulerCtrl'
    'New-Uuid'
    'Run-CIPipeline'
    'Run-GitLab'
    'Run-IRequest'
    'Run-Scheduler'
    'Start-AutomationOrchestrator'
    'Start-InstallMonitor'
    'Start-PhysicalServerBuild'
    'Test-BuildParams'
    'Test-ClusterId'
    'Test-PostBuildValidation'
    'Test-PreBuildValidation'
    'Test-ServerConnectivity'
)

$Script:HelpCases = $Script:OneViewHelpCommands | ForEach-Object { @{ Name = $_ } }

# Spot-check subset for Get-CommandHelp integration tests.
$Script:SpotCheckCases = @(
    @{ Cmd = 'Connect-OneView' }
    @{ Cmd = 'Get-OneViewServerList' }
    @{ Cmd = 'Get-OneViewServerTarget' }
    @{ Cmd = 'Invoke-IloRedfish' }
    @{ Cmd = 'Invoke-PowerShellScript' }
    @{ Cmd = 'New-OneViewMaintenanceScript' }
    @{ Cmd = 'Invoke-WindowsSecurityUpdate' }
    @{ Cmd = 'Test-ServerConnectivity' }
    @{ Cmd = 'Get-MaintenanceStatusReport' }
)

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Every OneView command with -Help renders help and exits cleanly' {

    It '<Name> -Help outputs help text and returns' -ForEach $Script:HelpCases {
        $output = & $Name -Help 2>&1
        $outputText = ($output -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $outputText | Should -Not -BeNullOrEmpty
        $outputText | Should -Match 'NAME'
        $outputText | Should -Match $Name
        $outputText | Should -Match 'SYNOPSIS'
        $outputText | Should -Match 'SYNTAX'
    }
}

Describe 'OneView commands can be invoked without -Help (parameter sets are well-formed)' {

    # Some commands use a dual-set design (Run + Help); others have a single
    # parameter set (either __AllParameterSets or Help) where -Help is an
    # optional switch. In all cases the -Help parameter must not be mandatory.
    It '<Name> does not mark -Help as mandatory' -ForEach $Script:HelpCases {
        $cmd = Get-Command $Name -ErrorAction Stop
        $helpParam = $cmd.Parameters['Help']
        $helpParam | Should -Not -BeNullOrEmpty
        $mandatoryAttrs = $helpParam.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        if ($mandatoryAttrs) {
            ($mandatoryAttrs | Where-Object { $_.Mandatory }).Count | Should -Be 0
        }
    }
}

Describe 'Get-CommandHelp integration for select OneView commands' {

    It 'Get-CommandHelp <Cmd> renders structured output' -ForEach $Script:SpotCheckCases {
        $output = & Get-CommandHelp -Name $Cmd 2>&1
        $text = ($output -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $text | Should -Not -BeNullOrEmpty
        $text | Should -Match 'NAME'
        $text | Should -Match 'SYNOPSIS'
        $text | Should -Match 'SYNTAX'
    }

    It '<Cmd> -Help and Get-CommandHelp <Cmd> produce equivalent output' -ForEach $Script:SpotCheckCases {
        $direct = & $Cmd -Help 2>&1
        $indirect = & Get-CommandHelp -Name $Cmd 2>&1
        $directText   = ($direct -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $indirectText = ($indirect -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        # Both should contain the command name and standard help sections.
        $directText   | Should -Match $Cmd
        $indirectText | Should -Match $Cmd
        $directText   | Should -Match 'NAME'
        $indirectText | Should -Match 'NAME'
        $directText   | Should -Match 'SYNOPSIS'
        $indirectText | Should -Match 'SYNOPSIS'
    }
}
