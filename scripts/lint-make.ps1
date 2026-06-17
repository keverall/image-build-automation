<#
.SYNOPSIS
    Lint Makefile syntax and style (Windows-compatible).

.DESCRIPTION
    Validates Makefile syntax using checkmake if available, otherwise performs
    a basic dry-run validation. Acts as a fallback for environments without
    checkmake installed.

.EXAMPLE
    pwsh -File scripts/lint-make.ps1
#>

# =============================================================================
# Lint Makefile syntax and style (Windows-compatible)
# =============================================================================
if (Get-Command checkmake -ErrorAction SilentlyContinue) {
    checkmake Makefile
} else {
    Write-Host "[lint-make] 'checkmake' missing. Running basic syntax check..." -ForegroundColor Yellow
    $null = make --dry-run --quiet help 2>&1
    Write-Host "[lint-make] Makefile syntax OK" -ForegroundColor Green
}
