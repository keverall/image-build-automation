# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Makefile
# =============================================================================
# Common tasks for PowerShell development and CI/CD.
#
# Quick start:
#   make setup   # Setup PowerShell environment (install modules)
#   make test    # Run all Pester tests
#   make lint    # Lint PowerShell with PSScriptAnalyzer
#   make coverage # Run tests with code coverage
#   make fix-docs # Fix broken markdown links (use -WhatIf to preview)
# =============================================================================

# ─── Configuration ───────────────────────────────────────────────────────────
# Use built-in CURDIR to avoid $(shell pwd) failing on Windows without sh.exe
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

# Colors: fallback to empty on Windows to avoid $(shell printf) errors without sh.exe
ifeq ($(OS),Windows_NT)
  GREEN := 
  CYAN := 
  YELLOW := 
  RED := 
  NC := 
else
  ESCAPE := $(shell printf '\033')
  GREEN := $(ESCAPE)[0;32m
  CYAN := $(ESCAPE)[0;36m
  YELLOW := $(ESCAPE)[1;33m
  RED := $(ESCAPE)[0;31m
  NC := $(ESCAPE)[0m
endif

.PHONY: setup lint lint-make lint-test test test-unit test-integration automation-mode-tests maint-mode-tests coverage gen-docs add-anchors docs clean prune-logs help all ci fix-docs

# ─── PowerShell Setup ───────────────────────────────────────────────────────
setup: prune-logs ## Setup PowerShell environment (install modules, configure profiles)
	@echo "$(CYAN)[setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Setup-Profile.ps1

# Note: checkmake installation is now handled gracefully by setup-runner.ps1

# ─── Linting ────────────────────────────────────────────────────────────────
lint: prune-logs lint-make lint-checkmake ## Lint PowerShell files and Makefile
	@echo "$(CYAN)[lint]$(NC) Running PSScriptAnalyzer..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1

lint-checkmake: ## Lint Makefile with checkmake (optional)
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-checkmake.ps1

lint-make: ## Lint Makefile syntax and style
	@echo "$(CYAN)[lint-make]$(NC) Checking Makefile..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint-make.ps1

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

automation-mode-tests: prune-logs ## Run automation workflow tests (ISO build, OneView, iLO Redfish, orchestrator)
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-automation-mode-tests.ps1

# ─── Code Coverage ────────────────────────────────────────────────────────────
coverage: prune-logs ## Run Pester tests with code coverage and generate report
	@echo "$(CYAN)[coverage]$(NC) Running tests with code coverage and generating report..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/coverage-report.ps1

docs: prune-logs gen-docs add-anchors ## Generate PowerShell Markdown docs + Bitbucket anchors
	@echo "$(GREEN)[docs]$(NC) Docs written to docs/dynamic-code-docs/"

gen-docs: ## Generate PowerShell API reference docs (src/ + scripts/ -> docs/dynamic-code-docs)
	@echo "$(CYAN)[docs]$(NC) Generating PowerShell API reference docs..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 -OutputDir docs/dynamic-code-docs || \
		(echo "$(YELLOW)[docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)

add-anchors: ## Add Bitbucket/GitStash-compatible anchors + TOC to all markdown
	@echo "$(CYAN)[docs]$(NC) Adding Bitbucket/GitStash-compatible anchors + TOC to all markdown..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/bitbucket-md-anchor-toc.ps1 -All

# ─── Documentation Link Validation ───────────────────────────────────────────
fix-docs: prune-logs ## Fix broken markdown links in configs/, docs/, and root
	@echo "$(CYAN)[fix-docs]$(NC) Validating and fixing markdown links..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-docs-links.ps1 $(WHATIF)

fix-docs-dryrun: WHATIF=-WhatIf
fix-docs-dryrun: prune-logs ## Preview broken markdown link fixes (dry-run)
	@echo "$(CYAN)[fix-docs-dryrun]$(NC) Previewing link fixes (no changes)..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-docs-links.ps1 $(WHATIF)

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
