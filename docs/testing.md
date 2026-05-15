# Unit Testing & Code Coverage Guide

Complete guide to running unit tests manually and via the Jenkins CI/CD pipeline, including code coverage reporting, PR incremental testing, and troubleshooting.

---

## Table of Contents

1. [Overview](#overview)
2. [Code Coverage Configuration](#code-coverage-configuration)
3. [Manual Unit Testing](#manual-unit-testing)
4. [Jenkins CI/CD Integration](#jenkins-cicd-integration)
5. [Quick Start: Manual Testing](#quick-start-manual-testing)
6. [Quick Start: Jenkins Pipeline](#quick-start-jenkins-pipeline)
7. [Understanding Coverage Reports](#understanding-coverage-reports)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The project uses **pytest** for comprehensive unit testing of all code in `src/automation/` and its subfolders. Tests are located in `tests/` mirroring the package structure (e.g., `src/automation/cli/build_iso.py` → `tests/cli/test_build_iso.py`). Code coverage is measured with **pytest-cov** and reported in multiple formats (terminal, XML, HTML).

**Key Features**
- Automated test discovery via pytest
- Strict import isolation via `conftest.py` (adds `src/` to `sys.path`)
- Mocking for external dependencies (`subprocess`, `requests`, file I/O)
- Fixtures for temporary directories (`tmp_path`) and sample data
- CI integration with JUnit XML test results and coverage.xml
- PR incremental testing (runs only affected tests, similar to turbo/nx)

---

## Code Coverage Configuration

Coverage settings are defined in `pyproject.toml` under `[tool.pytest.ini_options]`:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = """
    --verbose
    --cov=automation
    --cov-report=term-missing
    --cov-report=xml
    --cov-report=html
    --cov-fail-under=50
"""
```

- `--cov=automation` — measures coverage for the `automation` package (everything under `src/automation/`)
- `--cov-report=term-missing` — shows missing line numbers in console output
- `--cov-report=xml` — generates `coverage.xml` for CI/CD tooling and PR comments
- `--cov-report=html` — generates `htmlcov/` directory with a browsable interactive report
- `--cov-fail-under=50` — fails if overall coverage drops below 50% (can be overridden via CLI)

> **Note**: In Jenkins PR builds, the coverage threshold is set to `0` to avoid failing on partial coverage during incremental testing. Full builds enforce the `≥50%` threshold.

---

## Manual Unit Testing

### Prerequisites

```bash
# Install development dependencies (includes pytest, pytest-cov)
pip install -r requirements.txt

# Installation in editable mode (adds src/ to package path automatically)
pip install -e .
```

### Running Tests

**Run the entire test suite:**
```bash
pytest
# or
python -m pytest
```

**Run tests for a specific module:**
```bash
pytest tests/cli/test_build_iso.py -v
```

**Run tests matching a name pattern:**
```bash
pytest -k "test_build" -v
```

**Run tests with marshalled coverage (displays line numbers of missing coverage):**
```bash
pytest --cov=automation --cov-report=term-missing
```

**Generate HTML coverage report:**
```bash
pytest --cov=automation --cov-report=html
# Then open htmlcov/index.html in a browser
```

**Adjust coverage threshold:**
```bash
pytest --cov=automation --cov-fail-under=80  # require 80% coverage
```

**Parallel test execution (optional, if pytest-xdist installed):**
```bash
pip install pytest-xdist
pytest -n auto  # runs in parallel across CPU cores
```

### Test Structure

Each module mirrors the package structure:

```
tests/
├── cli/
│   ├── test_build_iso.py
│   ├── test_generate_uuid.py
│   ├── test_maintenance_mode.py
│   ├── test_opsramp_integration.py
│   ├── test_patch_windows_security.py
│   └── test_update_firmware_drivers.py
├── core/
│   ├── test_orchestrator.py
│   ├── test_router.py
│   └── test_validators.py
└── utils/
    ├── test_audit.py
    ├── test_base.py
    ├── test_config.py
    ├── test_credentials.py
    ├── test_executor.py
    ├── test_file_io.py
    ├── test_inventory.py
    ├── test_logging_setup.py
    └── test_powershell.py
```

### Common Fixtures (defined in `tests/conftest.py`)

- `tmp_path` — isolated temporary directory for filesystem operations
- `sample_config` — sample JSON config dict
- `sample_cluster_catalogue` — sample cluster definitions
- `sample_inventory_data` — sample servers list

### Isolation

- All imports are mocked using `unittest.mock` (`patch`, `MagicMock`)
- External calls (subprocess, HTTP requests, file reads) are replaced with mocks
- Each test runs in a fresh temporary directory

---

## Jenkins CI/CD Integration

### Pipeline Changes

The Jenkinsfile was enhanced to add **Unit Tests & Coverage** stage after the **Code Quality & Security Scan** stage and before **Generate UUIDs**. This provides early feedback on PRs before long-running build steps.

#### Stage Placement

```groovy
stage('Code Quality & Security Scan') { ... }

stage('Unit Tests & Coverage') {  // New stage added
    steps { powershell ''' ... ''' }
    post {
        always { junit 'test-results.xml' }
        failure { ... }
    }
}

stage('Generate UUIDs') { ... }
```

#### PR Incremental Testing (Turbo/Nx-style)

On pull request builds (when `CHANGE_ID` environment variable is set), only affected tests are executed:

1. Determine the target branch (`CHANGE_TARGET`, defaults to `main`)
2. Fetch target branch: `git fetch origin $target`
3. Get changed files: `git diff --name-only origin/$target...HEAD`
4. For each changed file:
   - If it's a test file (`tests/*.py`) → add directly
   - If it's source (`src/automation/*.py`) → map to corresponding test file:
     - `src/automation/cli/build_iso.py` → `tests/cli/test_build_iso.py`
     - `src/automation/utils/executor.py` → `tests/utils/test_executor.py`
     - etc.
5. Run only the collected test files
6. If no tests detected, write empty JUnit report and exit 0 (no failure)

**Full builds** (direct pushes to main or parameterized builds) run all tests in `tests/` directory.

#### Coverage Reporting

- **JUnit XML:** `test-results.xml` — consumed by Jenkins JUnit plugin for test trend charts
- **Coverage XML:** `coverage.xml` — can be published by Jenkins Cobertura plugin or archived as artifact
- **Console output:** `--cov-report=term-missing` prints per-file missing line numbers

#### Artifact Archiving

```groovy
post {
    always {
        junit 'test-results.xml'
        archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
    }
}
```

#### Email Notifications

On test failures: dev-team@yourcompany.com receives immediate alert with build number.

#### Dependency Installation

The stage ensures pytest and pytest-cov are installed:

```powershell
pip install pytest pytest-cov
```

---

## Quick Start: Manual Testing

### 1. Run All Tests

```bash
pytest -v
```

### 2. Run a Single Test File

```bash
pytest tests/cli/test_build_iso.py -v
```

### 3. Run a Single Test Function

```bash
pytest tests/cli/test_build_iso.py::TestISOOrchestrator::test_initialization -v
```

### 4. Check Coverage (Console)

```bash
pytest --cov=automation --cov-report=term-missing
```

### 5. Generate HTML Coverage Report

```bash
pytest --cov=automation --cov-report=html
# Open htmlcov/index.html in your browser
```

### 6. Run Coverage + Enforce Threshold

```bash
pytest --cov=automation --cov-report=term --cov-fail-under=80
```

### 7. Common Issues & Fixes

| Issue | Fix |
|---|---|
| Import errors (`No module named automation`) | Ensure you ran `pip install -e .` in the virtual environment |
| Permission errors on Windows | Run PowerShell as Administrator or install Python with user privileges |
| Missing fixtures | Ensure `conftest.py` is in `tests/` directory and up-to-date |
| Coverage XML not generated | Install `pytest-cov`: `pip install pytest-cov` |
| Tests hanging on network calls | Verify mocks are applied; check `patch()` paths |

### 8. Lint the Test Code

```bash
ruff check tests/ --fix
```

---

## Quick Start: Jenkins Pipeline

### For Developers (PR Authors)

Push your changes to a feature branch and open a pull request. Jenkins automatically:

1. Detects it's a PR (via `CHANGE_ID` env var)
2. Determines affected source files (`src/automation/**/*.py`)
3. Maps to corresponding test files (`tests/**/test_*.py`)
4. Runs only those affected tests
5. Publishes JUnit results and coverage report

**View results:**

- Jenkins job page → "Unit Tests & Coverage" stage
- Click the stage to see console output
- "Tests Result" link shows per-test breakdown
- "Coverage Report" artifact (if published via Cobertura plugin)

**Force full test run (if needed):** Add `BUILD_STAGE=all` in manual build parameters.

### For Administrators (Pipeline Configuration)

#### Prerequisites on Jenkins Agent

- Windows agent with Python 3.9+ on PATH
- Virtual environment with project dependencies installed
- Git installed (for `git fetch` and `git diff`)

**Recommended setup script:**

```powershell
# Create venv once (cached between builds)
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\pip install -e .
.\.venv\Scripts\pip install pytest pytest-cov ruff radon bandit safety
```

Ensure workspace persistence or restore from cache to avoid reinstalling each build.

#### Cobertura Plugin (Optional)

To view coverage trends in Jenkins UI:

1. Install **Cobertura Plugin**
2. In Jenkins job configuration → Post-build Actions → "Publish Cobertura Coverage Report"
3. Set "Cobertura xml report pattern" to `**/coverage.xml`
4. Enable "Record only stable builds" to avoid flood

#### JUnit Plugin (Auto-installed)

Publishes test results from `test-results.xml`. Configured automatically via `junit 'test-results.xml'` in the pipeline.

#### Email Notification

Configure Jenkins SMTP and update the email addresses in `Jenkinsfile`:

```groovy
mail to: 'dev-team@yourcompany.com', ...
```

---

## Understanding Coverage Reports

### Coverage.xml (Cobertura format)

- Parsed by Jenkins Cobertura plugin to display trend charts
- Shows per-package coverage (%)
- Used by PR decoration tools to show coverage delta

### htmlcov/index.html (Interactive)

Open in browser to explore:

- Per-file line-by-line highlighting (green = covered, red = missing)
- Overall % covered
- Missing line numbers
- Excluded files (if configured)

### Console Output (`--cov-report=term-missing`)

Example:
```
Name                     Stmts   Miss  Cover
--------------------------------------------
automation/cli/build_iso    50      5    90%
automation/utils/audit      80      0   100%
...
TOTAL                       500    100    80%
```

---

## PR Incremental Testing Deep Dive

### How It Works

```powershell
$isPR = $env:CHANGE_ID -ne $null -and $env:CHANGE_ID -ne ''
if ($isPR) {
    $target = $env:CHANGE_TARGET
    if ([string]::IsNullOrWhiteSpace($target)) { $target = "main" }
    git fetch origin $target 2>$null
    $changed = git diff --name-only origin/$target...HEAD
    # Determine tests for each changed source file
    ...
}
```

### File Mapping Strategy

| Changed source file | Corresponding test file |
|---|---|
| `src/automation/cli/build_iso.py` | `tests/cli/test_build_iso.py` |
| `src/automation/core/orchestrator.py` | `tests/core/test_orchestrator.py` |
| `src/automation/utils/executor.py` | `tests/utils/test_executor.py` |
| `tests/cli/test_build_iso.py` (modified) | runs directly |

If a source file is changed but no corresponding test exists, a notice is logged but the build continues.

### Benefits

- Faster PR feedback (tests only for impacted modules)
- Encourages test-driven development (modifying a file → run its test)
- Scales well in large codebases

### Limitations

- Test utilities (shared fixtures) not automatically detected if only conftest.py changes
- Cross-module integration tests may be skipped if only an indirect dependency changed

**Workaround:** For changes affecting many modules (e.g., `automation/utils/base.py`), consider:

- Adding `[ci skip]` to commit message to run full pipeline on a separate branch, or
- Manually triggering a full build with `BUILD_STAGE=all`

---

## Troubleshooting

### "No module named 'automation'" on local run

```bash
# Fix: install in editable mode (changes to src/ are immediately reflected)
pip install -e .
```

### Import errors in tests due to sys.path

`tests/conftest.py` adds `src/` to `sys.path`. Ensure it's present:

```python
import sys
from pathlib import Path
project_root = Path(__file__).resolve().parent.parent
src_path = project_root / "src"
sys.path.insert(0, str(src_path))
```

### "ImportError: cannot import name 'X' from 'automation.cli.build_iso'"

Ensure `build_iso.py` explicitly contains `def iso_main():` (or whichever symbol) and it's exported via `__all__` in `src/automation/cli/__init__.py`.

### Coverage report not generated

Install pytest-cov:

```bash
pip install pytest-cov
```

### Tests fail on Windows agent due to path separators

Test code uses `pathlib.Path` and `os.path` which are OS-aware. Avoid hard-coded `/` separators; use `Path()` or `os.path.join()`.

### Jenkinsfile syntax errors

Pipeline uses declarative syntax; ensure:
- No tabs (use spaces)
- Proper indentation (2 spaces per level)
- `script {}` blocks only inside `steps {}`
- No Windows-specific commands inside `bash` blocks

### Incremental testing runs nothing on PR

Check environment variables in Jenkins:
- `CHANGE_ID` should be set
- `CHANGE_TARGET` should be the target branch (e.g., `main`)

Add debug output:

```powershell
Write-Host "CHANGE_ID=$env:CHANGE_ID, CHANGE_TARGET=$env:CHANGE_TARGET"
```

### Slow test runs

- Use `pytest-xdist` for parallelization: `pip install pytest-xdist` then `pytest -n auto`
- Ensure isolated test fixtures (`tmp_path`) are cleaned automatically
- Mock heavy external dependencies (SUT, DISM, network)

---

## Additional Resources

- **pytest docs:** https://docs.pytest.org/
- **pytest-cov docs:** https://pytest-cov.readthedocs.io/
- **Jenkins JUnit plugin:** https://plugins.jenkins.io/junit/
- **Jenkins Cobertura plugin:** https://plugins.jenkins.io/cobertura/

---

## Summary

| Task | Command |
|---|---|
| Run all tests | `pytest` |
| Run file-specific tests | `pytest tests/cli/test_build_iso.py` |
| Run coverage with report | `pytest --cov=automation --cov-report=term-missing` |
| Generate HTML coverage | `pytest --cov=automation --cov-report=html` |
| Lint test code | `ruff check tests/ --fix` |
| Jenkins full build | Trigger with `BUILD_STAGE=all` |
| Jenkins PR incremental | Automatic on PR open/update |

