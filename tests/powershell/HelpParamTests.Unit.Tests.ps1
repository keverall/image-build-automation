#
# HelpParamTests.Unit.Tests.ps1 - Data-driven validation of the -Help switch
#
# The command matrix lives in scripts/HelpParamTests.txt (one command per line;
# blank lines and '#' comments are ignored) so this suite and the list can never
# drift apart. For every command in that file these tests assert that:
#
#   1. the command is exported and exposes a -Help parameter;
#   2. invoking -Help throws no exception and writes no error records;
#   3. the rendered help belongs to *that* command - the NAME section, every
#      SYNTAX usage line, and the PARAMETERS table all name the invoked
#      command and never a different one;
#   4. the canonical man-page section structure is present and ordered
#      (NAME, SYNOPSIS, SYNTAX, [DESCRIPTION], PARAMETERS, EXAMPLES);
#   5. the EXAMPLES section links the Automation command reference; and
#   6. `-Help` and `Get-CommandHelp -Name` render identical output.
#
# A completeness guard keeps the matrix exhaustive: every exported Automation
# command that exposes -Help (SCOM excluded) must appear in the file.
#
# SCOM-only commands (New-Scom*, Test-Scom*) are out of scope by design.
#

BeforeDiscovery {
    $Script:RepoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $Script:HelpListPath = Join-Path (Join-Path $Script:RepoRoot 'scripts') 'HelpParamTests.txt'

    $Script:HelpCommands = @(
        if (Test-Path -LiteralPath $Script:HelpListPath) {
            Get-Content -LiteralPath $Script:HelpListPath |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') } |
                ForEach-Object { ($_ -split '\s+')[0] }
        }
    ) | Select-Object -Unique

    # Each case carries the command name plus the whole matrix so the ownership
    # assertions can prove no *other* command's name was rendered.
    $Script:HelpCases = $Script:HelpCommands | ForEach-Object { @{ Name = $_; All = $Script:HelpCommands } }
}

BeforeAll {
    $Script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $Script:ModuleRoot = Join-Path (Join-Path $Script:RepoRoot 'src/powershell') 'Automation'

    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # Reload the matrix at run time: BeforeDiscovery data is not guaranteed to
    # persist into the run phase.
    $Script:HelpListPath = Join-Path (Join-Path $Script:RepoRoot 'scripts') 'HelpParamTests.txt'
    $Script:HelpList = @(
        if (Test-Path -LiteralPath $Script:HelpListPath) {
            Get-Content -LiteralPath $Script:HelpListPath |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') } |
                ForEach-Object { ($_ -split '\s+')[0] }
        }
    )

    # Parameters PowerShell injects into every advanced function. Get-CommandHelp
    # deliberately omits these from SYNTAX and the PARAMETERS table.
    $Script:CommonParams = @(
        'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
        'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable',
        'OutBuffer', 'PipelineVariable', 'ProgressAction', 'Confirm', 'WhatIf'
    )
}

Describe 'Help test matrix (scripts/HelpParamTests.txt)' {

    It 'lists at least one command' {
        Test-Path -LiteralPath $Script:HelpListPath | Should -BeTrue -Because 'the -Help command matrix must exist'
        @($Script:HelpList).Count | Should -BeGreaterThan 0 -Because 'the -Help command matrix must not be empty'
    }

    It 'contains unique, well-formed Verb-Noun command names' {
        $duplicates = @($Script:HelpList | Group-Object | Where-Object { $_.Count -gt 1 })
        ($duplicates | ForEach-Object Name) | Should -BeNullOrEmpty -Because 'the -Help matrix must not list a command twice'

        foreach ($cmd in $Script:HelpList) {
            $cmd | Should -Match '^[A-Z][a-z]+-[A-Za-z0-9]+$' -Because "'$cmd' is not a well-formed Verb-Noun command name"
        }
    }

    It 'every listed command is exported by the Automation module' {
        $missing = @($Script:HelpList | Where-Object {
            -not (Get-Command -Name $_ -Module Automation -ErrorAction SilentlyContinue)
        })
        $missing | Should -BeNullOrEmpty -Because "listed but not exported: $($missing -join ', ')"
    }

    It 'every listed command exposes a -Help parameter' {
        $noHelp = @($Script:HelpList | Where-Object {
            $c = Get-Command -Name $_ -Module Automation -ErrorAction SilentlyContinue
            -not $c -or -not $c.Parameters.ContainsKey('Help')
        })
        $noHelp | Should -BeNullOrEmpty -Because "these commands do not expose -Help: $($noHelp -join ', ')"
    }

    It 'covers every exported Automation command that exposes -Help (SCOM excluded)' {
        $scomExclusions = @('New-ScomConnection', 'New-ScomMaintenanceScript', 'Test-ScomMaintenanceConnectivity')
        $expected = @(
            Get-Command -Module Automation |
                Where-Object { $_.CommandType -ne 'Alias' -and $_.Parameters -and $_.Parameters.ContainsKey('Help') } |
                Select-Object -ExpandProperty Name |
                Where-Object { $_ -notin $scomExclusions } |
                Sort-Object -Unique
        )
        $actual  = @($Script:HelpList | Sort-Object -Unique)
        $missing = @($expected | Where-Object { $_ -notin $actual })
        $extra   = @($actual   | Where-Object { $_ -notin $expected })

        $missing | Should -BeNullOrEmpty -Because "exported -Help commands missing from the matrix: $($missing -join ', ')"
        $extra   | Should -BeNullOrEmpty -Because "matrix lists commands without an exported -Help: $($extra -join ', ')"
    }

    It 'no listed command marks -Help as mandatory' {
        foreach ($cmd in $Script:HelpList) {
            $helpParam = (Get-Command -Name $cmd -ErrorAction Stop).Parameters['Help']
            $helpParam | Should -Not -BeNullOrEmpty -Because "$cmd must expose a -Help parameter"

            $attributes = @($helpParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute]
            })
            @($attributes | Where-Object { $_.Mandatory }).Count |
                Should -Be 0 -Because "-Help must never be mandatory for $cmd"
        }
    }
}

Describe 'Every listed command renders its own, well-formed -Help page' {

    It '<Name> -Help renders the correct command help without throwing' -ForEach $Script:HelpCases {

        # ── Invocation: no exception, no error records ──────────────────────────
        $threw      = $null
        $helpErrors = @()
        $raw        = @()
        try {
            $raw = @(& $Name -Help -ErrorAction SilentlyContinue -ErrorVariable helpErrors 2>&1)
        } catch {
            $threw = $_
        }

        $threw | Should -BeNullOrEmpty -Because "-Help must not throw for $Name"
        @($helpErrors) | Should -BeNullOrEmpty -Because "$Name -Help wrote to the error stream"
        @($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) |
            Should -BeNullOrEmpty -Because "$Name -Help leaked an ErrorRecord into its output"

        # ── Normalise (strip ANSI colour) and split into lines ──────────────────
        $text = (@($raw) -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $text | Should -Not -BeNullOrEmpty -Because "$Name -Help produced no output"

        $lines = @(($text -replace "`r", '') -split "`n")

        $sectionIndex = @{}
        foreach ($section in 'NAME', 'SYNOPSIS', 'SYNTAX', 'DESCRIPTION', 'PARAMETERS', 'EXAMPLES') {
            $sectionIndex[$section] = [array]::IndexOf($lines, $section)
        }
        foreach ($required in 'NAME', 'SYNOPSIS', 'SYNTAX', 'PARAMETERS', 'EXAMPLES') {
            $sectionIndex[$required] | Should -BeGreaterOrEqual 0 -Because "the $required section is missing from $Name -Help"
        }

        # ── Canonical section order ─────────────────────────────────────────────
        $expectedOrder = 'NAME', 'SYNOPSIS', 'SYNTAX', 'PARAMETERS', 'EXAMPLES'
        for ($i = 1; $i -lt $expectedOrder.Count; $i++) {
            $sectionIndex[$expectedOrder[$i]] | Should -BeGreaterThan $sectionIndex[$expectedOrder[$i - 1]] `
                -Because "$($expectedOrder[$i]) must follow $($expectedOrder[$i - 1]) in $Name -Help"
        }

        # ── Ownership: the NAME section must name THIS command ──────────────────
        $nameSection = @($lines[($sectionIndex['NAME'] + 1)..($lines.Count - 1)] | Where-Object { $_.Trim() } | Select-Object -First 1)
        $nameSection.Count | Should -Be 1 -Because "the NAME section of $Name -Help is empty"
        $nameSection[0].Trim() | Should -BeExactly $Name -Because "the rendered help NAME must be $Name"

        $otherCommands = @($All | Where-Object { $_ -ne $Name })
        $otherCommands | Should -Not -Contain $nameSection[0].Trim() -Because "$Name -Help rendered another command's NAME"

        # ── Ownership: every SYNTAX usage line must start with THIS command ─────
        $syntaxStart = $sectionIndex['SYNTAX'] + 1
        $syntaxEnd   = $lines.Count
        foreach ($later in 'DESCRIPTION', 'PARAMETERS', 'EXAMPLES') {
            if ($sectionIndex[$later] -ge 0 -and $sectionIndex[$later] -gt $sectionIndex['SYNTAX']) {
                $syntaxEnd = [Math]::Min($syntaxEnd, $sectionIndex[$later])
            }
        }
        $usageLines = @()
        if ($syntaxEnd -gt $syntaxStart) {
            $usageLines = @($lines[$syntaxStart..($syntaxEnd - 1)] | Where-Object { $_.Trim() })
        }
        foreach ($usageLine in $usageLines) {
            $usageLine.Trim() | Should -Match ('^' + [regex]::Escape($Name) + '(\s|$)') `
                -Because "every SYNTAX line for $Name must start with the command name"
            $usageLine.Trim() | Should -Not -Match '-Help(\s|$)' `
                -Because "the -Help switch must not appear in a SYNTAX usage line for $Name"
        }

        # A command that accepts anything other than -Help must render a usage line.
        $cmd       = Get-Command -Name $Name -ErrorAction Stop
        $ownParams = @($cmd.Parameters.Keys | Where-Object { $_ -notin $Script:CommonParams })
        $runParams = @($ownParams | Where-Object { $_ -ne 'Help' })
        if ($runParams.Count -gt 0) {
            @($usageLines).Count | Should -BeGreaterThan 0 -Because "$Name accepts parameters and must render a SYNTAX usage line"
        }

        # ── Ownership: the PARAMETERS table must document every parameter ──────
        $renderedParams = @()
        for ($i = $sectionIndex['PARAMETERS'] + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*-([A-Za-z0-9_]+)\s*<') { $renderedParams += $Matches[1] }
        }
        foreach ($paramName in $ownParams) {
            $renderedParams | Should -Contain $paramName -Because "the PARAMETERS table for $Name is missing -$paramName"
        }

        # ── EXAMPLES must link the command reference ───────────────────────────
        $examplesText = (@($lines[$sectionIndex['EXAMPLES']..($lines.Count - 1)]) -join "`n")
        $examplesText | Should -Match 'automation_commands\.md' -Because "the EXAMPLES section for $Name must link the Automation command reference"

        # ── -Help and Get-CommandHelp must render the same page ────────────────
        $indirect = (@(& Get-CommandHelp -Name $Name 2>&1) -join "`n") -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $text | Should -BeExactly $indirect -Because "$Name -Help and Get-CommandHelp -Name $Name must render identical output"
    }
}
