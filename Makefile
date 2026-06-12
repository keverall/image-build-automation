# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Makefile
# =============================================================================
# Common tasks for PowerShell development and CI/CD.
#
# Quick start:
#   make setup   # Setup PowerShell environment (install modules)
#   make test    # Run all Pester tests
#   make lint    # Lint PowerShell with PSScriptAnalyzer
#   make coverage # Run tests with code coverage
# =============================================================================

# ─── Configuration ───────────────────────────────────────────────────────────
CURDIR := $(shell pwd)
PSMODULE := src/powershell/Automation/Automation.psd1
PSDIRS   := src/powershell
PSTESTS  := tests/powershell

# Use bundled make.exe on Windows if available (offline-capable)
LOCAL_MAKE := $(CURDIR)/bin/make.exe
ifeq ($(OS),Windows_NT)
  ifneq ($(wildcard $(LOCAL_MAKE)),)
    MAKE := $(LOCAL_MAKE)
  endif
endif

# Coverage threshold (percentage)
COVERAGE_THRESHOLD := 70

# Colors
ESCAPE := $(shell printf '\033')
GREEN := $(ESCAPE)[0;32m
CYAN := $(ESCAPE)[0;36m
YELLOW := $(ESCAPE)[1;33m
RED := $(ESCAPE)[0;31m
NC := $(ESCAPE)[0m

.PHONY: setup lint lint-make lint-test test test-unit test-integration coverage docs clean prune-logs help all ci

# ─── PowerShell Setup ───────────────────────────────────────────────────────
setup: prune-logs ## Setup PowerShell environment (install modules, configure profiles)
	@echo "$(CYAN)[setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Setup-Profile.ps1
	@bash scripts/install-checkmake.sh

# ─── Linting ────────────────────────────────────────────────────────────────
lint: prune-logs lint-make lint-checkmake ## Lint PowerShell files and Makefile
	@echo "$(CYAN)[lint]$(NC) Running PSScriptAnalyzer..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1

lint-checkmake: ## Lint Makefile with checkmake (optional)
	@bash scripts/run-checkmake.sh </dev/null

lint-make: ## Lint Makefile syntax and style
	@echo "$(CYAN)[lint-make]$(NC) Checking Makefile..."
	@bash scripts/lint-make.sh

lint-test: prune-logs ## Lint and run tests (combined CI step)
	@$(MAKE) lint && $(MAKE) test

# ─── PowerShell Testing ──────────────────────────────────────────────────────
test: prune-logs ## Run all Pester PowerShell tests with verbose output
	@echo "$(CYAN)[test]$(NC) Running Pester unit tests..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-tests.ps1

test-unit: prune-logs ## Run Pester unit tests only with detailed output
	@echo "$(CYAN)[test-unit]$(NC) Running Pester unit tests..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-tests.ps1

test-integration: prune-logs ## Run Pester integration tests only
	@echo "$(CYAN)[test-integration]$(NC) Running Pester integration tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path \"$$pwd\$(PSTESTS)/Pester.Integration.ps1\" -PassThru"

maint-mode-tests: prune-logs ## Run high-priority Set-MaintenanceMode tests
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-maint-mode-tests.ps1

# ─── Code Coverage ────────────────────────────────────────────────────────────
coverage: prune-logs ## Run Pester tests with code coverage and generate report
	@echo "$(CYAN)[coverage]$(NC) Running tests with code coverage and generating report..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/coverage-report.ps1

docs: prune-logs ## Generate PowerShell Markdown docs via PlatyPS
	@echo "$(CYAN)[docs]$(NC) Generating PowerShell API reference docs..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 -OutputDir docs/dynamic-code-docs || \
		(echo "$(YELLOW)[docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)
	@echo "$(GREEN)[docs]$(NC) Docs written to docs/dynamic-code-docs/"

# ─── Default Target ──────────────────────────────────────────────────────────
help: prune-logs ## Show this help message
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Show-Help.ps1

# ─── Cleanup ────────────────────────────────────────────────────────────────
clean: prune-logs ## Remove build artifacts and temp files
	@echo "$(CYAN)[clean]$(NC) Removing build artifacts..."
	@rm -rf generated/
	@echo "$(GREEN)[clean]$(NC) Done"

prune-logs: ## Prune log files older than 30 days
	@echo "$(CYAN)[prune-logs]$(NC) Pruning old log files..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/prune-logs.ps1

# ─── Aggregate Targets ───────────────────────────────────────────────────────
all: lint test ## Run linting and tests

# CI pipeline target
ci: lint coverage ## Run full CI pipeline