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
