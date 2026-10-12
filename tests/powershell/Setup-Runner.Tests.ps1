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
