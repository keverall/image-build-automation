# =============================================================================
# Run checkmake to validate Makefile (Windows-compatible)
# =============================================================================
if (-not (Get-Command checkmake -ErrorAction SilentlyContinue)) {
    Write-Host "[checkmake] Not installed (install with: make setup)" -ForegroundColor Yellow
    exit 0
}

Write-Host "[checkmake] Validating Makefile..."
try {
    $output = checkmake Makefile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[checkmake] No issues found" -ForegroundColor Green
    } else {
        Write-Host "[checkmake] Issues detected:" -ForegroundColor Yellow
        Write-Host $output
    }
} catch {
    Write-Host "[checkmake] Issues detected: $_" -ForegroundColor Yellow
}
