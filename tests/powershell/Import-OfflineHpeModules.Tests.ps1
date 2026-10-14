BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:importerPath = Join-Path $repoRoot 'scripts/Import-OfflineHpeModules.ps1'
    $tokens = $null
    $parseErrors = $null
    $script:importerAst = [System.Management.Automation.Language.Parser]::ParseFile($script:importerPath, [ref]$tokens, [ref]$parseErrors)
    foreach ($name in @('Test-HprestImportResidue', 'Import-OfflineHpeModule')) {
        $functionAst = $script:importerAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
        }, $true)
        . ([scriptblock]::Create($functionAst.Extent.Text))
    }
}

Describe 'Idempotent offline HPE module loading' {
    BeforeEach {
        $script:fixtureGuid = [guid]'4f7c7b70-fc3b-4c06-b437-476e2dc8038c'
        $script:fixtureManifest = Join-Path $TestDrive 'HpeFixture.psd1'
        Set-Content -LiteralPath $script:fixtureManifest -Value "@{ModuleVersion='10.0.4265.2221';GUID='$script:fixtureGuid'}"
        Mock Import-Module { throw 'An already loaded module must not be imported again.' }
        Mock Get-Command { [pscustomobject]@{ Name = $Name; ModuleName = $Module } } -ParameterFilter { $Module -in @('HPEOneView.1000', 'HPRESTCmdlets') }
        Mock Test-HprestImportResidue { return $false }
    }

    It 'reuses a loaded matching OneView module on repeated calls without disturbing sessions' {
        Mock Get-Module { [pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221'; Guid = $script:fixtureGuid } }
        1..2 | ForEach-Object {
            Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer', 'Get-OVIloSso')
        }
        Should -Invoke Import-Module -Times 0
    }

    It 'imports a fresh OneView module globally by manifest path, never using Force' {
        Mock Get-Module { return $null }
        Mock Import-Module { }
        Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer', 'Get-OVIloSso')
        Should -Invoke Import-Module -Times 1 -Exactly -ParameterFilter { $Name -eq $script:fixtureManifest -and $Global -and -not $Force }
    }

    It 'rejects a different OneView family without unloading or reimporting it' {
        Mock Get-Module { [pscustomobject]@{ Name = 'HPEOneView.860'; Version = [version]'8.60'; Guid = $script:fixtureGuid } }
        { Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer') } | Should -Throw '*fresh*Existing modules and sessions were left untouched*'
        Should -Invoke Import-Module -Times 0
    }

    It 'rejects another module identity even when its name and version match' {
        Mock Get-Module { [pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221'; Guid = [guid]::Empty } }
        { Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer') } | Should -Throw '*different HPE module version or identity*'
        Should -Invoke Import-Module -Times 0
    }

    It 'does not retry an incomplete loaded OneView module' {
        Mock Get-Module { [pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221'; Guid = $script:fixtureGuid } }
        Mock Get-Command { return $null } -ParameterFilter { $Module -eq 'HPEOneView.1000' }
        { Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer') } | Should -Throw '*loaded but*unavailable*'
        Should -Invoke Import-Module -Times 0
    }

    It 'reuses loaded HPREST without rerunning ScriptsToProcess or Add-Type' {
        Set-Content -LiteralPath $script:fixtureManifest -Value "@{ModuleVersion='1.2.0.0';GUID='$script:fixtureGuid'}"
        Mock Get-Module { [pscustomobject]@{ Name = 'HPRESTCmdlets'; Version = [version]'1.2.0.0'; Guid = $script:fixtureGuid } }
        Mock Test-HprestImportResidue { return $true }
        1..2 | ForEach-Object {
            Import-OfflineHpeModule -ModuleName HPRESTCmdlets -ManifestPath $script:fixtureManifest -ExpectedVersion '1.2.0.0' -RequiredCommands @('Connect-HPREST', 'Get-HPRESTDataRaw')
        }
        Should -Invoke Import-Module -Times 0
        Should -Invoke Test-HprestImportResidue -Times 0
    }

    It 'detects an orphaned AsyncPipeline type and requires a fresh shell without retrying' {
        Set-Content -LiteralPath $script:fixtureManifest -Value "@{ModuleVersion='1.2.0.0';GUID='$script:fixtureGuid'}"
        Mock Get-Module { return $null }
        Mock Test-HprestImportResidue { return $true }
        { Import-OfflineHpeModule -ModuleName HPRESTCmdlets -ManifestPath $script:fixtureManifest -ExpectedVersion '1.2.0.0' -RequiredCommands @('Connect-HPREST') } | Should -Throw '*AsyncPipeline*types cannot be unloaded*license script was not bypassed*'
        Should -Invoke Import-Module -Times 0
    }

    It 'preserves and reports a fresh import failure rather than modifying the vendor package' {
        Mock Get-Module { return $null }
        Mock Import-Module { throw 'Synthetic license/runtime failure' }
        $before = (Get-FileHash -LiteralPath $script:fixtureManifest).Hash
        { Import-OfflineHpeModule -ModuleName HPEOneView.1000 -ManifestPath $script:fixtureManifest -ExpectedVersion '10.0.4265.2221' -RequiredCommands @('Get-OVServer') } | Should -Throw '*Files were preserved*Original error: Synthetic license/runtime failure*'
        (Get-FileHash -LiteralPath $script:fixtureManifest).Hash | Should -BeExactly $before
    }

    It 'has no force imports, unloading, type redefinition, or license bypass' {
        $calls = @($script:importerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
        @($calls | Where-Object { $_.GetCommandName() -in @('Remove-Module', 'Remove-Item', 'Add-Type', 'Save-Module', 'Install-Module') }).Count | Should -Be 0
        $imports = @($calls | Where-Object { $_.GetCommandName() -eq 'Import-Module' })
        foreach ($import in $imports) {
            @($import.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -in @('Force', 'SkipEditionCheck') }).Count | Should -Be 0
        }
    }
}
