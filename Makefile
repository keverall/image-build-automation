# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Makefile
# =============================================================================
# Common tasks for PowerShell development and CI/CD.
#
# Quick start:
#   make setup    # Setup PowerShell environment (install modules)
#   make test     # Run all Pester tests
#   make lint     # Lint PowerShell with PSScriptAnalyzer
#   make coverage # Run tests with code coverage
# =============================================================================

# ─── Configuration ───────────────────────────────────────────────────────────
CURDIR := $(shell pwd)
PSMODULE := src/powershell/Automation/Automation.psd1
PSDIRS   := src/powershell
PSTESTS  := tests/powershell

# Coverage threshold (percentage)
COVERAGE_THRESHOLD := 70

# Colors
GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: setup lint lint-test test test-unit test-integration coverage docs \
        clean help

# ─── PowerShell Setup ───────────────────────────────────────────────────────
setup: ## Setup PowerShell environment (install modules, configure)
	@echo "$(CYAN)[setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1

# ─── PowerShell Linting ─────────────────────────────────────────────────────
lint: ## Lint PowerShell files with PSScriptAnalyzer
	@echo "$(CYAN)[lint]$(NC) Running PSScriptAnalyzer..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1

lint-test: ## Lint and run tests (combined CI step)
	@$(MAKE) lint && $(MAKE) test

# ─── PowerShell Testing ──────────────────────────────────────────────────────
test: ## Run all Pester PowerShell tests with verbose output
	@echo "$(CYAN)[test]$(NC) Running Pester unit tests..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-tests.ps1

test-unit: ## Run Pester unit tests only with detailed output
	@echo "$(CYAN)[test-unit]$(NC) Running Pester unit tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path @( \
			\"$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1\" \
		) -PassThru -OutputVerbosity Detailed"

test-integration: ## Run Pester integration tests only
	@echo "$(CYAN)[test-integration]$(NC) Running Pester integration tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path \"$$pwd\$(PSTESTS)/Pester.Integration.ps1\" -PassThru"

# ─── Code Coverage ────────────────────────────────────────────────────────────
coverage: ## Run Pester tests with code coverage and enforce threshold
	@echo "$(CYAN)[coverage]$(NC) Running tests with code coverage..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		$$config = New-PesterConfiguration; \
		$$config.Run.Path = @('$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1'); \
		$$config.Output.Verbosity = 'Detailed'; \
		$$config.Output.RenderMode = 'Auto'; \
		$$config.CodeCoverage.Enabled = $$true; \
		$$config.CodeCoverage.Path = @('$$pwd\src/powershell/Automation/Public/Set-MaintenanceMode.ps1'); \
		$$config.CodeCoverage.OutputPath = '$$pwd/coverage-results.xml'; \
		$$config.CodeCoverage.OutputFormat = 'Cobertura'; \
		Invoke-Pester -Configuration $$config; \
		$$coverage = $$config.CodeCoverage; \
		$$coveredLines = $$coverage.CoveredCommands.Count; \
		$$totalLines = $$coverage.TotalCommands.Count; \
		$$percent = if ($$totalLines -gt 0) { [math]::Round(($$coveredLines / $$totalLines) * 100, 2) } else { 0 }; \
		Write-Host ''; \
		Write-Host '========================================'; \
		Write-Host '[coverage] Results:'; \
		Write-Host \"  Covered commands: $$coveredLines / $$totalLines\"; \
		Write-Host \"  Coverage: $$percent%\"; \
		Write-Host '========================================'; \
		if ($$percent -lt $(COVERAGE_THRESHOLD)) { \
			Write-Host '$(RED)[coverage] ERROR: Coverage $$percent% is below threshold $(COVERAGE_THRESHOLD)%$(NC)'; \
			exit 1; \
		} else { \
			Write-Host '$(GREEN)[coverage] SUCCESS: Coverage meets threshold$(NC)'; \
		}"

coverage-report: ## Generate HTML coverage report
	@echo "$(CYAN)[coverage-report]$(NC) Generating HTML coverage report..."
	@mkdir -p generated/htmlcov
	@pwsh -NoProfile -ExecutionPolicy Bypass -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		$$config = New-PesterConfiguration; \
		$$config.Run.Path = @('$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1'); \
		$$config.CodeCoverage.Enabled = $$true; \
		$$config.CodeCoverage.Path = '$$pwd\$(PSDIRS)/Automation/Public/Set-MaintenanceMode.ps1'; \
		$config.CodeCoverage.OutputPath = '$pwd/generated/htmlcov/index.html'; \
		$config.CodeCoverage.OutputFormat = 'Html'; \
		Invoke-Pester -Configuration $config"
	@echo "$(GREEN)[coverage-report]$(NC) Report written to generated/htmlcov/index.html"

docs: ## Generate PowerShell Markdown docs via PlatyPS
	@echo "$(CYAN)[docs]$(NC) Generating PowerShell API reference docs..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 -OutputDir docs/dynamic-code-docs || \
		(echo "$(YELLOW)[docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)
	@echo "$(GREEN)[docs]$(NC) Docs written to docs/dynamic-code-docs/"

# ─── Default Target ──────────────────────────────────────────────────────────
help: ## Show this help message
	@printf "\033[0;36m╔══════════════════════════════════════════════════════════╗\033[0m\n"
	@printf "\033[0;36m║\033[0m  HPE ProLiant ISO Automation — Available Commands   \033[0;36m║\033[0m\n"
	@printf "\033[0;36m╚══════════════════════════════════════════════════════════╝\033[0m\n"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[0;32m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Cleanup ────────────────────────────────────────────────────────────────
clean: ## Remove build artifacts and temp files
	@echo "$(CYAN)[clean]$(NC) Removing build artifacts..."
	@rm -rf generated/
	@rm -rf generated/htmlcov/*
	@rm -rf coverage-results.xml
	@echo "$(GREEN)[clean]$(NC) Done"

# ─── Aggregate Targets ───────────────────────────────────────────────────────
all: lint test ## Run linting and tests

# CI pipeline target
ci: lint coverage ## Run full CI pipeline
