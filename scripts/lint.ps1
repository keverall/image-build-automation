# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Lint Script
# =============================================================================
# Runs PSScriptAnalyzer on all project PowerShell files.

<#
.SYNOPSIS
    Run PSScriptAnalyzer linting on PowerShell source code.

.DESCRIPTION
    Scans all PowerShell files in the project using PSScriptAnalyzer.
    Excludes vendored dependencies and generated artifacts.
    Excludes rules that flag intentional patterns (embedded scripts, credentials in scripts, etc.).
    
    Excluded rules:
    - PSUseBOMForUnicodeEncodedFile
    - PSUseToExportFieldsInManifest
    - PSUseShouldProcessForStateChangingFunctions
    - PSUseApprovedVerbs
    - PSUseSingularNouns
    - PSAvoidUsingWriteHost
    - PSAvoidUsingConvertToSecureStringWithPlainText
    - PSAvoidUsingUsernameAndPasswordParams
    - TypeNotFound
    
    Exits with code 1 if errors are found.

.EXAMPLE
    pwsh -File scripts/lint.ps1
#>

#
# Usage:
#   pwsh -File scripts/lint-pwsh.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$excludedDirectories = @('vendor', 'generated', '.git', 'bin')
$allPowerShellFiles = Get-ChildItem -Path $PROJECT_ROOT -Recurse -Filter '*.ps1' -File |
    Where-Object {
        $relativePath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $_.FullName)
        $parts = $relativePath -split '[\\/]+'
        $null -eq ($parts | Where-Object { $excludedDirectories -contains $_ })
    } |
    Select-Object -ExpandProperty FullName

# Colors
$COLOR_GREEN = "`e[32m"
$COLOR_CYAN  = "`e[36m"
$COLOR_RED   = "`e[31m"
$COLOR_RESET = "`e[0m"

Write-Host "${COLOR_CYAN}[pwsh-lint]${COLOR_RESET} Scanning $($allPowerShellFiles.Count) PowerShell files across the project..."

$pssa = Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue
if (-not $pssa) {
    Write-Host "${COLOR_RED}PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer${COLOR_RESET}"
    exit 1
}

# Exclude rules that flag intentional patterns (embedded scripts, credentials in scripts, etc.)
$excludedRules = @(
    'PSUseBOMForUnicodeEncodedFile',
    'PSUseToExportFieldsInManifest',
    'PSUseShouldProcessForStateChangingFunctions',
    'PSUseApprovedVerbs',
    'PSUseSingularNouns',
    'PSAvoidUsingWriteHost',
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    'PSAvoidUsingUsernameAndPasswordParams',
    'TypeNotFound'
)

$errors = $allPowerShellFiles | ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_ -Severity Error
} | Where-Object { $excludedRules -notcontains $_.RuleName }

if ($errors) {
    $errors | Format-Table -AutoSize
    exit 1
}

Write-Host "${COLOR_GREEN}[pwsh-lint]${COLOR_RESET} No issues found"