# OneViewMaintenanceMode.Unit.Tests.ps1
# Regression tests for Enable-/Disable-OneViewMaintenanceMode defaults.
#
# Guards against two classes of bug:
#  1. Parameter aliases that collide with their own parameter name (which throws
#     "The parameter 'NoSchedule' cannot be specified because it conflicts with
#     the parameter alias of the same name for parameter 'NoSchedule'").
#  2. Omitting -Start/-End on Enable-OneViewMaintenanceMode passed $null into the
#     [DateTime]-typed OneViewClient.SetMaintenance method, throwing
#     "Cannot convert null to type 'system.datetime'".

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction SilentlyContinue
}

Describe 'Enable-OneViewMaintenanceMode - parameter integrity' {
    It 'NoSchedule and Json parameters expose no self-referential aliases' {
        $cmd = Get-Command Enable-OneViewMaintenanceMode -ErrorAction Stop
        foreach ($p in $cmd.Parameters.Values) {
            $p.Aliases | Where-Object { $_ -eq $p.Name } |
                ForEach-Object { throw "Parameter '$($p.Name)' has a self-referential alias" }
        }
        $cmd.Parameters['NoSchedule'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['NoSchedule'].Aliases | Should -Be @()
    }
}

Describe 'Enable-OneViewMaintenanceMode - default schedule when -Start/-End omitted' {
    It 'Does not throw and defaults StartTime/EndTime to a 4h UTC window' {
        $before = [DateTime]::UtcNow
        $result = Enable-OneViewMaintenanceMode -TargetId 'srv01' -OneViewHost 'bogus.example' -DryRun -ErrorAction Stop
        $after = [DateTime]::UtcNow

        $result.Success | Should -Be $true
        $result.StartTime | Should -Not -BeNullOrEmpty
        $result.EndTime   | Should -Not -BeNullOrEmpty

        # Start defaults to ~now (UTC), end to start + ~4h.
        $result.StartTime | Should -BeGreaterThan $before.AddSeconds(-5)
        $result.StartTime | Should -BeLessThan $after.AddSeconds(5)
        $result.EndTime   | Should -BeGreaterThan $before.AddHours(3)
        $result.EndTime   | Should -BeLessThan $after.AddHours(5)
    }
}

Describe 'Disable-OneViewMaintenanceMode - parameter integrity and dry run' {
    It 'NoSchedule exposes no self-referential aliases' {
        $cmd = Get-Command Disable-OneViewMaintenanceMode -ErrorAction Stop
        foreach ($p in $cmd.Parameters.Values) {
            $p.Aliases | Where-Object { $_ -eq $p.Name } |
                ForEach-Object { throw "Parameter '$($p.Name)' has a self-referential alias" }
        }
        $cmd.Parameters['NoSchedule'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['NoSchedule'].Aliases | Should -Be @()
    }

    It 'DryRun completes without throwing' {
        $result = Disable-OneViewMaintenanceMode -TargetId 'srv01' -OneViewHost 'bogus.example' -DryRun -ErrorAction Stop
        $result.Success | Should -Be $true
    }

    It 'Live run without credentials returns a clear message instead of a cryptic conversion error' {
        $result = Disable-OneViewMaintenanceMode -TargetId 'srv01' -OneViewHost 'bogus.example' -ErrorAction SilentlyContinue
        $result.Success | Should -Be $false
        $result.Message | Should -Match 'credentials? not configured'
    }
}

Describe 'Enable-OneViewMaintenanceMode - credentials guard' {
    It 'Live run without credentials returns a clear message instead of the empty-string bind error' {
        $result = Enable-OneViewMaintenanceMode -TargetId 'srv01' -OneViewHost 'bogus.example' -ErrorAction SilentlyContinue
        $result.Success | Should -Be $false
        $result.Message | Should -Match 'credentials? not configured'
    }
}

Describe 'Enable/Disable-OneViewMaintenanceMode - serial number accepted as -TargetId' {
    It 'DryRun accepts a serial passed positionally as -TargetId (resolver is invoked in live runs)' {
        # Reproduces the reported failure: operators pass the serial number as the
        # positional -TargetId. The cmdlet must not require a server NAME to bind,
        # and must attempt serial resolution on a live run (which DryRun skips).
        $result = Enable-OneViewMaintenanceMode -TargetId 'CZ22420JCM' -OneViewHost 'bogus.example' -DryRun -ErrorAction Stop
        $result.Success          | Should -Be $true
        $result.TargetId         | Should -Be 'CZ22420JCM'
        $result.ResolvedTarget   | Should -Be 'CZ22420JCM'
    }

    It 'DryRun accepts an explicit -SerialNumber and records it' {
        $result = Disable-OneViewMaintenanceMode -TargetId 'srv01' -SerialNumber 'CZ22420JCM' -OneViewHost 'bogus.example' -DryRun -ErrorAction Stop
        $result.Success        | Should -Be $true
        $result.SerialNumber   | Should -Be 'CZ22420JCM'
    }
}
