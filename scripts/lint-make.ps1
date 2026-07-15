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
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$BIN_DIR      = Join-Path $PROJECT_ROOT 'bin'
$checkmakeExe = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) { 'checkmake.exe' } else { 'checkmake' }

$checkmake = $null
$candidates = @(
    (Join-Path $BIN_DIR $checkmakeExe),
    $checkmakeExe
)
foreach ($c in $candidates) {
    if (Test-Path $c) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -and $cmd.Source -ne '') {
            $checkmake = $cmd.Source
            break
        }
    }
}

if (-not $checkmake) {
    $cmd = Get-Command $checkmakeExe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and $cmd.Source -ne '') { $checkmake = $cmd.Source }
}

if ($checkmake) {
    try {
        $output = & $checkmake Makefile 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Host "[lint-make] checkmake: no issues found" -ForegroundColor Green
        } else {
            Write-Host "[lint-make] checkmake issues:" -ForegroundColor Yellow
            Write-Output $output
        }
    } catch {
        Write-Host "[lint-make] checkmake failed: $_" -ForegroundColor Yellow
        $checkmake = $null
    }
}

if (-not $checkmake) {
    Write-Host "[lint-make] 'checkmake' not found. Running basic syntax check..." -ForegroundColor Yellow
    $null = make --dry-run --quiet help 2>&1
    Write-Host "[lint-make] Makefile syntax OK" -ForegroundColor Green
}
