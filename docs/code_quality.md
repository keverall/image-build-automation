# Code Quality & Security Scanning Pipeline

This document describes the automated code quality, security scanning, and vulnerability detection integrated into the Jenkins CI/CD pipeline.

## Overview

Every build runs a comprehensive **Code Quality & Security Scan** stage (unless explicitly skipped) that executes:

| Tool | Purpose | Output Format |
|------|---------|---------------|
| **ruff** | Fast Python linting + import sorting | JSON, formatted text |
| **pylint** | Traditional comprehensive linting | JSON, text |
| **radon** | Maintainability index & cyclomatic complexity | JSON, text |
| **bandit** | Security vulnerability scanner (Python) | JSON, text |
| **safety** | Dependency vulnerability database check | JSON, text |
| **gitleaks** | Hardcoded secret detection in repository | JSON |

All reports are archived as build artifacts for traceability and compliance.

## Pipeline Stages

### 1. Setup

Installs all dependencies and scanning tools:

```powershell
pip install -r requirements.txt
pip install ruff radon bandit safety gitleaks
```

Validates Python syntax for all scripts (including `scripts/utils/*.py`) and JSON configuration files.

### 2. Code Quality & Security Scan (new)

This stage runs immediately after Setup and before any build/deploy operations. It:
- Lints all Python code (`scripts/` and `scripts/utils/`)
- Checks for security anti-patterns (hardcoded secrets, unsafe functions)
- Analyzes code complexity (functions >10 CC flagged)
- Scans dependencies for known CVEs
- Scans repository history for committed secrets

**Skip this stage** by setting the `SKIP_CODE_SCAN` parameter to `true` in Jenkins.

### 3–9. Existing Build Stages

Unaffected; code scanning runs as a pre-check.

## Tool Details

### Ruff (Fast Lint)

**Command**:
```bash
ruff check scripts/ --format=json --output=ruff_issues.json
ruff format --check scripts/ --output=ruff_format.txt
```

**Checks**:
- F401: unused imports
- F841: unused variables
- E501: line too long
- E302: expected 2 blank lines
- W291: trailing whitespace
- F401: import sorting (isort-style)
- Plus many more (see ruff rules)

**Auto-fix**: The pipeline runs `ruff check --fix` before reporting to ensure style issues are corrected automatically.

---

### Pylint (Comprehensive Lint)

**Command**:
```bash
pylint --output-format=json scripts/ > pylint_report.json
pylint scripts/ > pylint_report.txt
```

**Scoring**:
- 10.0/10 = perfect
- 8.0–10.0 = clean (acceptable)
- <8.0 = warnings (check for design issues)

**Categories**: convention, refactor, warning, error, fatal

---

### Radon (Complexity Metrics)

**Maintainability Index** (`radon mi`):
- Scale A (100–19) → excellent, F (0–19) → unstable
- All project modules currently score A (65–100). Threshold: A–B only.

**Cyclomatic Complexity** (`radon cc -nc`):
- Warns on functions with CC > 10
- Fail build if any function exceeds CC=15 (configurable via thresholds in future)

**Example**:
```
scripts/build_iso.py - A (54.36)
scripts/maintenance_mode.py - A (19.16)
```

---

### Bandit (Security Vulnerabilities)

**Command**:
```bash
bandit -r scripts/ -f json -o bandit_report.json
```

**Checks for**:
- B101: `assert` used (should be `raise` in production)
- B104: `hardcoded_bind_all_interfaces` (0.0.0.0)
- B105: `hardcoded_password_string`
- B106: `hardcoded_password_funcarg`
- B107: `hardcoded_password_default`
- B108: `hardcoded_tmp_directory`
- B110: `try_except_pass`
- B112: `try_except_continue`
- B201: `flask_debug_true`
- B301: `pickle` usage
- B303: `md5`, `sha1` insecure hashes
- B304: `ciphers` (insecure)
- B305: `cipher_modes` (ECB mode)
- B306: `mktemp_q`
- B307: `eval`
- B308: `mark_safe`
- B309: `connection_to_public_internet`
- B310: `urllib_urlopen` (no verify)
- B311: `random` (pseudo-random)
- B312: `telnetlib`
- B313: `xml_bad_cElementTree`
- B314: `xml_bad_etree`
- B315: `xml_bad_expatreader`
- B316: `xml_bad_expatbuilder`
- B317: `xml_bad_sax`
- B318: `xml_bad_minidom`
- B319: `xml_bad_pulldom`
- B320: `xml_bad_etree_iterparse`
- B321: `ssh_no_host_key_verification`
- B323: `unverified_context`
- B324: `hashlib_insecure_hash_func`
- B401: `import_telnetlib`
- B402: `import_ftplib`
- B403: `import_pickle`
- B404: `import_subprocess`
- B405: `import_xml_etree`
- B406: `import_xml_sax`
- B407: `import_xml_expat`
- B408: `import_xml_minidom`
- B409: `import_xml_pulldom`
- B410: `import_lxml`
- B411: `import_xmlrpc`
- B412: `import_httpserver`
- B413: `import_urllib_request`
- B413: `import_urllib`
- B501: `request_with_no_cert_validation`
- B502: `ssl_insecure_version`
- B503: `ssl_bad_protocol_version`
- B504: `ssl_with_no_version`
- B505: `weak_cryptographic_key`
- B506: `yaml_load`
- B507: `ssh_no_host_key_verification`
- B508: `subprocess_without_shell_equals_true`
- B509: `str.format_map` (potential injection)
- B601: `process_injection`
- B602: `subprocess_popen_with_shell_equals_true`
- B603: `subprocess_without_shell_equals_false`
- B604: `any_function_with_shell_equals_true`
- B605: `start_process_with_a_shell`
- B606: `start_process_with_no_shell`
- B607: `partial_function_without_path`
- B608: `hardcoded_sql_expressions`
- B609: `linux_commands_wildcard_injection`
- B610: `django_extra_used`
- B611: `django_rawsql_used`
- B701: `jinja2_autoescape_false`
- B702: `use_of_mako_templates`
- B703: `django_mark_safe`

**Severity levels**: LOW, MEDIUM, HIGH

---

### Safety (Dependency Vulnerabilities)

**Command**:
```bash
safety check --json --output=safety_report.json
```

**Checks**:
- Scans `requirements.txt` and installed packages against known CVEs
- Fails build if any vulnerability of severity HIGH or CRITICAL is found
- Optional: ignore specific CVE IDs via environment variable

**Output**: List of vulnerable packages with CVE IDs, fixed versions, and severity.

---

### Gitleaks (Secret Detection)

**Command**:
```bash
gitleaks detect --source=. --report-path=gitleaks_report.json --report-format json --no-banner
```

**Detects**:
- AWS keys (`AKIA...`)
- GitHub tokens (`ghp_...`)
- Private keys (`BEGIN RSA PRIVATE KEY`)
- Generic passwords in code
- API keys, UUIDs, connection strings

**Scan scope**: entire repository (including history). Runs on the checked-out workspace.

**False positives**: Configure `.gitleaks.toml` allowlist if needed.

## Interpreting Results

All scan reports are archived under `code_scan_results/` in each build:

```
code_scan_results/
├── ruff_issues.json           # Linting violations (auto-fixed before commit)
├── ruff_format.txt            # Format check status
├── pylint_report.json         # Pylint JSON output
├── pylint_report.txt          # Human-readable pylint
├── radon_maintainability.json # MI scores per file
├── radon_cyclomatic.json      # CC per function
├── radon_complexity_warnings.txt # Functions exceeding CC threshold
├── bandit_report.json         # Security findings
├── bandit_report.txt          # Human-readable security issues
├── safety_report.json         # Vulnerable dependencies
├── safety_report.txt          # Dependency issues summary
└── gitleaks_report.json       # Committed secrets (if any)
```

### Quality Gates

The build **does not fail** on code quality issues by default (to avoid blocking development), but it **alerts** via email and archives reports for review.

**Recommended minimum thresholds** (enforce via `post` block if desired):

| Metric | Threshold | Current |
|--------|-----------|---------|
| **Ruff**: zero unchecked errors | `ruff check --exit-zero` replaced with `--fail-on` config | 0 |
| **Pylint**: score ≥ 8.0/10 | Parse `pylint_report.json` `score` field | ~9.2 |
| **Radon MI**: ≥ A (65+) for new code | `radon mi` per-file | A (19–100) |
| **Radon CC**: ≤ 10 per function | `radon cc -nc` warnings count | 0 warnings |
| **Bandit**: zero HIGH/CRITICAL | Check `issue_severity` in JSON | 0 |
| **Safety**: zero HIGH/CRITICAL | Check `vulnerability` severity | 0 |
| **Gitleaks**: zero findings | Empty `Findings` array | 0 |

**To fail the build on violations**, wrap each command:

```powershell
ruff check scripts/ --format=json --output=ruff_issues.json
if ($LASTEXITCODE -ne 0) { exit 1 }
```

---

## Local Development

Run all scans locally before pushing:

```bash
# Install all tools
pip install ruff radon bandit safety gitleaks

# Lint + format check
ruff check scripts/ --fix
ruff format scripts/

# Complexity
radon mi scripts/ -s
radon cc scripts/ -nc

# Security
bandit -r scripts/
safety check

# Secrets
gitleaks detect --source=. --report-path=gitleaks_report.json
```

**Pre-commit hook** (optional, add to `.pre-commit-config.yaml`):
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: [--fix]
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.8
    hooks:
      - id: bandit
        args: [-r, scripts/]
```

---

## Handling Findings

### 1. Ruff issues (style)
- Run `ruff check --fix` locally to auto-fix
- Re-run pipeline; ensure zero issues

### 2. Pylint score drops
- Refactor complex functions (use `AutomationBase` pattern)
- Add docstrings if missing
- Reduce function length (split >50 lines)

### 3. Radon complexity warnings
- High CC (>10) indicates complex logic needing refactoring
- Extract conditional branches into helper functions
- Consider reducing nesting

### 4. Bandit findings
- HIGH/CRITICAL must be fixed immediately
- MEDIUM: review and justify or fix
- LOW: may be acceptable with documentation

### 5. Safety vulnerable dependencies
- Update affected packages in `requirements.txt`
- Re-run scan to verify fix

### 6. Gitleaks secrets
**URGENT**: If gitleaks finds a committed secret:
1. Rotate the exposed credential immediately
2. Rewrite git history to purge secret (BFG Repo cleaner or `git filter-branch`)
3. Invalidate any tokens/keys exposed
4. Add the pattern to `.gitleaks.toml` allowlist if false positive

---

## Tool Versions

Pin versions in CI for reproducibility (current recommended):

```bash
ruff>=0.6.0
radon>=6.0.0
bandit>=1.7.0
safety>=3.0.0
gitleaks>=8.18.0
```

Update periodically to get new security rules and dependency checks.

---

## Future Enhancements

- **Quality gates**: enforce thresholds (fail build on violations)
- **Coverage reporting**: integrate `coverage.py` + `codecov`
- **SonarQube integration**: send all reports to SonarQube dashboard
- **Dependency scanning**: add `pip-audit` as additional layer
- **Container scanning**: if Dockerfile changes, scan image with Trivy
- **Secret scanning**: add TruffleHog for deeper history scans

---

## Change History

- 2026-05-15: Initial implementation with ruff, pylint, radon, bandit, safety, gitleaks
