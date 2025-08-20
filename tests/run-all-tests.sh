#!/usr/bin/env bash

# TKGI Application Tracker - Complete Test Suite Runner
# Runs all tests with coverage reporting and CI-friendly output

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test configuration
RUN_UNIT_TESTS=true
RUN_INTEGRATION_TESTS=true
RUN_BATS_TESTS=true
GENERATE_COVERAGE=false
VERBOSE=false
CI_MODE=false
FAIL_FAST=false

# Test results tracking
TOTAL_TEST_SUITES=0
PASSED_TEST_SUITES=0
FAILED_TEST_SUITES=0
FAILED_SUITES=()

function usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive test suite for TKGI Application Tracker

OPTIONS:
    --unit-only         Run only Python unit tests
    --integration-only  Run only integration tests
    --bats-only         Run only BATS shell tests
    --coverage          Generate coverage reports (requires coverage.py)
    --ci                CI mode - machine readable output, fail fast
    --verbose           Verbose output
    --fail-fast         Stop on first test failure
    -h, --help          Display this help message

EXAMPLES:
    $0                  Run all tests
    $0 --unit-only      Run only Python unit tests
    $0 --ci --coverage  Run all tests in CI mode with coverage
    $0 --verbose        Run with detailed output

REQUIREMENTS:
    - Python 3.9+ with unittest
    - BATS testing framework (for shell tests)
    - coverage.py (optional, for coverage reports)
    - Docker (for integration tests)

EXIT CODES:
    0  All tests passed
    1  Some tests failed
    2  Test setup/environment error
    3  Missing dependencies
EOF
}

function log_info() {
    if [[ "$CI_MODE" == "false" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    else
        echo "INFO: $*"
    fi
}

function log_success() {
    if [[ "$CI_MODE" == "false" ]]; then
        echo -e "${GREEN}[PASS]${NC} $*"
    else
        echo "PASS: $*"
    fi
}

function log_error() {
    if [[ "$CI_MODE" == "false" ]]; then
        echo -e "${RED}[FAIL]${NC} $*" >&2
    else
        echo "FAIL: $*" >&2
    fi
}

function log_warn() {
    if [[ "$CI_MODE" == "false" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $*" >&2
    else
        echo "WARN: $*" >&2
    fi
}

function check_dependencies() {
    log_info "Checking test dependencies..."

    local missing_deps=()

    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    # Check BATS (optional)
    if [[ "$RUN_BATS_TESTS" == "true" ]] && ! command -v bats &> /dev/null; then
        log_warn "BATS not found - shell tests will be skipped"
        RUN_BATS_TESTS=false
    fi

    # Check coverage (optional)
    if [[ "$GENERATE_COVERAGE" == "true" ]] && ! python3 -c "import coverage" 2>/dev/null; then
        log_warn "coverage.py not found - coverage reporting disabled"
        GENERATE_COVERAGE=false
    fi

    # Check Docker for integration tests
    if [[ "$RUN_INTEGRATION_TESTS" == "true" ]] && ! command -v docker &> /dev/null; then
        log_warn "Docker not found - integration tests may fail"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 3
    fi

    log_success "Dependencies check completed"
    return 0
}

function setup_test_environment() {
    log_info "Setting up test environment..."

    # Create test output directory
    mkdir -p "$TEST_OUTPUT_DIR"

    # Set test environment variables
    export TKGI_APP_TRACKER_TEST_MODE=true
    export PYTHONPATH="${PROJECT_ROOT}/scripts:${PYTHONPATH:-}"

    # Set up PATH for test utilities
    export PATH="${SCRIPT_DIR}:${PATH}"

    log_success "Test environment ready"
}

function run_python_unit_tests() {
    log_info "Running Python unit tests..."

    TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))

    local test_files=(
        "${SCRIPT_DIR}/test_aggregate_data.py"
        "${SCRIPT_DIR}/test_generate_reports.py"
    )

    local python_cmd="python3"
    local test_args=()

    if [[ "$GENERATE_COVERAGE" == "true" ]]; then
        python_cmd="python3 -m coverage"
        test_args+=("run" "--parallel-mode" "--source=${PROJECT_ROOT}/scripts")
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        test_args+=("-v")
    fi

    local python_test_failed=false

    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            log_info "Running $(basename "$test_file")..."

            local output_file
            output_file="${TEST_OUTPUT_DIR}/$(basename "$test_file" .py).log"

            if [[ "$VERBOSE" == "true" ]]; then
                if $python_cmd "${test_args[@]}" "$test_file"; then
                    log_success "$(basename "$test_file") passed"
                else
                    log_error "$(basename "$test_file") failed"
                    python_test_failed=true
                    if [[ "$FAIL_FAST" == "true" ]]; then
                        return 1
                    fi
                fi
            else
                if $python_cmd "${test_args[@]}" "$test_file" > "$output_file" 2>&1; then
                    log_success "$(basename "$test_file") passed"
                else
                    log_error "$(basename "$test_file") failed - see $output_file"
                    python_test_failed=true
                    if [[ "$FAIL_FAST" == "true" ]]; then
                        return 1
                    fi
                fi
            fi
        fi
    done

    # Combine coverage data if generated
    if [[ "$GENERATE_COVERAGE" == "true" ]]; then
        log_info "Combining coverage data..."
        cd "$PROJECT_ROOT"
        python3 -m coverage combine
        python3 -m coverage report > "${TEST_OUTPUT_DIR}/coverage-report.txt"
        python3 -m coverage html -d "${TEST_OUTPUT_DIR}/coverage-html"
        log_success "Coverage report generated in ${TEST_OUTPUT_DIR}/coverage-html/"
    fi

    if [[ "$python_test_failed" == "true" ]]; then
        FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
        FAILED_SUITES+=("Python Unit Tests")
        return 1
    else
        PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
        return 0
    fi
}

function run_bats_tests() {
    log_info "Running BATS shell tests..."

    TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))

    if ! command -v bats &> /dev/null; then
        log_warn "BATS not available - skipping shell tests"
        return 0
    fi

    local bats_files=(
        "${SCRIPT_DIR}/test_foundation_utils.bats"
        "${SCRIPT_DIR}/test_helpers.bats"
    )

    local bats_failed=false

    for bats_file in "${bats_files[@]}"; do
        if [[ -f "$bats_file" ]]; then
            log_info "Running $(basename "$bats_file")..."

            local output_file
            output_file="${TEST_OUTPUT_DIR}/$(basename "$bats_file" .bats).log"

            if [[ "$VERBOSE" == "true" ]]; then
                if bats "$bats_file"; then
                    log_success "$(basename "$bats_file") passed"
                else
                    log_error "$(basename "$bats_file") failed"
                    bats_failed=true
                    if [[ "$FAIL_FAST" == "true" ]]; then
                        return 1
                    fi
                fi
            else
                if bats "$bats_file" > "$output_file" 2>&1; then
                    log_success "$(basename "$bats_file") passed"
                else
                    log_error "$(basename "$bats_file") failed - see $output_file"
                    bats_failed=true
                    if [[ "$FAIL_FAST" == "true" ]]; then
                        return 1
                    fi
                fi
            fi
        fi
    done

    if [[ "$bats_failed" == "true" ]]; then
        FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
        FAILED_SUITES+=("BATS Shell Tests")
        return 1
    else
        PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
        return 0
    fi
}

function run_integration_tests() {
    log_info "Running integration tests..."

    TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))

    local integration_test="${SCRIPT_DIR}/test_pipeline_integration.sh"

    if [[ ! -f "$integration_test" ]]; then
        log_error "Integration test file not found: $integration_test"
        FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
        FAILED_SUITES+=("Integration Tests")
        return 1
    fi

    local output_file
    output_file="${TEST_OUTPUT_DIR}/integration-tests.log"

    if [[ "$VERBOSE" == "true" ]]; then
        if "$integration_test"; then
            log_success "Integration tests passed"
            PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
            return 0
        else
            log_error "Integration tests failed"
            FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
            FAILED_SUITES+=("Integration Tests")
            return 1
        fi
    else
        if "$integration_test" > "$output_file" 2>&1; then
            log_success "Integration tests passed"
            PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
            return 0
        else
            log_error "Integration tests failed - see $output_file"
            FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
            FAILED_SUITES+=("Integration Tests")
            return 1
        fi
    fi
}

function generate_test_report() {
    local report_file="${TEST_OUTPUT_DIR}/test-report.txt"

    # Ensure output directory exists
    mkdir -p "${TEST_OUTPUT_DIR}"

    {
        echo "TKGI Application Tracker - Test Report"
        echo "======================================"
        echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""
        echo "Test Summary:"
        echo "  Total Test Suites: $TOTAL_TEST_SUITES"
        echo "  Passed: $PASSED_TEST_SUITES"
        echo "  Failed: $FAILED_TEST_SUITES"
        echo ""

        if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
            echo "Failed Test Suites:"
            for suite in "${FAILED_SUITES[@]}"; do
                echo "  - $suite"
            done
            echo ""
        fi

        if [[ "$GENERATE_COVERAGE" == "true" && -f "${TEST_OUTPUT_DIR}/coverage-report.txt" ]]; then
            echo "Coverage Report:"
            cat "${TEST_OUTPUT_DIR}/coverage-report.txt"
            echo ""
        fi

        echo "Test Environment:"
        echo "  Python: $(python3 --version 2>&1)"
        echo "  BATS: $(command -v bats &>/dev/null && bats --version || echo 'Not available')"
        echo "  Docker: $(command -v docker &>/dev/null && docker --version || echo 'Not available')"
        echo ""

        echo "Test Logs Available:"
        find "$TEST_OUTPUT_DIR" -name "*.log" -exec basename {} \; | sort

    } > "$report_file"

    log_info "Test report generated: $report_file"
}

function print_test_summary() {
    if [[ "$CI_MODE" == "false" ]]; then
        echo -e "\n${BLUE}============================================${NC}"
        echo -e "${BLUE}         TEST EXECUTION SUMMARY${NC}"
        echo -e "${BLUE}============================================${NC}"
    else
        echo "TEST_SUMMARY_START"
    fi

    echo "Total Test Suites: $TOTAL_TEST_SUITES"
    echo "Passed: $PASSED_TEST_SUITES"
    echo "Failed: $FAILED_TEST_SUITES"

    if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
        echo ""
        echo "Failed Test Suites:"
        for suite in "${FAILED_SUITES[@]}"; do
            echo "  - $suite"
        done
    fi

    if [[ "$CI_MODE" == "true" ]]; then
        echo "TEST_SUMMARY_END"
    fi

    if [[ $FAILED_TEST_SUITES -eq 0 ]]; then
        log_success "ALL TESTS PASSED"
        return 0
    else
        log_error "SOME TESTS FAILED"
        return 1
    fi
}

function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-only)
                RUN_UNIT_TESTS=true
                RUN_INTEGRATION_TESTS=false
                RUN_BATS_TESTS=false
                shift
                ;;
            --integration-only)
                RUN_UNIT_TESTS=false
                RUN_INTEGRATION_TESTS=true
                RUN_BATS_TESTS=false
                shift
                ;;
            --bats-only)
                RUN_UNIT_TESTS=false
                RUN_INTEGRATION_TESTS=false
                RUN_BATS_TESTS=true
                shift
                ;;
            --coverage)
                GENERATE_COVERAGE=true
                shift
                ;;
            --ci)
                CI_MODE=true
                FAIL_FAST=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --fail-fast)
                FAIL_FAST=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    # Check dependencies
    if ! check_dependencies; then
        exit $?
    fi

    # Setup test environment
    setup_test_environment

    if [[ "$CI_MODE" == "false" ]]; then
        log_info "TKGI Application Tracker - Test Suite Runner"
        log_info "============================================"
    fi

    # Run test suites
    if [[ "$RUN_UNIT_TESTS" == "true" ]]; then
        run_python_unit_tests || true
    fi

    if [[ "$RUN_BATS_TESTS" == "true" ]]; then
        run_bats_tests || true
    fi

    if [[ "$RUN_INTEGRATION_TESTS" == "true" ]]; then
        run_integration_tests || true
    fi

    # Generate test report
    generate_test_report

    # Print summary and exit
    if print_test_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
