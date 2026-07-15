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
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$BIN_DIR      = Join-Path $PROJECT_ROOT 'bin'
$isWin        = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$checkmakeExe = if ($isWin) { 'checkmake.exe' } else { 'checkmake' }

$checkmake = $null
foreach ($candidate in @((Join-Path $BIN_DIR $checkmakeExe), $checkmakeExe)) {
    if (Test-Path $candidate) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
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

if (-not $checkmake) {
    Write-Host "[checkmake] Not installed (install with: make setup)" -ForegroundColor Yellow
    exit 0
}

Write-Output "[checkmake] Validating Makefile..."
try {
    $output = & $checkmake Makefile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[checkmake] No issues found" -ForegroundColor Green
    } else {
        Write-Host "[checkmake] Issues detected:" -ForegroundColor Yellow
        Write-Output $output
    }
} catch {
    Write-Host "[checkmake] Issues detected: $_" -ForegroundColor Yellow
}
