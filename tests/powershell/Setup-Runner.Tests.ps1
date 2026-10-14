#requires -Version 5.1

Describe 'setup-runner platform detection' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $runnerPath = Join-Path $repoRoot 'scripts/setup-runner.ps1'
    }

    It 'does not assign to read-only automatic variables in standalone scripts' {
        $readOnlyVariables = @(
            'IsWindows', 'IsLinux', 'IsMacOS', 'IsCoreCLR',
            'PSVersionTable', 'ExecutionContext', 'PID', 'PSCulture',
            'PSUICulture', 'Host', 'HOME', 'Error', 'ShellId',
            'true', 'false'
        )

        $scriptFiles = Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' -File -Recurse
        $violations = foreach ($scriptFile in $scriptFiles) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptFile.FullName, [ref]$tokens, [ref]$parseErrors)

            $assignments = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $true)

            foreach ($assignment in $assignments) {
                $left = $assignment.Left
                if ($left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    $left.VariablePath.UserPath -in $readOnlyVariables) {
                    [pscustomobject]@{
                        File = $scriptFile.FullName
                        Variable = $left.VariablePath.UserPath
                        Line = $assignment.Extent.StartLineNumber
                    }
                }
            }
        }

        $violations | Should -BeNullOrEmpty
    }

    It 'executes Install-RequiredModules without colliding with $IsWindows' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $runnerPath, [ref]$tokens, [ref]$parseErrors)
        $functionAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Install-RequiredModules'
        }, $true) | Select-Object -First 1

        $functionAst | Should -Not -BeNullOrEmpty

        $invoke = {
            param($functionText)
            function Write-Log { param($Message) }
            function Get-BundledModulePath { param($Name, $Version) return $null }
            function Install-RequiredModule { param($Name, $Version) }
            $REQUIRED_MODULES = @()
            . ([scriptblock]::Create($functionText))
            Install-RequiredModules
        }

        { & $invoke $functionAst.Extent.Text } | Should -Not -Throw
    }
}

Describe 'setup-runner non-destructive offline module imports' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $runnerPath = Join-Path $repoRoot 'scripts/setup-runner.ps1'
        $tokens = $null
        $errors = $null
        $script:runnerAst = [System.Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$errors)
        foreach ($name in @('Get-BundledModulePath', 'Repair-TempModulesDirectory', 'Test-ModuleImportIsolated', 'Install-RequiredModule', 'Install-Checkmake')) {
            $definition = $script:runnerAst.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        function Write-OK { param($Message) }
        function Write-Log { param($Message) }
        function Write-Warn { param($Message) }
        function Find-LocalBinary { param($BinaryName) }
        function Test-ValidExecutable { param($Path) }
    }

    BeforeEach {
        $script:VENDOR_MODULES_DIR = Join-Path $TestDrive 'modules'
        $script:TEMP_MODULES_DIR = Join-Path $TestDrive 'temp-modules'
        $script:BIN_DIR = Join-Path $TestDrive 'bin'
        $script:fixtureName = 'SetupSafetyFixture'
        $script:fixtureVersion = '1.0.0'
        $script:fixtureRoot = Join-Path $script:VENDOR_MODULES_DIR "$script:fixtureName/$script:fixtureVersion"
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
        $script:fixtureManifest = Join-Path $script:fixtureRoot "$script:fixtureName.psd1"
        Set-Content -LiteralPath $script:fixtureManifest -Value "@{ RootModule = '$script:fixtureName.psm1'; ModuleVersion = '$script:fixtureVersion'; FunctionsToExport = @('Get-SetupFixture') }"
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot "$script:fixtureName.psm1") -Value 'function Get-SetupFixture { return "fixture" }; Export-ModuleMember -Function Get-SetupFixture'
    }

    It 'contains no dependency deletion, moves, or online provisioning calls' {
        $blocked = @('Remove-Item', 'Move-Item', 'Clear-Content', 'rm', 'rmdir', 'del', 'Save-Module', 'Install-Module', 'Invoke-WebRequest', 'Invoke-RestMethod')
        $calls = $script:runnerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
        @($calls | Where-Object { $_.GetCommandName() -in $blocked }).Count | Should -Be 0
        $deletions = $script:runnerAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Member.Value -eq 'Delete'
        }, $true)
        @($deletions).Count | Should -Be 0
    }

    It 'prefers the bundled manifest to another installed copy' {
        Mock Get-Module { throw 'Discovery of a stale installation should not be needed.' }
        Mock Test-ModuleImportIsolated { return $true }
        Install-RequiredModule -Name $script:fixtureName -Version $script:fixtureVersion
        Should -Invoke Test-ModuleImportIsolated -Times 1 -Exactly -ParameterFilter { $ManifestPath -eq $script:fixtureManifest }
        Should -Invoke Get-Module -Times 0
    }

    It 'preserves all bundled bytes and other versions after repeated failed imports' {
        $otherVersion = Join-Path $script:VENDOR_MODULES_DIR "$script:fixtureName/2.0.0"
        New-Item -ItemType Directory -Path $otherVersion -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $otherVersion 'retain.txt') -Value 'retain this version too'
        $before = @(Get-ChildItem -LiteralPath $script:VENDOR_MODULES_DIR -File -Recurse | Get-FileHash | ForEach-Object { "$($_.Path):$($_.Hash)" })
        Mock Test-ModuleImportIsolated { throw 'Synthetic import failure; runtime is unsupported.' }
        1..2 | ForEach-Object {
            { Install-RequiredModule -Name $script:fixtureName -Version $script:fixtureVersion } | Should -Throw '*Synthetic import failure*'
        }
        $after = @(Get-ChildItem -LiteralPath $script:VENDOR_MODULES_DIR -File -Recurse | Get-FileHash | ForEach-Object { "$($_.Path):$($_.Hash)" })
        ($after -join "`n") | Should -BeExactly ($before -join "`n")
    }

    It 'rejects an incomplete bundle without falling back or deleting it' {
        $badRoot = Join-Path $script:VENDOR_MODULES_DIR 'IncompleteFixture/1.0.0'
        New-Item -ItemType Directory -Path $badRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $badRoot 'retain.txt') -Value 'not a manifest'
        Mock Get-Module { throw 'Do not silently switch to another package.' }
        { Install-RequiredModule -Name IncompleteFixture -Version '1.0.0' } | Should -Throw '*no matching module manifest*'
        Test-Path -LiteralPath (Join-Path $badRoot 'retain.txt') | Should -BeTrue
    }

    It 'fails clearly when a module is unavailable offline' {
        Mock Get-Module { return $null }
        { Install-RequiredModule -Name MissingOfflineFixture -Version '1.0.0' } | Should -Throw '*No files were deleted and no download was attempted*'
    }

    It 'validates an existing local installation by its explicit manifest path' {
        Mock Get-Module { [pscustomobject]@{ Version = [version]'1.0.0'; Path = $script:fixtureManifest } }
        Mock Test-ModuleImportIsolated { return $true }
        Install-RequiredModule -Name InstalledFixture -Version '1.0.0'
        Should -Invoke Test-ModuleImportIsolated -Times 1 -Exactly -ParameterFilter { $ManifestPath -eq $script:fixtureManifest }
    }

    It 'successfully imports a real harmless fixture in an isolated process twice' {
        1..2 | ForEach-Object {
            Test-ModuleImportIsolated -Name $script:fixtureName -Version $script:fixtureVersion -ManifestPath $script:fixtureManifest | Should -BeTrue
        }
        Test-Path -LiteralPath $script:fixtureManifest | Should -BeTrue
    }

    It 'reports the actual isolated import error and preserves the failing manifest' {
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot "$script:fixtureName.psm1") -Value "throw 'Synthetic isolated import failure'"
        { Test-ModuleImportIsolated -Name $script:fixtureName -Version $script:fixtureVersion -ManifestPath $script:fixtureManifest } |
            Should -Throw '*Files were preserved*Import error:*Synthetic isolated import failure*'
        Test-Path -LiteralPath $script:fixtureManifest | Should -BeTrue
    }

    It 'copies only missing legacy modules and retains both existing and legacy files' {
        $legacyRoot = Join-Path $script:TEMP_MODULES_DIR $script:fixtureName
        $newLegacy = Join-Path $script:TEMP_MODULES_DIR 'LegacyOnlyFixture'
        New-Item -ItemType Directory -Path $legacyRoot, $newLegacy -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $legacyRoot 'retain.txt') -Value 'legacy duplicate retained'
        Set-Content -LiteralPath (Join-Path $newLegacy 'retain.txt') -Value 'copy retained'
        $hashBefore = (Get-FileHash -LiteralPath $script:fixtureManifest).Hash
        Repair-TempModulesDirectory
        Repair-TempModulesDirectory
        (Get-FileHash -LiteralPath $script:fixtureManifest).Hash | Should -BeExactly $hashBefore
        Test-Path -LiteralPath (Join-Path $legacyRoot 'retain.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $newLegacy 'retain.txt') | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $script:VENDOR_MODULES_DIR 'LegacyOnlyFixture/retain.txt') | Should -BeExactly 'copy retained'
    }

    It 'retains invalid optional binaries rather than deleting or downloading them' {
        New-Item -ItemType Directory -Path $script:BIN_DIR -Force | Out-Null
        $exe = if ($IsWindows) { 'checkmake.exe' } else { 'checkmake' }
        $candidate = Join-Path $script:BIN_DIR $exe
        Set-Content -LiteralPath $candidate -Value 'not a valid executable'
        Mock Find-LocalBinary { return $true }
        Mock Test-ValidExecutable { return $false }
        Install-Checkmake
        Get-Content -LiteralPath $candidate | Should -BeExactly 'not a valid executable'
    }

    It 'registers local module discovery before verifying imports in Main' {
        $main = $script:runnerAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Main'
        }, $true)
        $calls = @($main.Body.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
        [array]::IndexOf($calls, 'Ensure-OfflineModulePath') | Should -BeLessThan ([array]::IndexOf($calls, 'Install-RequiredModules'))
    }
}
