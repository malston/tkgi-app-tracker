# TKGI Application Tracker - Makefile
# Provides convenient targets for local development and testing

# Configuration
SHELL := /bin/bash
SAMPLE_DATA_DIR := sample-data
REPORTS_DIR := $(SAMPLE_DATA_DIR)/reports
SCRIPTS_DIR := scripts

# Python virtual environment
VENV := venv
PYTHON := $(VENV)/bin/python3
PIP := $(VENV)/bin/pip

# Default foundation for testing
FOUNDATION ?= dc01-k8s-n-01
SEED ?= 42
VERBOSE ?= false

# Cross-foundation aggregation settings
FOUNDATION_REPORTS_DIR ?=

# Colors for output - set NO_COLOR=1 to disable colors
ifndef NO_COLOR
    GREEN := \033[0;32m
    YELLOW := \033[0;33m
    RED := \033[0;31m
    CYAN := \033[36m
    WHITE := \033[1;37m
    NC := \033[0m
else
    GREEN :=
    YELLOW :=
    RED :=
    CYAN :=
    WHITE :=
    NC :=
endif

.PHONY: help all clean sample-data csv-reports excel-reports cross-foundation-report cross-foundation-test test validate setup venv install clean-venv docker-build docker-test docker-dev docker-clean

# Default target - show help
.DEFAULT_GOAL := help

help: ## Show this help message
	@printf "\n$(CYAN)TKGI Application Tracker - Available Make Targets$(NC)\n"
	@printf "==================================================\n\n"
	@printf "$(WHITE)Main Workflows:$(NC)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | head -10 | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-24s$(NC) %s\n", $$1, $$2}'
	@printf "\n$(WHITE)Development Tasks:$(NC)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | tail -n +11 | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-24s$(NC) %s\n", $$1, $$2}'
	@printf "\n$(WHITE)Configuration:$(NC)\n"
	@printf "  $(YELLOW)FOUNDATION=$(FOUNDATION)    $(NC)Target foundation for testing\n"
	@printf "  $(YELLOW)SEED=$(SEED)                     $(NC)Random seed for reproducible data\n"
	@printf "  $(YELLOW)VERBOSE=$(VERBOSE)               $(NC)Enable verbose output\n"
	@printf "  $(YELLOW)NO_COLOR=1                  $(NC)Disable colored output\n"
	@printf "\n$(WHITE)Examples:$(NC)\n"
	@printf "  $(CYAN)make all                    $(NC)Generate sample data, CSV, and Excel reports\n"
	@printf "  $(CYAN)make sample-data SEED=123   $(NC)Generate data with specific seed\n"
	@printf "  $(CYAN)make test-foundation        $(NC)Test with specific foundation\n"
	@printf "  $(CYAN)make clean all              $(NC)Clean and regenerate everything\n\n"

##@ Setup & Installation

setup: venv install ## Complete local development setup (creates venv, installs deps)
	@printf "$(GREEN)✅ Development environment setup complete!$(NC)\n"
	@printf "$(WHITE)Next steps:$(NC)\n"
	@printf "  1. Run: $(CYAN)make all$(NC) to generate sample data and reports\n"
	@printf "  2. Run: $(CYAN)make open-excel$(NC) to view the Excel workbook\n\n"

venv: ## Create Python virtual environment
	@if [ ! -d "$(VENV)" ]; then \
		printf "$(GREEN)Creating Python virtual environment...$(NC)\n"; \
		python3 -m venv $(VENV); \
		printf "$(GREEN)✅ Virtual environment created$(NC)\n"; \
	else \
		printf "$(YELLOW)⚠️  Virtual environment already exists$(NC)\n"; \
	fi

install: venv ## Install Python dependencies
	@printf "$(CYAN)Installing Python dependencies...$(NC)\n"
	@$(PIP) install -r requirements.txt
	@printf "$(GREEN)✅ Dependencies installed$(NC)\n"

clean-venv: ## Remove Python virtual environment
	@printf "$(RED)Removing virtual environment...$(NC)\n"
	@rm -rf $(VENV)
	@printf "$(GREEN)✅ Virtual environment removed$(NC)\n"

##@ Main Workflows

all: sample-data csv-reports excel-reports ## Generate complete workflow (data + reports + Excel)
	@printf "$(GREEN)✅ Complete TKGI Application Tracker workflow finished!$(NC)\n"


clean: ## Clean all generated data and reports
	@printf "$(YELLOW)🧹 Cleaning generated files...$(NC)\n"
	@rm -rf $(REPORTS_DIR)/*.json $(REPORTS_DIR)/*.csv $(REPORTS_DIR)/*.xlsx
	@rm -rf data/*.json reports/*.json reports/*.csv reports/*.xlsx 2>/dev/null || true
	@printf "$(GREEN)✅ Cleanup complete$(NC)\n"

sample-data: ## Generate sample TKGI application data
	@echo "📊 Generating sample data..."
	@cd $(SAMPLE_DATA_DIR) && ../$(PYTHON) generate-sample-data.py --seed $(SEED)
	@echo "✅ Sample data generated with seed $(SEED)"

csv-reports: sample-data ## Generate CSV reports from sample data
	@echo "📋 Generating CSV reports..."
	@$(PYTHON) $(SCRIPTS_DIR)/generate-reports.py --reports-dir $(REPORTS_DIR) $(if $(filter true,$(VERBOSE)),--verbose)
	@echo "✅ CSV reports generated"

excel-reports: csv-reports install ## Generate Excel workbook with charts and pivot tables
	@echo "📈 Generating Excel workbook..."
	@$(PYTHON) $(SCRIPTS_DIR)/generate-excel-template.py --output-dir $(REPORTS_DIR) $(if $(filter true,$(VERBOSE)),--verbose)
	@echo "✅ Excel workbook generated"

cross-foundation-report: install ## Aggregate CSV reports from multiple foundation directories
	@if [ -z "$(FOUNDATION_REPORTS_DIR)" ]; then \
		printf "$(RED)❌ FOUNDATION_REPORTS_DIR parameter required$(NC)\n"; \
		printf "$(WHITE)Example: make cross-foundation-report FOUNDATION_REPORTS_DIR=foundation-reports$(NC)\n"; \
		printf "$(WHITE)Or test with: make cross-foundation-test$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(CYAN)🌐 Aggregating reports from: $(FOUNDATION_REPORTS_DIR)$(NC)\n"
	@$(PYTHON) $(SCRIPTS_DIR)/aggregate-cross-foundation.py $(FOUNDATION_REPORTS_DIR) $(if $(filter true,$(VERBOSE)),--verbose)
	@printf "$(GREEN)✅ Cross-foundation aggregation complete$(NC)\n"

quick-excel: install ## Quick Excel generation (skip data regeneration)
	@echo "📈 Generating Excel workbook from existing data..."
	@$(PYTHON) $(SCRIPTS_DIR)/generate-excel-template.py --output-dir $(REPORTS_DIR) $(if $(filter true,$(VERBOSE)),--verbose)
	@echo "✅ Excel workbook generated"

test-pipeline: ## Run the complete sample pipeline workflow
	@echo "🔬 Testing complete pipeline workflow..."
	@cd $(SAMPLE_DATA_DIR) && ./test-excel-reports.sh --seed $(SEED) $(if $(filter true,$(VERBOSE)),-v)
	@echo "✅ Pipeline test complete"

test-foundation: ## Test data collection with specific foundation
	@echo "🌐 Testing with foundation: $(FOUNDATION)"
	@./scripts/docker-test.sh collect-data -f $(FOUNDATION) $(if $(filter true,$(VERBOSE)),-v)
	@echo "✅ Foundation test complete"

cross-foundation-test: csv-reports install ## Test cross-foundation aggregation with sample data
	@printf "$(CYAN)🧪 Testing cross-foundation aggregation with sample data...$(NC)\n"
	@rm -rf test-cross-foundation 2>/dev/null || true
	@mkdir -p test-cross-foundation/{dc01-k8s-n-01,dc02-k8s-n-01,dc03-k8s-n-02}
	@printf "$(YELLOW)📋 Creating foundation-specific test data...$(NC)\n"
	@LATEST_CSV=$$(ls -t $(REPORTS_DIR)/application_report_*.csv 2>/dev/null | head -1); \
	if [ -n "$$LATEST_CSV" ]; then \
		printf "Using CSV file: $$LATEST_CSV\n"; \
		for f in dc01-k8s-n-01 dc02-k8s-n-01 dc03-k8s-n-02; do \
			head -1 "$$LATEST_CSV" > "test-cross-foundation/$$f/application_report_test.csv"; \
			grep "$$f" "$$LATEST_CSV" >> "test-cross-foundation/$$f/application_report_test.csv" || true; \
			count=$$(wc -l < "test-cross-foundation/$$f/application_report_test.csv"); \
			count=$$((count - 1)); \
			if [ $$count -gt 0 ]; then \
				printf "✓ $$f: $$count applications\n"; \
				echo "Foundation,Cluster,Total_Applications,Status" > "test-cross-foundation/$$f/cluster_report_test.csv"; \
				echo "$$f,$$f,$$count,Healthy" >> "test-cross-foundation/$$f/cluster_report_test.csv"; \
				echo "Foundation,Total_Applications,Active_Applications" > "test-cross-foundation/$$f/executive_summary_test.csv"; \
				echo "$$f,$$count,$$count" >> "test-cross-foundation/$$f/executive_summary_test.csv"; \
				cp "test-cross-foundation/$$f/application_report_test.csv" "test-cross-foundation/$$f/migration_priority_test.csv"; \
			fi; \
		done; \
	else \
		printf "$(RED)❌ No CSV reports found. Run 'make csv-reports' first.$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(CYAN)🌐 Running cross-foundation aggregation...$(NC)\n"
	@$(PYTHON) $(SCRIPTS_DIR)/aggregate-cross-foundation.py test-cross-foundation $(if $(filter true,$(VERBOSE)),--verbose)
	@printf "$(GREEN)✅ Cross-foundation aggregation test complete!$(NC)\n"
	@printf "$(WHITE)📂 Results available in: test-cross-foundation/consolidated/$(NC)\n"
	@ls -la test-cross-foundation/consolidated/ 2>/dev/null || true
# 	@rm -rf test-cross-foundation

validate: ## Validate generated reports and data quality
	@echo "✔️  Validating generated reports..."
	@./scripts/docker-test.sh validate-scripts $(if $(filter true,$(VERBOSE)),-v)
	@echo "Checking report files..."
	@ls -la $(REPORTS_DIR)/*.json 2>/dev/null | head -3 || echo "⚠️  No JSON files found"
	@ls -la $(REPORTS_DIR)/*.csv 2>/dev/null | head -3 || echo "⚠️  No CSV files found"
	@ls -la $(REPORTS_DIR)/*.xlsx 2>/dev/null | head -1 || echo "⚠️  No Excel files found"
	@echo "✅ Validation complete"

validate-reports: validate ## Run validation (alias for backward compatibility)
	@echo "✅ Report validation complete"

show-reports: ## Display information about generated reports
	@echo "📊 Generated Reports Summary"
	@echo "============================="
	@echo
	@if [ -d "$(REPORTS_DIR)" ]; then \
		echo "📂 Reports directory: $(REPORTS_DIR)"; \
		echo; \
		echo "📄 JSON Data Files:"; \
		ls -la $(REPORTS_DIR)/*.json 2>/dev/null | tail -4 | sed 's/^/  /' || echo "  No JSON files found"; \
		echo; \
		echo "📋 CSV Report Files:"; \
		ls -la $(REPORTS_DIR)/*.csv 2>/dev/null | tail -4 | sed 's/^/  /' || echo "  No CSV files found"; \
		echo; \
		echo "📊 Excel Workbook:"; \
		ls -la $(REPORTS_DIR)/*.xlsx 2>/dev/null | tail -1 | sed 's/^/  /' || echo "  No Excel files found"; \
		echo; \
		TOTAL_FILES=$$(find $(REPORTS_DIR) -type f \( -name "*.json" -o -name "*.csv" -o -name "*.xlsx" \) | wc -l); \
		echo "📈 Total files: $$TOTAL_FILES"; \
	else \
		echo "❌ Reports directory not found. Run 'make sample-data' first."; \
	fi

open-excel: ## Open the latest Excel workbook (macOS)
	@LATEST_EXCEL=$$(ls -t $(REPORTS_DIR)/*.xlsx 2>/dev/null | head -1); \
	if [ -n "$$LATEST_EXCEL" ]; then \
		echo "📊 Opening Excel workbook: $$LATEST_EXCEL"; \
		open "$$LATEST_EXCEL"; \
	else \
		echo "❌ No Excel workbook found. Run 'make excel-reports' first."; \
	fi

dev-workflow: clean all show-reports ## Complete development workflow with summary
	@echo "🎉 Development workflow complete!"
	@echo "Next steps:"
	@echo "  1. Review generated reports with: make show-reports"
	@echo "  2. Open Excel workbook with: make open-excel"
	@echo "  3. Run validation with: make validate"

benchmark: ## Generate data with different seeds for benchmarking
	@echo "⏱️  Running benchmark with multiple seeds..."
	@for seed in 42 123 456 789; do \
		echo "Generating data with seed $$seed..."; \
		cd $(SAMPLE_DATA_DIR) && $(PYTHON) generate-sample-data.py --seed $$seed; \
		$(PYTHON) $(SCRIPTS_DIR)/generate-reports.py --reports-dir $(REPORTS_DIR) --verbose; \
	done
	@echo "✅ Benchmark complete"

deploy-pipeline: ## Deploy Concourse pipeline (requires foundation parameter)
	@if [ -z "$(FOUNDATION)" ]; then \
		echo "❌ FOUNDATION parameter required"; \
		echo "Example: make deploy-pipeline FOUNDATION=dc01-k8s-n-01"; \
		exit 1; \
	fi
	@echo "🚀 Deploying pipeline for foundation: $(FOUNDATION)"
	@./ci/fly.sh set -f $(FOUNDATION) $(if $(filter true,$(VERBOSE)),-v)
	@echo "✅ Pipeline deployed"

# Development utility targets
lint: ## Run static analysis on shell scripts (requires shellcheck)
	@echo "🔍 Running shellcheck on scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -not -path "./node_modules/*" -exec shellcheck {} \; || echo "⚠️  Shellcheck warnings found"; \
	else \
		echo "⚠️  shellcheck not installed, skipping lint"; \
	fi

check-env: ## Check local environment and dependencies
	@echo "🔧 Checking environment..."
	@echo "Python version: $$($(PYTHON) --version)"
	@echo "Python path: $$(which $(PYTHON))"
	@echo "Working directory: $$(pwd)"
	@echo "Foundation: $(FOUNDATION)"
	@echo "Seed: $(SEED)"
	@echo "Sample data dir: $(SAMPLE_DATA_DIR)"
	@$(PYTHON) -c "import openpyxl; print('✅ openpyxl available')" 2>/dev/null || echo "⚠️  openpyxl not available"
	@echo "✅ Environment check complete"

# Hidden utility targets (not shown in help)
.PHONY: _create_dirs _check_python

_create_dirs:
	@mkdir -p $(REPORTS_DIR) data reports

_check_python:
	@which $(PYTHON) > /dev/null || (echo "❌ Python 3 not found" && exit 1)

# Add dependencies
sample-data: venv _create_dirs
csv-reports: venv
excel-reports: venv
test-foundation: venv

##@ Docker Testing

docker-build: ## Build test container image
	@printf "$(CYAN)Building Docker test image...$(NC)\n"
	@docker build -f Dockerfile.test -t tkgi-app-tracker-test:latest .
	@printf "$(GREEN)✅ Docker test image built$(NC)\n"

docker-test: ## Run pipeline tasks using Docker (TASK=collect-data|aggregate-data|generate-reports|package-reports|run-tests|dev|full-pipeline)
	@printf "$(CYAN)Running Docker-based task testing...$(NC)\n"
	@./scripts/docker-test.sh $(TASK) $(if $(FOUNDATION),-f $(FOUNDATION)) $(if $(filter true,$(VERBOSE)),-v)

docker-dev: ## Start interactive Docker development environment
	@printf "$(CYAN)Starting Docker development environment...$(NC)\n"
	@./scripts/docker-test.sh dev -i

docker-clean: ## Clean up Docker containers and images
	@printf "$(CYAN)Cleaning up Docker resources...$(NC)\n"
	@docker-compose -f docker-compose.test.yml down --volumes --remove-orphans 2>/dev/null || true
	@docker rmi tkgi-app-tracker-test:latest 2>/dev/null || true
	@printf "$(GREEN)✅ Docker resources cleaned$(NC)\n"

##@ Testing

test: ## Run complete test suite (unit + integration + shell tests)
	@printf "$(CYAN)Running complete test suite...$(NC)\n"
	@./tests/run-all-tests.sh $(if $(filter true,$(VERBOSE)),--verbose)

test-unit: ## Run Python unit tests only
	@printf "$(CYAN)Running Python unit tests...$(NC)\n"
	@./tests/run-all-tests.sh --unit-only $(if $(filter true,$(VERBOSE)),--verbose)

test-integration: ## Run integration tests only
	@printf "$(CYAN)Running integration tests...$(NC)\n"
	@./tests/run-all-tests.sh --integration-only $(if $(filter true,$(VERBOSE)),--verbose)

test-shell: ## Run shell script tests (BATS) only
	@printf "$(CYAN)Running shell script tests...$(NC)\n"
	@./tests/run-all-tests.sh --bats-only $(if $(filter true,$(VERBOSE)),--verbose)

test-jq: ## Validate jq syntax in scripts
	@printf "$(CYAN)Running jq syntax validation...$(NC)\n"
	@./tests/test-jq-syntax.sh

test-json-combo: ## Test JSON combination logic
	@printf "$(CYAN)Running JSON combination tests...$(NC)\n"
	@bats tests/test-json-combination.bats

test-coverage: ## Run tests with coverage reporting
	@printf "$(CYAN)Running tests with coverage reporting...$(NC)\n"
	@./tests/run-all-tests.sh --coverage $(if $(filter true,$(VERBOSE)),--verbose)

test-ci: ## Run tests in CI mode (fail fast, machine readable output)
	@printf "$(CYAN)Running tests in CI mode...$(NC)\n"
	@./tests/run-all-tests.sh --ci

test-clean: ## Clean test output and temporary files
	@printf "$(CYAN)Cleaning test output...$(NC)\n"
	@rm -rf tests/output tests/mocks
	@printf "$(GREEN)✅ Test output cleaned$(NC)\n"

##@ Utilities

zip-changes: ## Create zip file of all unstaged git changes preserving directory structure
	@printf "$(CYAN)Creating zip file of unstaged changes...$(NC)\n"
	@rm -rf /tmp/zip-staging 2>/dev/null || true
	@mkdir -p /tmp/zip-staging
	@PROJECT_NAME=$$(basename "$$(pwd)"); \
	if git status --porcelain | grep -q "^ M"; then \
		git status --porcelain | grep "^ M" | cut -c4- | while read file; do \
			mkdir -p "/tmp/zip-staging/$$PROJECT_NAME/$$(dirname "$$file")"; \
			cp "$$file" "/tmp/zip-staging/$$PROJECT_NAME/$$file"; \
		done; \
		cd /tmp/zip-staging && zip -r "$${OLDPWD}/$$PROJECT_NAME-modified-files.zip" "$$PROJECT_NAME/"; \
		cd - > /dev/null; \
		rm -rf /tmp/zip-staging; \
		printf "$(GREEN)✅ Created $$PROJECT_NAME-modified-files.zip$(NC)\n"; \
		ls -lh "$$PROJECT_NAME-modified-files.zip"; \
	else \
		printf "$(YELLOW)⚠️  No unstaged changes found$(NC)\n"; \
	fi
