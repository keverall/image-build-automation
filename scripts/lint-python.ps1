<#
.SYNOPSIS
    Lint Python scripts with Ruff (check + autofix), mirroring scripts/lint.ps1.

.DESCRIPTION
    Phase 1 - Autofix: `ruff check --fix` repairs what it can (unused imports,
    import sorting, simple style issues).
    Phase 2 - Verify: `ruff check` re-runs with no fixes so any remaining
    violations are reported and fail the build.

    Ruff resolution order:
      1. `ruff` on PATH
      2. `uv run ruff` (uv-managed environments)
      3. `python -m ruff`
      4. `python -m pip install ruff` (user scope), then fall back to 3.

    Directory exclusions are defined in ruff.toml (vendor, generated, bin,
    scripts/modules). Exit 0 if clean; exit 1 if violations remain or Ruff
    cannot be made available.

.EXAMPLE
    pwsh -File scripts/lint-python.ps1
#>

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

$Green  = "`e[0;32m"
$Cyan   = "`e[0;36m"
$Yel    = "`e[1;33m"
$Red    = "`e[0;31m"
$Reset  = "`e[0m"

Write-Output "${Cyan}═══ PHASE 1: Ruff autofix ═══${Reset}"

# Resolve ruff: pwsh on Linux needs a scalar executable plus a separate args
# array (passing an array as the command stringifies it, e.g. 'uv run ruff').
$ruffExe  = ''
$ruffArgs = @()
if (Get-Command ruff -ErrorAction SilentlyContinue) {
    $ruffExe  = 'ruff'
    $ruffArgs = @()
} elseif (Get-Command uv -ErrorAction SilentlyContinue) {
    $ruffExe  = 'uv'
    $ruffArgs = @('run', 'ruff')
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $ruffExe  = 'python3'
    $ruffArgs = @('-m', 'ruff')
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $ruffExe  = 'python'
    $ruffArgs = @('-m', 'ruff')
} else {
    Write-Output "${Red}✗ No Python/Ruff runtime found${Reset}"
    Write-Output "Install Python 3.8+ (or uv) and Ruff, then re-run."
    exit 1
}

# Confirm ruff is actually runnable; if not, attempt a one-shot user-scope
# install as a fallback.
& $ruffExe @ruffArgs @('--version') 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Output "${Yel}Installing Ruff (user scope)...${Reset}"
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        & uv pip install --user ruff 2>$null
    } elseif ($ruffExe -in @('python3','python')) {
        & $ruffExe -m pip install --user --quiet ruff 2>$null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Output "${Red}✗ Failed to install Ruff${Reset}"
        Write-Output "Install manually:  ruff check --fix scripts/*.py"
        exit 1
    }
}

# Collect Python files the same way ruff would (respects ruff.toml excludes):
# just lint the repo root so ruff.toml's extend-exclude is authoritative.
$pyFiles = Get-ChildItem -Path $PROJECT_ROOT -Recurse -Filter '*.py' -File -Force |
    Where-Object {
        $rel = $_.FullName.Substring($PROJECT_ROOT.Length).TrimStart('/','\')
        $top = ($rel -split '[\\/]+')[0]
        $top -notin @('vendor','generated','bin') -and
        $rel -notmatch '(^|[\\/])scripts[\\/]modules([\\/]|$)'
    } | ForEach-Object { [System.IO.Path]::GetRelativePath($PROJECT_ROOT, $_.FullName) }

if (-not $pyFiles) {
    Write-Output "${Yel}No Python files found to lint${Reset}"
    exit 0
}

Write-Output "Using: $ruffExe $($ruffArgs -join ' ') --version"
Write-Output "Linting $($pyFiles.Count) Python file(s)..."
$pyFiles | ForEach-Object { Write-Output "  - $_" }

# Phase 1: autofix
& $ruffExe @ruffArgs @('check','--fix') @pyFiles
$fixCode = $LASTEXITCODE

# Phase 2: verify (no fixes) so the final state is clean
Write-Output ""
Write-Output "${Cyan}═══ PHASE 2: Ruff verify (no fixes) ═══${Reset}"
& $ruffExe @ruffArgs @('check') @pyFiles
$verifyCode = $LASTEXITCODE

if ($verifyCode -ne 0) {
    Write-Output ""
    Write-Output "${Red}✗ Ruff found remaining violations${Reset}"
    Write-Output "Fix with:  $ruffExe $($ruffArgs -join ' ') check --fix $(($pyFiles -join ' '))"
    exit 1
}

Write-Output ""
Write-Output "${Green}✓ Python lint passed${Reset}"
Write-Output "  - Autofix : OK"
Write-Output "  - Clean   : OK"
Write-Output ""
Write-Output "${Green}$($pyFiles.Count) file(s) linted successfully${Reset}"
exit 0
