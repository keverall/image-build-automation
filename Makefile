# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Makefile
# =============================================================================
# Common tasks for development, testing, and CI/CD.
#
# Quick start:
#   make setup          # Create venv and install all dependencies
#   make pwsh-setup     # Setup PowerShell environment (install modules)
#   make test           # Run Python test suite with coverage
#   make pwsh-test      # Run PowerShell tests
#   make lint           # Run all linting checks
#   make security       # Run security scans
#   make all            # Full setup + lint + test + security
#
# Python commands:
#   make test-fast      # Run tests without coverage (faster)
#   make test-unit      # Run unit tests only
#   make test-integration # Run integration tests only
#   make lint-fix       # Auto-fix linting issues
#   make format         # Format all Python files
#
# PowerShell commands:
#   make pwsh-test      # Run all Pester tests
#   make pwsh-lint      # Lint PowerShell with PSScriptAnalyzer
#   make pwsh-coverage  # Run tests with code coverage
# =============================================================================

# ─── Configuration ───────────────────────────────────────────────────────────
PYTHON := uv run --python 3.12
VENV := .venv
SRC := src/python/automation
TESTS := tests/python
PYPROJECT := pyproject.toml
CURDIR := $(shell pwd)

# Colors
GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
BOLD := \033[1m
NC := \033[0m

.PHONY: setup install deps test lint lint-fix security format check clean help all \
            pwsh-setup pwsh-lint pwsh-lint-test pwsh-test pwsh-test-unit pwsh-test-integration pwsh-coverage pwsh-docs py-docs \
           test-fast test-unit test-integration test-watch coverage-html coverage-xml security-quick install-gitleaks \
           ci pr-check shell run-build-iso run-generate-uuid run-maintenance docs fresh

# ─── PowerShell ─────────────────────────────────────────────────────────────
PSMODULE := src/powershell/Automation/Automation.psd1
PSTESTS  := tests/powershell
PSDIRS   := src/powershell

pwsh-setup: ## Setup PowerShell environment (install modules, configure)
	@echo "$(CYAN)[pwsh-setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1

pwsh-lint: ## Lint PowerShell files with PSScriptAnalyzer
	@echo "$(CYAN)[pwsh-lint]$(NC) Running PSScriptAnalyzer..."
	@pwsh -NoProfile -Command "\
		\$$pssa = Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue; \
		if (-not \$$pssa) { \
			Write-Host 'PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer'; \
			exit 1; \
		}; \
		\$$errors = Invoke-ScriptAnalyzer -Path '$(PSDIRS)' -Recurse -Severity Warning; \
		if (\$$errors) { \$$errors | Format-Table -AutoSize; exit 1 } \
		else { Write-Host '$(GREEN)[pwsh-lint]$(NC) No issues found' }" || true
	@printf "\033[0;31m\033[1m⚠️  WARNING: DO NOT CHANGE STRINGS TO SECURESTRINGS — IT BREAKS ALL POWERSHELL TESTS. BE WARNED AND HEED!\033[0m\n"

pwsh-lint-test: ## Lint PowerShell test files
	@echo "$(CYAN)[pwsh-lint-test]$(NC) Checking PowerShell test files..."
	@pwsh -NoProfile -Command "\
		\$$pssa = Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue; \
		if (-not \$$pssa) { \
			Write-Host 'PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer'; \
			exit 1; \
		}; \
		\$$errors = Invoke-ScriptAnalyzer -Path '$(PSTESTS)' -Recurse -Severity Warning -ErrorAction SilentlyContinue; \
		if (\$$errors) { \$$errors | Format-Table -AutoSize; exit 1 } \
		else { Write-Host '$(GREEN)[pwsh-lint-test]$(NC) Test files OK' }"

# ─── PowerShell Testing ───────────────────────────────────────────────────────
pwsh-test: ## Run all Pester PowerShell tests
	@echo "$(CYAN)[pwsh-test]$(NC) Running all Pester tests..."
	@pwsh -NoProfile -Command "\
		\$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		\$$config = New-PesterConfiguration; \
		\$$config.Run.Path = @( \
			\"\$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1\" \
		); \
		\$$config.Output.Verbosity = 'Detailed'; \
		Invoke-Pester -Configuration \$$config"

pwsh-test-unit: ## Run Pester unit tests only
	@echo "$(CYAN)[pwsh-test-unit]$(NC) Running Pester unit tests..."
	@pwsh -Command "\$$pwd = '$(CURDIR)'; Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; Import-Module \$$pwd\$(PSDIRS)/Automation/Automation.psd1 -Force -WarningAction SilentlyContinue; \
		Invoke-Pester -Path @( \
			\"\$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1\", \
			\"\$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1\" \
		) -PassThru"

pwsh-test-integration: ## Run Pester integration tests only
	@echo "$(CYAN)[pwsh-test-integration]$(NC) Running Pester integration tests..."
	@pwsh -Command "\$$pwd = '$(CURDIR)'; Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path \"\$$pwd\$(PSTESTS)/Pester.Integration.ps1\" -PassThru"

pwsh-coverage: ## Run Pester tests with code coverage
	@echo "$(CYAN)[pwsh-coverage]$(NC) Running Pester tests with coverage..."
	@pwsh -NoProfile -Command "\
		\$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		\$$config = New-PesterConfiguration; \
		\$$config.Run.Path = @('\$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/New-Uuid.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1', '\$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1'); \
		\$$config.Output.Verbosity = 'Detailed'; \
		\$$config.CodeCoverage.Enabled = \$true; \
		\$$config.CodeCoverage.Path = '\$$pwd\$(PSDIRS)/Public/*.ps1'; \
		Invoke-Pester -Configuration \$$config"

pwsh-docs: ## Generate PowerShell Markdown docs via PlatyPS
	@echo "$(CYAN)[pwsh-docs]$(NC) Generating PowerShell API reference docs (PlatyPS)..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 || \
		(echo "$(YELLOW)[pwsh-docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)
	@echo "$(GREEN)[pwsh-docs]$(NC) Docs written to docs/powershell/generated/"
	@echo ""

py-docs: ## Generate Python CLI Markdown docs via argparse help extraction
	@echo "$(CYAN)[py-docs]$(NC) Generating Python CLI API reference docs…"
	@$(PYTHON) scripts/generate_python_docs.py --force
	@echo "$(GREEN)[py-docs]$(NC) Docs written to docs/python/generated/"

# ─── Default Target ──────────────────────────────────────────────────────────
help: ## Show this help message
	@printf "\033[0;36m╔══════════════════════════════════════════════════════════╗\033[0m\n"
	@printf "\033[0;36m║\033[0m  HPE ProLiant ISO Automation — Available Commands   \033[0;36m║\033[0m\n"
	@printf "\033[0;36m╚══════════════════════════════════════════════════════════╝\033[0m\n"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[0;32m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Setup ───────────────────────────────────────────────────────────────────
setup: ## Create venv and install all dependencies (first run)
	@echo "$(CYAN)[setup]$(NC) Creating virtual environment..."
	uv venv $(VENV) --python 3.12
	@echo "$(CYAN)[setup]$(NC) Installing runtime dependencies..."
	uv pip install -r requirements.txt
	@echo "$(CYAN)[setup]$(NC) Installing dev dependencies..."
	uv pip install "ruff>=0.6.0" "radon>=6.0.0" "bandit>=1.7.0" \
		"safety>=3.0.0" "mypy>=1.0" "pytest>=7.0" "pytest-cov>=4.0"
	@echo "$(CYAN)[setup]$(NC) Installing automation package (editable)..."
	uv pip install -e .
	@echo "$(GREEN)[setup]$(NC) Done! Activate with: source $(VENV)/bin/activate"

install: ## Install package in editable mode (after setup)
	@echo "$(CYAN)[install]$(NC) Installing automation package..."
	uv pip install -e .

deps: ## Install runtime dependencies only
	@echo "$(CYAN)[deps]$(NC) Installing runtime dependencies..."
	uv pip install -r requirements.txt

# ─── Testing ─────────────────────────────────────────────────────────────────
test: ## Run all tests with coverage
	@echo "$(CYAN)[test]$(NC) Running test suite..."
	$(PYTHON) -m pytest $(TESTS) -v --cov=$(SRC:src/%=%) --cov-report=term-missing

test-fast: ## Run tests without coverage (faster)
	@echo "$(CYAN)[test-fast]$(NC) Running tests (no coverage)..."
	$(PYTHON) -m pytest $(TESTS) -v

test-unit: ## Run unit tests only
	@echo "$(CYAN)[test-unit]$(NC) Running unit tests..."
	$(PYTHON) -m pytest $(TESTS) -v -m unit

test-integration: ## Run integration tests only
	@echo "$(CYAN)[test-integration]$(NC) Running integration tests..."
	$(PYTHON) -m pytest $(TESTS) -v -m integration

test-watch: ## Run tests and watch for changes (requires pytest-watch)
	@echo "$(CYAN)[test-watch]$(NC) Watching for changes..."
	$(PYTHON) -m ptw $(TESTS) --runner "pytest -v"

coverage-html: ## Generate HTML coverage report
	@echo "$(CYAN)[coverage-html]$(NC) Generating HTML coverage report..."
	@$(PYTHON) -m pytest $(TESTS) --cov=$(SRC:src/%=%) --cov-report=html -q 2>/dev/null || true
	@mkdir -p generated && mv htmlcov generated/ 2>/dev/null || true
	@echo "$(GREEN)[coverage-html]$(NC) Open generated/htmlcov/index.html in browser"

coverage-xml: ## Generate XML coverage report (for CI)
	@echo "$(CYAN)[coverage-xml]$(NC) Generating XML coverage report..."
	$(PYTHON) -m pytest $(TESTS) --cov=$(SRC:src/%=%) --cov-report=xml

# ─── Linting & Formatting ────────────────────────────────────────────────────
lint: ## Run all linting and code quality checks
	@set -e; \
	$(PYTHON) -m ruff check $(SRC) --output-format=concise; \
	$(PYTHON) -m ruff format $(SRC) --check; \
	$(PYTHON) -m mypy $(SRC) --ignore-missing-imports; \
	$(PYTHON) -m radon mi $(SRC) -s; \
	$(PYTHON) -m radon cc $(SRC) -nc; \
	echo "$(GREEN)[lint]$(NC) All checks passed"

lint-fix: ## Run ruff auto-fix and format
	@echo "$(CYAN)[lint-fix]$(NC) Auto-fixing with ruff..."
	@$(PYTHON) -m ruff check $(SRC) --fix
	@$(PYTHON) -m ruff format $(SRC)
	@echo "$(GREEN)[lint-fix]$(NC) Done"

lint-test: ## Run linting on test files
	@echo "$(CYAN)[lint-test]$(NC) Checking test files..."
	$(PYTHON) -m ruff check $(TESTS) --output-format=concise
	$(PYTHON) -m ruff format $(TESTS) --check
	@echo "$(GREEN)[lint-test]$(NC) Test files OK"

format: ## Format all Python files
	@echo "$(CYAN)[format]$(NC) Formatting code..."
	@$(PYTHON) -m ruff format $(SRC) $(TESTS)
	@$(PYTHON) -m ruff check $(SRC) $(TESTS) --fix
	@echo "$(GREEN)[format]$(NC) Done"

# ─── Security Scanning ───────────────────────────────────────────────────────
security: ## Run all security scans
	@echo "$(CYAN)[security]$(NC) Running bandit..."
	$(PYTHON) -m bandit -r $(SRC) -f txt
	@echo "$(CYAN)[security]$(NC) Running safety (dependency vulnerabilities)..."
	$(PYTHON) -m safety check
	@echo "$(CYAN)[security]$(NC) Running gitleaks (secret detection)..."
	@gitleaks detect --source=. --no-banner 2>/dev/null || \
		(echo "$(YELLOW)[security]$(NC) gitleaks not found. Install: make install-gitleaks" && false)
	@echo "$(GREEN)[security]$(NC) All security checks passed"

security-quick: ## Run bandit only (fastest security check)
	@echo "$(CYAN)[security-quick]$(NC) Running bandit..."
	$(PYTHON) -m bandit -r $(SRC) -f txt

install-gitleaks: ## Install gitleaks binary
	@echo "$(CYAN)[install-gitleaks]$(NC) Installing gitleaks..."
	@ARCH=$$(uname -m); \
	case "$$ARCH" in \
		x86_64) GL_ARCH="x64" ;; \
		aarch64) GL_ARCH="arm64" ;; \
		*) GL_ARCH="$$ARCH" ;; \
	esac; \
	OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_$$OS_$$GL_ARCH.tar.gz" | \
		tar -xzf - -C /usr/local/bin 2>/dev/null || \
		(mkdir -p ~/.local/bin && \
		curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_$$OS_$$GL_ARCH.tar.gz" | \
		tar -xzf - -C ~/.local/bin 2>/dev/null)
	@echo "$(GREEN)[install-gitleaks]$(NC) Done"

# ─── Build & Package ─────────────────────────────────────────────────────────
build: ## Build distribution packages
	@echo "$(CYAN)[build]$(NC) Building packages..."
	$(PYTHON) -m pip install build
	$(PYTHON) -m build
	@echo "$(GREEN)[build]$(NC) Packages built in dist/"

clean: ## Remove build artifacts, cache, and venv
	@echo "$(CYAN)[clean]$(NC) Removing build artifacts..."
	rm -rf dist/ build/ *.egg-info src/*.egg-info
	rm -rf .pytest_cache .coverage coverage.xml
	rm -rf .mypy_cache .ruff_cache
	rm -rf generated/
	@echo "$(CYAN)[clean]$(NC) Removing virtual environment..."
	rm -rf $(VENV)
	@echo "$(GREEN)[clean]$(NC) Done"

# ─── CI/CD ───────────────────────────────────────────────────────────────────
ci: ## Run full CI pipeline locally (lint + test + security)
	@echo "$(CYAN)[ci]$(NC) Starting local CI pipeline..."
	@echo "$(CYAN)[ci]$(NC) ┌─ Linting"
	@make lint
	@echo "$(CYAN)[ci]$(NC) └─ Tests"
	@make test
	@echo "$(CYAN)[ci]$(NC) └─ Security"
	@make security-quick
	@echo "$(GREEN)[ci]$(NC) Pipeline passed"

pr-check: ## Quick pre-PR checks (lint + test only)
	@echo "$(CYAN)[pr-check]$(NC) Running pre-PR checks..."
	@make lint
	@make test
	@echo "$(GREEN)[pr-check]$(NC) Ready to push"

# ─── Development ─────────────────────────────────────────────────────────────
shell: ## Start Python REPL with project imports
	@echo "$(CYAN)[shell]$(NC) Starting Python REPL..."
	$(PYTHON) -c "import automation; print(f'Loaded automation {automation.__version__}')"
	$(PYTHON)

run-build-iso: ## Run build_iso CLI (dry-run)
	@echo "$(CYAN)[run-build-iso]$(NC) Running build_iso (dry-run)..."
	$(PYTHON) -m automation.cli.build_iso --dry-run

run-generate-uuid: ## Generate UUID for a server
	@echo "$(CYAN)[run-generate-uuid]$(NC) Usage: make run-generate-uuid SERVER=server1"
	$(PYTHON) -m automation.cli.generate_uuid $(SERVER)

run-maintenance: ## Enable maintenance mode for a cluster
	@echo "$(CYAN)[run-maintenance]$(NC) Usage: make run-maintenance CLUSTER=PROD-CLUSTER-01"
	$(PYTHON) -m automation.cli.maintenance_mode --cluster-id $(CLUSTER) --start now

# ─── Aggregate Targets ───────────────────────────────────────────────────────
all: setup lint test security ## Full setup, lint, test, and security scan

docs: pwsh-docs py-docs ## Generate all API reference docs (PowerShell + Python)

fresh: clean setup ## Clean everything and rebuild from scratch
