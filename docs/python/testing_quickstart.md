# Testing Quick Start Guide

Fast reference for running unit tests manually and via Jenkins pipeline.

---

## Manual Testing

### Install & Run All Tests

```bash
# Install package in editable mode
pip install -e .

# Run all tests verbosely
pytest -v

# With coverage report in console
pytest --cov=automation --cov-report=term-missing

# Generate HTML coverage report
pytest --cov=automation --cov-report=html
# Then open: htmlcov/index.html
```

### Run Specific Tests

```bash
# Single file
pytest tests/cli/test_build_iso.py -v

# Single test function
pytest tests/cli/test_build_iso.py::TestISOOrchestrator::test_initialization -v

# By keyword
pytest -k "dry_run" -v
```

### Common Commands

| Goal | Command |
|---|---|
| Failing on low coverage | `pytest --cov=automation --cov-fail-under=80` |
| Parallel execution | `pytest -n auto` (requires pytest-xdist) |
| Stop on first failure | `pytest -x` |
| Show print statements | `pytest -s` |
| Drop to debugger on failure | `pytest --pdb` |

---

## Jenkins Pipeline

### What Gets Run

| Build Type | Tests Run | Coverage Threshold |
|---|---|---|
| PR / Merge Request | Affected tests only (see below) | `0%` (no failure) |
| Full build (main) | All tests in `tests/` | `≥50%` (must pass) |
| Manual parameterized | Based on `BUILD_STAGE` parameter | Configurable |

### PR Incremental Testing Flow

```
┌─────────────────────────────────────────┐
│  PR pushed → Jenkins detects CHANGE_ID  │
├─────────────────────────────────────────┤
│  1. Fetch target branch (e.g., main)    │
│  2. git diff → changed files            │
│  3. Map source → test files             │
│     src/automation/core/x.py  → tests/core/test_x.py │
│     tests/.../*.py            → run directly       │
│  4. Run only those tests                │
└─────────────────────────────────────────┘
```

### Viewing Results

1. Jenkins job → Build → "Unit Tests & Coverage" stage
2. Click **"Tests Result"** to see per-test breakdown (JUnit)
3. Download `coverage.xml` artifact for external reporting
4. (Optional) Cobertura plugin shows coverage trend chart in Jenkins UI

### Typical Output

```
[INFO] PR build: Determining affected tests...
[INFO] Running affected tests: tests/cli/test_build_iso.py, tests/utils/test_executor.py
============================= test session starts ==============================
collected 23 items

tests/cli/test_build_iso.py :: TestISOOrchestrator::test_initialization PASSED
...

---------- coverage: platform linux, python 3.9 ----------
Name                     Stmts   Miss  Cover
--------------------------------------------
automation/cli/build_iso     50      5    90%
automation/utils/audit       80      0   100%
TOTAL                       500    100    80%
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `No module named automation` | Package not installed | `pip install -e .` |
| No tests discovered | Wrong `testpaths` in pytest config | Verify `pyproject.toml` `[tool.pytest.ini_options]` |
| Coverage XML missing | pytest-cov not installed | `pip install pytest-cov` |
| PR runs nothing | CHANGE_TARGET not set | Manually set or check Jenkins Multibranch config |
| Tests hanging | Mock not applied, real external call | Check `patch()` path, ensure correct module path |

---

## Cheatsheets

### Mapping Source → Test

```powershell
# PowerShell one-liner
$src = 'src/automation/cli/build_iso.py'
$test = $src -replace '^src/', 'tests/' -replace '\.py$', '_test.py'
# Result: tests/cli/test_build_iso.py
```

### Coverage Thresholds

```bash
# Loose (CI with incremental runs)
pytest --cov=automation --cov-fail-under=0

# Strict (local development)
pytest --cov=automation --cov-fail-under=80

# Report only, don't fail
pytest --cov=automation --cov-report=term
```

### Copy Tests for New Module

```bash
# Scaffold test file from template
cp tests/template_test.py tests/cli/test_my_new_module.py
sed -i 's/ModuleName/MyNewModule/g' tests/cli/test_my_new_module.py
```

---

## Next Steps

- Full test suite: `pytest -v`
- Review coverage: open `htmlcov/index.html`
- Push PR → view Jenkins "Unit Tests & Coverage" stage
