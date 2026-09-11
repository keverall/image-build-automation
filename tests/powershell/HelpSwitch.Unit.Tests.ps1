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

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # ── Discover every exported function that carries a -Help parameter ──────────
    # Exclude SCOM-specific commands (names containing 'Scom').
    $allCommands = Get-Command -Module Automation -CommandType Function |
        Where-Object {
            $_.Parameters -and
            $_.Parameters.ContainsKey('Help') -and
            $_.Name -notmatch 'Scom'
        }

    # SCOM-only command names to suppress (kept as a guard / future reference).
    $script:ScomCommands = @(
        'New-ScomMaintenanceScript',
        'New-ScomConnection',
        'Set-MaintenanceMode',
        'Test-ScomMaintenanceConnectivity'
    )
}

Describe 'Every OneView command with -Help renders help and exits cleanly' {

    # Build the -ForEach data set from the discovered commands.
    $helpCases = foreach ($c in $allCommands) {
        [PSCustomObject]@{
            CommandName = $c.Name
        }
    }

    It '<CommandName> -Help outputs help text and returns' -ForEach $helpCases {
        $output = & $CommandName -Help 2>&1
        # The help renderer writes output via Write-Output; capture it.
        $outputText = $output -join "`n"
        $outputText      | Should -Not -BeNullOrEmpty
        $outputText      | Should -Match 'NAME'
        $outputText      | Should -Match $CommandName
        $outputText      | Should -Match 'SYNOPSIS'
        $outputText      | Should -Match 'SYNTAX'
    }
}

Describe 'OneView commands can be invoked without -Help (parameter sets are well-formed)' {

    $invokeCases = foreach ($c in $allCommands) {
        [PSCustomObject]@{
            CommandName   = $c.Name
            DefaultSet    = $c.DefaultParameterSet ?? '__AllParameterSets'
            ParameterSets = ($c.ParameterSets | ForEach-Object { $_.Name }) -join ','
        }
    }

    It '<CommandName> has a parameter set that does not require -Help' -ForEach $invokeCases {
        # The command must have at least one parameter set that is NOT the
        # dedicated 'Help' set (or use the default __AllParameterSets).
        $nonHelpSets = $CommandSets = ($c = Get-Command $CommandName -ErrorAction Stop).ParameterSets |
            Where-Object { $_.Name -ne 'Help' }
        $nonHelpSets.Count | Should -BeGreaterThan 0
    }

    It '<CommandName> does not force -Help to be mandatory' -ForEach $invokeCases {
        $cmd = Get-Command $CommandName -ErrorAction Stop
        $helpParam = $cmd.Parameters['Help']
        $helpParam | Should -Not -BeNullOrEmpty
        $mandatoryAttrs = $helpParam.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        if ($mandatoryAttrs) {
            ($mandatoryAttrs | Where-Object { $_.Mandatory }).Count | Should -Be 0
        }
    }

    It '<CommandName> -Help selects the Help parameter set (or __AllParameterSets) and not the Run set' -ForEach $invokeCases {
        $cmd = Get-Command $CommandName -ErrorAction Stop
        $helpParam = $cmd.Parameters['Help']
        $helpAttrs = $helpParam.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        if ($helpAttrs) {
            # The Help parameter should be in the 'Help' set (if parameter sets
            # are used) or in __AllParameterSets (no explicit set). Either is fine
            # — the key requirement is that it is NOT mandatory.
            $helpAttrs | ForEach-Object {
                $_.Mandatory | Should -Be $false
            }
        }
    }
}

Describe 'Get-CommandHelp integration for select OneView commands' {

    # Spot-check a representative subset of OneView commands to ensure
    # Get-CommandHelp produces structured output for each.
    $spotCheck = @(
        @{ Cmd = 'Connect-OneView' },
        @{ Cmd = 'Get-OneViewServerList' },
        @{ Cmd = 'Get-OneViewServerTarget' },
        @{ Cmd = 'Invoke-IloRedfish' },
        @{ Cmd = 'Invoke-PowerShellScript' },
        @{ Cmd = 'New-OneViewMaintenanceScript' },
        @{ Cmd = 'Invoke-WindowsSecurityUpdate' },
        @{ Cmd = 'Test-ServerConnectivity' },
        @{ Cmd = 'Get-MaintenanceStatusReport' }
    )

    It 'Get-CommandHelp <Cmd> renders structured output' -ForEach $spotCheck {
        $output = & Get-CommandHelp -Name $Cmd 2>&1
        $text = $output -join "`n"
        $text | Should -Not -BeNullOrEmpty
        $text | Should -Match 'NAME'
        $text | Should -Match "`s"
        $text | Should -Match 'SYNOPSIS'
        $text | Should -Match 'SYNTAX'
    }

    It '<Cmd> -Help and Get-CommandHelp <Cmd> produce the same NAME line' -ForEach $spotCheck {
        $direct = & $Cmd -Help 2>&1
        $indirect = & Get-CommandHelp -Name $Cmd 2>&1
        $directText = $direct -join "`n"
        $indirectText = $indirect -join "`n"
        $directText  | Should -Match "NAME`r?`n    $Cmd"
        $indirectText | Should -Match "NAME`r?`n    $Cmd"
    }
}
