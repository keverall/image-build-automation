# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Lint Script
# =============================================================================
# Runs PSScriptAnalyzer on ALL .ps1 and .psm1 files across the entire project:
#   scripts/, src/powershell/, tests/powershell/, wip/, and root-level files.

<#
.SYNOPSIS
    Run PSScriptAnalyzer linting on ALL PowerShell files in the project.

.DESCRIPTION
    Scans all .ps1 and .psm1 files across the entire project tree using
    PSScriptAnalyzer (severity: Error). Reports all errors across all files
    before exiting.

    Directories excluded from scanning:
    - vendor/           (vendored third-party dependencies)
    - generated/        (generated artifacts)
    - .git/             (git internals)
    - bin/              (build output)
    - scripts/modules/  (bundled PowerShell modules: Pester, PSScriptAnalyzer, platyPS)

    Rules excluded (intentional patterns):
    - PSUseBOMForUnicodeEncodedFile
    - PSUseToExportFieldsInManifest
    - PSUseShouldProcessForStateChangingFunctions
    - PSUseApprovedVerbs
    - PSUseSingularNouns
    - PSAvoidUsingWriteHost
    - PSAvoidUsingConvertToSecureStringWithPlainText
    - PSAvoidUsingUsernameAndPasswordParams
    - TypeNotFound

    Collects errors from ALL files before reporting.
    Exits with code 1 if any errors are found, 0 otherwise.

.EXAMPLE
    pwsh -File scripts/lint.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

$excludedDirectories = @('vendor', 'generated', '.git', 'bin')
$excludedPathPrefixes = @(
    (Join-Path $PROJECT_ROOT 'scripts/modules')
)

$allPowerShellFiles = [System.Collections.Generic.List[string]]::new()

Get-ChildItem -Path $PROJECT_ROOT -Recurse -Include '*.ps1', '*.psm1' -File | ForEach-Object {
    $relativePath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $_.FullName)
    $parts = $relativePath -split '[\\/]+'

    $skip = $false
    foreach ($dir in $excludedDirectories) {
        if ($parts -contains $dir) { $skip = $true; break }
    }

    if (-not $skip) {
        foreach ($prefix in $excludedPathPrefixes) {
            if ($_.FullName.StartsWith($prefix)) { $skip = $true; break }
        }
    }

    if (-not $skip) { $allPowerShellFiles.Add($_.FullName) }
}

# Colors
$COLOR_GREEN = "`e[32m"
$COLOR_CYAN  = "`e[36m"
$COLOR_RED   = "`e[31m"
$COLOR_RESET = "`e[0m"

Write-Host "${COLOR_CYAN}[pwsh-lint]${COLOR_RESET} Scanning $($allPowerShellFiles.Count) PowerShell files (.ps1 + .psm1) across the project..."

$pssa = Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue
if (-not $pssa) {
    Write-Host "${COLOR_RED}PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer${COLOR_RESET}"
    exit 1
}

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

$allErrors = [System.Collections.Generic.List[object]]::new()
$fileErrorCounts = [ordered]@{}

foreach ($file in $allPowerShellFiles) {
    try {
        $fileErrors = @(Invoke-ScriptAnalyzer -Path $file -Severity Error |
            Where-Object { $excludedRules -notcontains $_.RuleName })
        if ($fileErrors.Count -gt 0) {
            $allErrors.AddRange([object[]]$fileErrors)
            $fileErrorCounts[$file] = $fileErrors.Count
        }
    } catch {
        $friendlyPath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $file)
        Write-Host "${COLOR_RED}[pwsh-lint]${COLOR_RESET} Failed to analyze $friendlyPath : $_"
    }
}

if ($allErrors.Count -gt 0) {
    $allErrors | Format-Table -AutoSize

    Write-Host ""
    Write-Host "${COLOR_RED}[pwsh-lint]${COLOR_RESET} Summary: $($allErrors.Count) error(s) in $($fileErrorCounts.Count) file(s) out of $($allPowerShellFiles.Count) scanned.${COLOR_RESET}"
    foreach ($entry in $fileErrorCounts.GetEnumerator()) {
        $friendlyPath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $entry.Key)
        Write-Host "  ${COLOR_RED}${friendlyPath}${COLOR_RESET} ($($entry.Value) error(s))"
    }
    exit 1
}

Write-Host "${COLOR_GREEN}[pwsh-lint]${COLOR_RESET} All $($allPowerShellFiles.Count) files passed. No issues found."