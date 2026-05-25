# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Makefile
# =============================================================================
# Common tasks for PowerShell development and CI/CD.
#
# Quick start:
#   make setup    # Setup PowerShell environment (install modules)
#   make test     # Run all Pester tests
#   make lint     # Lint PowerShell with PSScriptAnalyzer
#   make coverage   # Run tests with code coverage
# =============================================================================

# ─── Configuration ───────────────────────────────────────────────────────────
CURDIR := $(shell pwd)
PSMODULE := src/powershell/Automation/Automation.psd1
PSDIRS   := src/powershell
PSTESTS  := tests/powershell

# Colors
GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: pwsh-setup pwsh-lint pwsh-lint-test pwsh-test pwsh-test-unit pwsh-test-integration pwsh-coverage pwsh-docs \
        clean help

# ─── PowerShell Setup ───────────────────────────────────────────────────────
pwsh-setup: ## Setup PowerShell environment (install modules, configure)
	@echo "$(CYAN)[pwsh-setup]$(NC) Setting up PowerShell environment..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1

# ─── PowerShell Linting ─────────────────────────────────────────────────────
pwsh-lint: ## Lint PowerShell files with PSScriptAnalyzer
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/lint-pwsh.ps1

# ─── PowerShell Testing ──────────────────────────────────────────────────────
pwsh-test: ## Run all Pester PowerShell tests
	@echo "$(CYAN)[pwsh-test]$(NC) Running all Pester tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		$$config = New-PesterConfiguration; \
		$$config.Run.Path = @( \
			\"$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1\", \
			\"$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1\" \
		); \
		$$config.Output.Verbosity = 'Detailed'; \
		Invoke-Pester -Configuration $$config"

pwsh-test-unit: ## Run Pester unit tests only
	@echo "$(CYAN)[pwsh-test-unit]$(NC) Running Pester unit tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Import-Module $$pwd\$(PSDIRS)/Automation/Automation.psd1 -Force -WarningAction SilentlyContinue; \
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
		) -PassThru"

pwsh-test-integration: ## Run Pester integration tests only
	@echo "$(CYAN)[pwsh-test-integration]$(NC) Running Pester integration tests..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		Invoke-Pester -Path \"$$pwd\$(PSTESTS)/Pester.Integration.ps1\" -PassThru"

pwsh-coverage: ## Run Pester tests with code coverage
	@echo "$(CYAN)[pwsh-coverage]$(NC) Running Pester tests with coverage..."
	@pwsh -NoProfile -Command "\
		$$pwd = '$(CURDIR)'; \
		Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop; \
		$$config = New-PesterConfiguration; \
		$$config.Run.Path = @('$$pwd\$(PSTESTS)/Audit.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Config.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Credentials.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Executor.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/FileIO.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Inventory.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/New-Uuid.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Router.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Set-MaintenanceMode.Unit.Tests.ps1', '$$pwd\$(PSTESTS)/Validators.Unit.Tests.ps1'); \
		$$config.Output.Verbosity = 'Detailed'; \
		$$config.CodeCoverage.Enabled = $$true; \
		$$config.CodeCoverage.Path = '$$pwd\$(PSDIRS)/Public/*.ps1'; \
		Invoke-Pester -Configuration $$config"

pwsh-docs: ## Generate PowerShell Markdown docs via PlatyPS
	@echo "$(CYAN)[pwsh-docs]$(NC) Generating PowerShell API reference docs (PlatyPS)..."
	@pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Generate-PSDocs.ps1 || \
		(echo "$(YELLOW)[pwsh-docs]$(NC) PlatyPS not installed. Install with: Install-Module PlatyPS -Scope CurrentUser" && false)
	@echo "$(GREEN)[pwsh-docs]$(NC) Docs written to docs/powershell/generated/"

# ─── Default Target ──────────────────────────────────────────────────────────
help: ## Show this help message
	@printf "\033[0;36m╔══════════════════════════════════════════════════════════╗\033[0m\n"
	@printf "\033[0;36m║\033[0m  HPE ProLiant ISO Automation — Available Commands   \033[0;36m║\033[0m\n"
	@printf "\033[0;36m╚══════════════════════════════════════════════════════════╝\033[0m\n"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[0;32m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Cleanup ───────────────────────────────────────────────────────────────────
clean: ## Remove build artifacts and temp files
	@echo "$(CYAN)[clean]$(NC) Removing build artifacts..."
	rm -rf generated/
	@echo "$(GREEN)[clean]$(NC) Done"

# ─── Aggregate Targets ───────────────────────────────────────────────────────
all: pwsh-lint pwsh-test ## Run linting and tests