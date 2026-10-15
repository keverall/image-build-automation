BeforeAll {
    $script:packageRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts/modules/HPRESTCmdlets/1.2.0.0'
    $script:rootModule = Join-Path $script:packageRoot 'HPRESTCmdlets.psm1'
    $script:licenseScript = Join-Path $script:packageRoot 'ShowLicense.ps1'
}

Describe 'HPRESTCmdlets vendored package - duplicate AsyncPipeline regression' {
    # PowerShell runs ScriptsToProcess (ShowLicense.ps1) BEFORE the RootModule.
    # ShowLicense.ps1 adds AsyncPipeline, so the RootModule's identical Add-Type
    # aborted every import with "Cannot add type. The type name 'AsyncPipeline'
    # already exists" - on a fresh shell too. This is the import blocker.
    It 'defines AsyncPipeline in the license script that runs first' {
        Test-Path -LiteralPath $script:licenseScript | Should -BeTrue
        $licenseContent = Get-Content -LiteralPath $script:licenseScript -Raw
        $licenseContent | Should -Match 'Add-Type'
        $licenseContent | Should -Match 'public class AsyncPipeline'
        # The licensee's acceptance flow must stay present and untouched.
        $licenseContent | Should -Match 'LicenseShown'
        $licenseContent | Should -Match 'License declined so module not loaded'
    }

    It 'guards the RootModule duplicate Add-Type instead of redefining the type' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:rootModule, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        $addTypes = @($ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Add-Type'
        }, $true))

        # Every Add-Type for AsyncPipeline must sit inside a guard that first checks
        # whether the type already exists - an unguarded one re-breaks the import.
        $asyncAdds = @($addTypes | Where-Object {
            $_.Extent.Text -match 'AsyncPipeline'
        })
        $asyncAdds.Count | Should -BeGreaterOrEqual 1

        foreach ($add in $asyncAdds) {
            $ancestor = $add.Parent
            $guarded = $false
            while ($null -ne $ancestor) {
                if ($ancestor -is [System.Management.Automation.Language.IfStatementAst] -and
                    $ancestor.Extent.Text -match "'AsyncPipeline'\s*-as\s*\[type\]") {
                    $guarded = $true
                    break
                }
                $ancestor = $ancestor.Parent
            }
            $guarded | Should -BeTrue -Because 'an unguarded AsyncPipeline Add-Type aborts the import'
        }
    }

    It 'imports successfully when the license script already created the type' {
        # Reproduce the real order a fresh shell sees: ScriptsToProcess runs first,
        # then the root module. Run it in a child process so the type does not leak
        # into the test session. The license script's interactive dialog is bypassed
        # here only because it is not what is under test: the type is added directly.
        $child = Join-Path $TestDrive 'child-import-check.ps1'
        $rootModuleLiteral = $script:rootModule.Replace("'", "''")
        @"
# Simulate ShowLicense.ps1's Add-Type having already run.
Add-Type @'
public class AsyncPipeline
{
    public System.Management.Automation.PowerShell Pipeline ;
    public System.IAsyncResult AsyncResult ;
}
'@

# Now execute the guarded region of the real root module.
`$root = Get-Content -LiteralPath '$rootModuleLiteral' -Raw
`$m = [regex]::Match(`$root, "(?s)if \(-not \('AsyncPipeline' -as \[type\]\)\) \{.*?\n\}\r?\n")
if (-not `$m.Success) { Write-Output 'NO_GUARD_FOUND'; exit 4 }
Invoke-Expression `$m.Value
if ('AsyncPipeline' -as [type]) { Write-Output 'TYPE_OK' } else { Write-Output 'TYPE_MISSING'; exit 5 }
"@ | Set-Content -LiteralPath $child

        $output = & pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $child 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ("child process output: $($output -join ' | ')")
        "$output" | Should -Match 'TYPE_OK'
    }

    It 'does not change the AddressType enum definition' {
        $content = Get-Content -LiteralPath $script:rootModule -Raw
        $content | Should -Match 'public enum AddressType'
        ([regex]::Matches($content, 'Add-Type\s+-TypeDefinition\s+@"\s*public enum AddressType')).Count | Should -Be 1
    }
}
