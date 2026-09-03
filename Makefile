# =============================================================================
# HPE ProLiant Windows Server ISO Automation - Makefile
# =============================================================================
# Common tasks for PowerShell development and CI/CD.
#
# Quick start:
#   make setup   # Setup PowerShell environment (install modules)
#   make test    # Run all Pester tests
#   make lint    # Lint PowerShell with PSScriptAnalyzer
#   make lint-python # Lint Python scripts with Ruff (check + autofix)
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

# Doc fix flags (populated by fix-docs-dryrun); empty for real runs
WHATIF ?=
DRYRUN ?=

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

.PHONY: setup lint lint-make lint-checkmake lint-python lint-test test test-unit test-integration automation-mode-tests maint-mode-tests test-progress-rpt-tests coverage gen-docs add-anchors docs clean prune-logs help all ci fix-docs word-docs word-docs-clean

# ─── PowerShell Setup ───────────────────────────────────────────────────────
setup: ## Setup PowerShell environment (install modules, configure profiles)
	@echo "$(CYAN)[setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Setup-Profile.ps1

# Note: checkmake installation is now handled gracefully by setup-runner.ps1

# ─── Linting ────────────────────────────────────────────────────────────────
lint: lint-make lint-checkmake lint-python ## Lint PowerShell, Makefile, and Python (Ruff)
	@echo "$(CYAN)[lint]$(NC) Running PSScriptAnalyzer..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1

lint-checkmake: ## Lint Makefile with checkmake (optional)
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-checkmake.ps1

lint-python: ## Lint Python scripts with Ruff (check + autofix)
	@echo "$(CYAN)[lint-python]$(NC) Running Ruff on Python scripts..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint-python.ps1

lint-make: ## Lint Makefile syntax and style
	@echo "$(CYAN)[lint-make]$(NC) Checking Makefile..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint-make.ps1

lint-test: ## Lint and run tests (combined CI step)
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
		Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path \"$$pwd\$(PSTESTS)/Pester.Integration.ps1\" -PassThru"

maint-mode-tests: prune-logs ## Run high-priority Set-MaintenanceMode tests
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-maint-mode-tests.ps1

automation-mode-tests: prune-logs ## Run automation workflow tests (ISO build, OneView, iLO Redfish, orchestrator)
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-automation-mode-tests.ps1

test-progress-rpt-tests: prune-logs ## Run test progress report generator tests (Update-TestProgress helpers, E2E, HTML)
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-test-progress-rpt-tests.ps1

# ─── Code Coverage ────────────────────────────────────────────────────────────
coverage: prune-logs ## Run Pester tests with code coverage and generate report
	@echo "$(CYAN)[coverage]$(NC) Running tests with code coverage and generating report..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/coverage-report.ps1

docs: gen-docs fix-links add-anchors ## Generate PowerShell Markdown docs, fix links, and add anchors/TOC
	@echo "$(GREEN)[docs]$(NC) Docs written to docs/dynamic-code-docs/"

gen-docs: ## Generate PowerShell API reference docs (src/ + scripts/ -> docs/dynamic-code-docs)
	@echo "$(CYAN)[docs]$(NC) Generating PowerShell API reference docs..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 -OutputDir docs/dynamic-code-docs || \
		(echo "$(YELLOW)[docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)

add-anchors: ## Add Bitbucket/GitStash-compatible anchors + TOC to all markdown
	@echo "$(CYAN)[add-anchors]$(NC) Adding anchors + TOC to all markdown..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/bitbucket-md-anchor-toc.ps1 -All $(DRYRUN)

# ─── Documentation Link Validation ───────────────────────────────────────────
# Shared by `make docs` and `make fix-docs` so both leave the repository in the
# exact same canonical doc state (no churn when run in either order).
fix-links: ## Validate and fix broken markdown links (shared by docs + fix-docs)
	@echo "$(CYAN)[fix-links]$(NC) Validating and fixing markdown links..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-docs-links.ps1 $(WHATIF)

fix-docs: fix-links add-anchors ## Fix broken markdown links + anchors/TOC in configs/, docs/, and root
	@echo "$(GREEN)[fix-docs]$(NC) Done."

fix-docs-dryrun: WHATIF=-WhatIf
fix-docs-dryrun: DRYRUN=-DryRun
fix-docs-dryrun: ## Preview broken markdown link + anchor/TOC fixes (dry-run)
	@$(MAKE) fix-links
	@$(MAKE) add-anchors

# ─── Word DOCX Help Docs ───────────────────────────────────────────────────────
word-docs: ## Convert Markdown docs to Word DOCX with clickable bookmarks/links
	@echo "$(CYAN)[word-docs]$(NC) Converting Markdown docs to DOCX..."
	@python3 scripts/MD_to_DOCX_Converter.py
	@echo "$(GREEN)[word-docs]$(NC) DOCX docs written to docx/"

word-docs-clean: ## Remove generated Word DOCX help docs
	rm -rf docx/

# ─── Default Target ──────────────────────────────────────────────────────────
help: ## Show this help message
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Show-Help.ps1

# ─── Cleanup ────────────────────────────────────────────────────────────────
clean: ## Remove build artifacts and temp files
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

# ─── Test Progress Updates ───────────────────────────────────────────────────
test-progress-update: ## Update test plans with today's test execution progress (interactive)
	@echo "$(CYAN)[test-progress-update]$(NC) Updating test plans with execution progress..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Update-TestProgress.ps1

test-progress-update-ci: ## Update test plans non-interactively (use REASON="..." COMMAND="..." ENV="..." OV_SUMMARY="..." OV_ADD_ROW=1 OV_PHASES="..." OV_TESTER="..." OV_APPLIANCE="..." OV_RESULT="..." OV_LOGREF="..." OV_SIGNOFF="...")
	@echo "$(CYAN)[test-progress-update]$(NC) Updating test plans (non-interactive)..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Update-TestProgress.ps1 -NonInteractive \
		-Reason "$(REASON)" -CommandSuite "$(COMMAND)" -Environment "$(ENV)" \
		-OneViewStatusSummary "$(OV_SUMMARY)" $(if $(OV_ADD_ROW),-AddOneViewRow,) \
		-OvPhases "$(OV_PHASES)" -OvTester "$(OV_TESTER)" -OvAppliance "$(OV_APPLIANCE)" \
		-OvResult "$(OV_RESULT)" -OvLogRef "$(OV_LOGREF)" -OvSignedOff "$(OV_SIGNOFF)"

# ─── GitLab Hardening & Compliance Test Plan ─────────────────────────────────
gitlab-hardening-update: ## Update GitLab hardening test plan (interactive)
	@echo "$(CYAN)[gitlab-hardening]$(NC) Updating GitLab hardening test plan..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Update-GitLabHardeningPlan.ps1

gitlab-hardening-update-ci: ## Update GitLab hardening test plan non-interactively (env-driven; see script header)
	@echo "$(CYAN)[gitlab-hardening]$(NC) Updating GitLab hardening test plan (non-interactive)..."
	@GH_ADD_ROW=1 GH_ADD_COV_ROW=1 pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Update-GitLabHardeningPlan.ps1 -NonInteractive
