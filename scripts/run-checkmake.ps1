<#
.SYNOPSIS
    Run checkmake to validate Makefile (Windows-compatible).

.DESCRIPTION
    Validates Makefile syntax using the checkmake tool. If checkmake is not
    installed, the script exits gracefully with a warning message.

.EXAMPLE
    pwsh -File scripts/run-checkmake.ps1
#>

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
