# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Lint Script
# =============================================================================
# Runs PSScriptAnalyzer on PowerShell source files.
#
# Usage:
#   pwsh -File scripts/lint-pwsh.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$PSDIRS = Join-Path $PROJECT_ROOT 'src/powershell'

# Colors
$COLOR_GREEN = "`e[32m"
$COLOR_CYAN  = "`e[36m"
$COLOR_RED   = "`e[31m"
$COLOR_RESET = "`e[0m"

Write-Host "${COLOR_CYAN}[pwsh-lint]${COLOR_RESET} Running PSScriptAnalyzer..."

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

$errors = Invoke-ScriptAnalyzer -Path $PSDIRS -Recurse -Severity Error |
    Where-Object { $excludedRules -notcontains $_.RuleName }

if ($errors) {
    $errors | Format-Table -AutoSize
    exit 1
}

Write-Host "${COLOR_GREEN}[pwsh-lint]${COLOR_RESET} No issues found"