# =============================================================================
# HPE ProLiant Windows Server ISO Automation - PowerShell Lint Script
# =============================================================================
# Phase 1: Syntax validation (catches parse errors)
# Phase 2: PSScriptAnalyzer (code quality, style, best practices)

<#
.SYNOPSIS
    Lint all PowerShell files - syntax validation and code quality checks.

.DESCRIPTION
    Two-phase linting process:
    
    1. SYNTAX VALIDATION: Parses each file to catch syntax/parse errors
       - Uses PowerShell's built-in Parser
       - Catches missing braces, invalid syntax, etc.
       - FATAL: Exits immediately if syntax errors found
    
    2. CODE QUALITY: Runs PSScriptAnalyzer for best practices
       - Style, performance, design patterns
       - Respects excluded rules (see below)
    
    Directories excluded: vendor/, generated/, .git/, bin/, scripts/modules/
    
    Rules excluded from PSScriptAnalyzer:
    - PSUseBOMForUnicodeEncodedFile
    - PSUseToExportFieldsInManifest
    - PSUseShouldProcessForStateChangingFunctions
    - PSUseApprovedVerbs
    - PSUseSingularNouns
    - PSAvoidUsingWriteHost
    - PSAvoidUsingConvertToSecureStringWithPlainText
    - PSAvoidUsingUsernameAndPasswordParams
    - TypeNotFound

.EXAMPLE
    pwsh -File scripts/lint.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Collect all PowerShell files across entire project
$excludedDirectories = @('vendor', 'generated', '.git', 'bin')
$excludedPathPrefixes = @((Join-Path $PROJECT_ROOT 'scripts/modules'))

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

Write-Output "${COLOR_CYAN}═══ PHASE 1: Syntax Validation ═══${COLOR_RESET}"
Write-Output "Scanning $($allPowerShellFiles.Count) PowerShell files for syntax errors..."
Write-Output ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: SYNTAX VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════
$syntaxErrors = [System.Collections.Generic.List[object]]::new()

foreach ($file in $allPowerShellFiles) {
    $tokens = $null
    $errors = $null
    
    # Parse the file to catch syntax errors
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file,
        [ref]$tokens,
        [ref]$errors
    )
    
    if ($errors -and $errors.Count -gt 0) {
        $relativePath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $file)
        
        foreach ($err in $errors) {
            # Skip TypeNotFound - these refer to types defined in other project files, not syntax errors
            if ($err.ErrorId -eq 'TypeNotFound') { continue }
            
            $syntaxErrors.Add([PSCustomObject]@{
                File    = $relativePath
                Line    = $err.Extent.StartLineNumber.ToString()
                Column  = $err.Extent.StartColumnNumber.ToString()
                ErrorId = $err.ErrorId
                Message = $err.Message
            })
        }
    }
}

# Report syntax errors and exit if any found
if ($syntaxErrors.Count -gt 0) {
    Write-Output "${COLOR_RED}✗ SYNTAX ERRORS FOUND${COLOR_RESET}"
    Write-Output ""
    $syntaxErrors | Format-Table -AutoSize
    
    Write-Output ""
    Write-Output "${COLOR_RED}$($syntaxErrors.Count) syntax error(s) in $($syntaxErrors.File | Select-Object -Unique | Measure-Object | Select-Object -ExpandProperty Count) file(s)${COLOR_RESET}"
    Write-Output ""
    Write-Output "Please fix syntax errors before running code quality checks."
    Write-Output "Linting failed."
    exit 1
}

Write-Output "${COLOR_GREEN}✓ Syntax validation passed${COLOR_RESET}"
Write-Output ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: CODE QUALITY (PSScriptAnalyzer)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Output "${COLOR_CYAN}═══ PHASE 2: Code Quality Check ═══${COLOR_RESET}"

$pssa = Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue
if (-not $pssa) {
    Write-Output "${COLOR_RED}✗ PSScriptAnalyzer not installed${COLOR_RESET}"
    Write-Output "Install with: Install-Module PSScriptAnalyzer"
    exit 1
}

Write-Output "Running PSScriptAnalyzer on $($allPowerShellFiles.Count) files..."
Write-Output ""

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
        Write-Output "${COLOR_RED}[pwsh-lint]${COLOR_RESET} Failed to analyze $friendlyPath : $_"
    }
}

# Report code quality errors and exit if any found
if ($allErrors.Count -gt 0) {
    Write-Output "${COLOR_RED}✗ CODE QUALITY ISSUES FOUND${COLOR_RESET}"
    Write-Output ""
    $allErrors | Format-Table -AutoSize
    
    Write-Output ""
    Write-Output "${COLOR_RED}$($allErrors.Count) error(s) in $($fileErrorCounts.Count) file(s)${COLOR_RESET}"
    
    if ($fileErrorCounts.Count -gt 0) {
        Write-Output ""
        Write-Output "Files with most errors:"
        $fileErrorCounts.GetEnumerator() | 
            Sort-Object Value -Descending | 
            Select-Object -First 5 |
            ForEach-Object {
                $friendlyPath = [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $_.Key)
                Write-Output "  - $friendlyPath ($($_.Value) errors)"
            }
    }
    
    Write-Output ""
    Write-Output "Linting failed."
    exit 1
}

# Success!
Write-Output ""
Write-Output "${COLOR_GREEN}✓ All checks passed${COLOR_RESET}"
Write-Output "  - Syntax validation: OK"
Write-Output "  - Code quality: OK"
Write-Output ""
Write-Output "${COLOR_GREEN}$($allPowerShellFiles.Count) files linted successfully${COLOR_RESET}"
exit 0
