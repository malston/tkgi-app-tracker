#!/usr/bin/env bash

set -euo pipefail

# Docker-based testing for TKGI Application Tracker pipeline tasks
# This script provides a way to test Concourse tasks locally using Docker containers
# that mirror the production execution environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
TASK=""
VERBOSE=false
CLEANUP=true
INTERACTIVE=false
FOUNDATION="dc01-k8s-n-01"

function usage() {
    cat << EOF
Usage: $0 <task> [OPTIONS]

Test TKGI Application Tracker pipeline tasks using Docker containers that mirror
the Concourse execution environment.

TASKS:
    collect-data      Test data collection from TKGI clusters
    aggregate-data    Test data aggregation across multiple clusters
    generate-reports  Test CSV and JSON report generation
    package-reports   Test report packaging for distribution
    run-tests         Run unit and integration tests
    validate-scripts  Validate shell scripts, Python syntax, and YAML files
    notify            Test Teams notification functionality
    dev               Start interactive development environment
    full-pipeline     Run complete pipeline sequence

OPTIONS:
    -f, --foundation FOUNDATION    Foundation name for testing (default: dc01-k8s-n-01)
    -v, --verbose                  Enable verbose output
    --no-cleanup                   Don't clean up containers after execution
    -i, --interactive              Run task interactively (bash shell)
    -h, --help                     Display this help message

ENVIRONMENT VARIABLES:
    OM_TARGET                     Ops Manager endpoint (for testing)
    OM_CLIENT_ID                  OAuth2 client ID (for testing)
    OM_CLIENT_SECRET              OAuth2 client secret (for testing)
    TKGI_API_ENDPOINT             TKGI API endpoint (for testing)

EXAMPLES:
    # Test data collection task
    $0 collect-data -f dc01-k8s-n-01

    # Run complete pipeline with verbose output
    $0 full-pipeline -v

    # Start interactive development environment
    $0 dev -i

    # Test with custom foundation
    $0 aggregate-data -f dc02-k8s-n-01 --verbose

NOTES:
    - Tasks run in Ubuntu 22.04 containers with tools similar to production
    - Test data is provided in ./test-data directory
    - Output is written to ./test-output directory
    - Use 'dev' task for debugging and interactive development
    - Containers are automatically cleaned up unless --no-cleanup is used

EOF
}

function info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

function success() {
    echo -e "${GREEN}✅ $*${NC}"
}

function warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

function error() {
    echo -e "${RED}❌ $*${NC}"
}

function setup_test_data() {
    info "Setting up test data directory..."

    mkdir -p "${PROJECT_ROOT}/test-data"
    mkdir -p "${PROJECT_ROOT}/test-output"

    # Create basic test parameters file
    cat > "${PROJECT_ROOT}/test-data/foundation-params.yml" << 'EOF'
# Test parameters for foundation
foundation: dc01-k8s-n-01
datacenter: dc01
environment: lab

# Test TKGI configuration
om_target: opsman.acme.com
om_client_id: test-client-id
om_client_secret: test-client-secret
tkgi_api_endpoint: api.pks.acme.com

# Test cluster list
clusters:
  - cluster-web-01
  - cluster-api-01
  - cluster-data-01
EOF

    success "Test data directory setup complete"
}

function cleanup_containers() {
    if [[ "$CLEANUP" == "true" ]]; then
        info "Cleaning up Docker containers..."
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose.test.yml down --volumes --remove-orphans 2>/dev/null || true
        success "Cleanup complete"
    fi
}

function run_task() {
    local task="$1"

    info "Running task: $task"

    cd "$PROJECT_ROOT"

    # Set up environment variables for Docker Compose
    export FOUNDATION="$FOUNDATION"
    export DATACENTER
    DATACENTER=$(echo "$FOUNDATION" | cut -d'-' -f1)
    export ENVIRONMENT
    case "$DATACENTER" in
        dc01) ENVIRONMENT="lab" ;;
        *) ENVIRONMENT="nonprod" ;;
    esac

    # Use test credentials if not provided
    export OM_TARGET="${OM_TARGET:-opsman.acme.com}"
    export OM_CLIENT_ID="${OM_CLIENT_ID:-test-client}"
    export OM_CLIENT_SECRET="${OM_CLIENT_SECRET:-test-secret}"
    export TKGI_API_ENDPOINT="${TKGI_API_ENDPOINT:-api.pks.acme.com}"

    if [[ "$INTERACTIVE" == "true" ]] && [[ "$task" == "dev" ]]; then
        info "Starting interactive development environment..."
        docker-compose -f docker-compose.test.yml run --rm "$task"
    else
        if [[ "$VERBOSE" == "true" ]]; then
            docker-compose -f docker-compose.test.yml up --abort-on-container-exit "$task"
        else
            docker-compose -f docker-compose.test.yml up --abort-on-container-exit "$task" > /dev/null
        fi
    fi

    # Check exit code
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        success "Task '$task' completed successfully"
    else
        error "Task '$task' failed with exit code $exit_code"
        return $exit_code
    fi
}

function run_full_pipeline() {
    info "Running full pipeline test sequence..."

    local tasks=("collect-data" "aggregate-data" "generate-reports" "package-reports" "run-tests" "validate-scripts")

    for task in "${tasks[@]}"; do
        info "Pipeline step: $task"
        if ! run_task "$task"; then
            error "Pipeline failed at step: $task"
            return 1
        fi
    done

    success "Full pipeline test completed successfully!"
}

function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            collect-data|aggregate-data|generate-reports|package-reports|run-tests|validate-scripts|notify|dev|full-pipeline)
                TASK="$1"
                shift
                ;;
            -f|--foundation)
                FOUNDATION="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate task is specified
    if [[ -z "$TASK" ]]; then
        error "Task must be specified"
        usage
        exit 1
    fi

    # Check Docker is available
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is required but not installed"
        exit 1
    fi

    # Setup cleanup trap
    trap cleanup_containers EXIT

    # Setup test environment
    setup_test_data

    info "TKGI Application Tracker - Docker Task Testing"
    info "============================================="
    info "Task: $TASK"
    info "Foundation: $FOUNDATION"
    info "Verbose: $VERBOSE"
    info "Interactive: $INTERACTIVE"

    # Run the requested task
    if [[ "$TASK" == "full-pipeline" ]]; then
        run_full_pipeline
    else
        run_task "$TASK"
    fi

    success "Docker task testing completed!"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
