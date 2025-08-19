#!/usr/bin/env bash
#
# Script: run-pipeline-task.sh
# Description: [DEPRECATED] Local execution wrapper for TKGI App Tracker pipeline tasks
# Usage: ./scripts/run-pipeline-task.sh [task-name] [options]
#
# ⚠️  DEPRECATION NOTICE ⚠️
# This local wrapper script has limitations and cannot replicate the exact
# Concourse execution environment. Use Docker-based testing instead:
#
#   make docker-test TASK=collect-data FOUNDATION=dc01-k8s-n-01
#   
# See docs/docker-testing-guide.md for comprehensive testing instructions.
#

set -o errexit
set -o pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# Source foundation utilities
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/foundation-utils.sh"

# Available tasks
AVAILABLE_TASKS=(
    "collect-data"
    "aggregate-data"
    "generate-reports"
    "package-reports"
    "notify"
    "run-tests"
    "validate-scripts"
    "full-pipeline"
)

# Default values
TASK=""
FOUNDATION=""
DRY_RUN=false
VERBOSE=false
OUTPUT_DIR="${REPO_ROOT}/local-output"

# Function to display usage
function usage() {
    echo "Usage: $0 <task> [options]"
    echo ""
    echo "Available tasks:"
    for task in "${AVAILABLE_TASKS[@]}"; do
        echo "  ${task}"
    done
    echo ""
    echo "Options:"
    echo "  -f FOUNDATION   Foundation name (e.g., dc01-k8s-n-01)"
    echo "  -o OUTPUT_DIR   Output directory (default: ./local-output)"
    echo "  -v              Verbose output"
    echo "  --dry-run       Show what would be done without executing"
    echo "  -h, --help      Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 collect-data -f dc01-k8s-n-01"
    echo "  $0 aggregate-data -o /tmp/my-output"
    echo "  $0 full-pipeline -f dc02-k8s-n-01 -v"
    echo ""
    echo "Environment Variables (optional):"
    echo "  OM_TARGET                    - Ops Manager endpoint"
    echo "  OM_CLIENT_ID                 - OAuth2 client ID"
    echo "  OM_CLIENT_SECRET             - OAuth2 client secret"
    echo "  TKGI_API_ENDPOINT            - TKGI API endpoint"
    echo "  TEAMS_WEBHOOK_URL            - Teams notification webhook"
    exit 1
}

# Function to setup local environment
function setup_local_environment() {
    echo "Setting up local execution environment..."

    # Create output directories
    mkdir -p "${OUTPUT_DIR}"/{collected-data,aggregated-data,generated-reports,packaged-reports}

    # Set environment variables for task execution
    export FOUNDATION="${FOUNDATION}"
    DATACENTER=$(get_datacenter "${FOUNDATION}")
    export DATACENTER
    ENVIRONMENT=$(get_environment_from_foundation "${FOUNDATION}")
    export ENVIRONMENT

    if [[ "${VERBOSE}" == "true" ]]; then
        echo "Foundation: ${FOUNDATION}"
        echo "Datacenter: ${DATACENTER}"
        echo "Environment: ${ENVIRONMENT}"
        echo "Output directory: ${OUTPUT_DIR}"
    fi
}

# Function to load foundation parameters from local params file
function load_foundation_parameters() {
    if [[ -z "${FOUNDATION}" ]]; then
        echo "Warning: No foundation specified, using environment variables"
        return 0
    fi

    local datacenter
    datacenter=$(get_datacenter "${FOUNDATION}")
    local params_file="${HOME}/git/params/${datacenter}/${datacenter}-k8s-tkgi-app-tracker.yml"

    if [[ -f "${params_file}" ]]; then
        echo "Loading parameters from: ${params_file}"

        # Extract parameters using yq or grep (basic YAML parsing)
        if command -v yq &> /dev/null; then
            export OM_TARGET="${OM_TARGET:-$(yq e '.om_target' "${params_file}")}"
            export TKGI_API_ENDPOINT="${TKGI_API_ENDPOINT:-$(yq e '.tkgi_api_endpoint' "${params_file}")}"
            export TEAMS_WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-$(yq e '.teams_webhook_url' "${params_file}")}"
        else
            echo "Warning: yq not installed, using environment variables only"
        fi
    else
        echo "Warning: Parameters file not found: ${params_file}"
        echo "Using environment variables only"
    fi
}

# Function to execute collect-data task
function run_collect_data() {
    echo "Running collect-data task..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/collect-data/task.sh"
        return 0
    fi

    # Change to task directory and execute
    cd "${REPO_ROOT}/ci/tasks/collect-data"

    # Set up task inputs (simulate Concourse inputs)
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export CONFIG_REPO="${HOME}/git/config-lab"  # Adjust based on environment
    export COLLECTED_DATA_DIR="${OUTPUT_DIR}/collected-data"

    mkdir -p "${COLLECTED_DATA_DIR}"

    # Execute the task
    bash task.sh

    echo "✅ collect-data task completed"
    echo "Output available in: ${COLLECTED_DATA_DIR}"
}

# Function to execute aggregate-data task
function run_aggregate_data() {
    echo "Running aggregate-data task..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/aggregate-data/task.sh"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/aggregate-data"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export COLLECTED_DATA_DIR="${OUTPUT_DIR}/collected-data"
    export AGGREGATED_DATA_DIR="${OUTPUT_DIR}/aggregated-data"

    mkdir -p "${AGGREGATED_DATA_DIR}"

    # Check if input data exists
    if [[ ! -d "${COLLECTED_DATA_DIR}" || -z "$(ls -A "${COLLECTED_DATA_DIR}" 2>/dev/null)" ]]; then
        echo "Error: No collected data found in ${COLLECTED_DATA_DIR}"
        echo "Run 'collect-data' task first or provide existing data"
        exit 1
    fi

    bash task.sh

    echo "✅ aggregate-data task completed"
    echo "Output available in: ${AGGREGATED_DATA_DIR}"
}

# Function to execute generate-reports task
function run_generate_reports() {
    echo "Running generate-reports task..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/generate-reports/task.sh"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/generate-reports"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export AGGREGATED_DATA_DIR="${OUTPUT_DIR}/aggregated-data"
    export GENERATED_REPORTS_DIR="${OUTPUT_DIR}/generated-reports"

    mkdir -p "${GENERATED_REPORTS_DIR}"

    # Check if input data exists
    if [[ ! -d "${AGGREGATED_DATA_DIR}" || -z "$(ls -A "${AGGREGATED_DATA_DIR}" 2>/dev/null)" ]]; then
        echo "Error: No aggregated data found in ${AGGREGATED_DATA_DIR}"
        echo "Run 'aggregate-data' task first or provide existing data"
        exit 1
    fi

    bash task.sh

    echo "✅ generate-reports task completed"
    echo "Output available in: ${GENERATED_REPORTS_DIR}"
}

# Function to execute package-reports task
function run_package_reports() {
    echo "Running package-reports task..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/package-reports/task.sh"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/package-reports"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export GENERATED_REPORTS_DIR="${OUTPUT_DIR}/generated-reports"
    export PACKAGED_REPORTS_DIR="${OUTPUT_DIR}/packaged-reports"

    mkdir -p "${PACKAGED_REPORTS_DIR}"

    # Check if input data exists
    if [[ ! -d "${GENERATED_REPORTS_DIR}" || -z "$(ls -A "${GENERATED_REPORTS_DIR}" 2>/dev/null)" ]]; then
        echo "Error: No generated reports found in ${GENERATED_REPORTS_DIR}"
        echo "Run 'generate-reports' task first or provide existing data"
        exit 1
    fi

    bash task.sh

    echo "✅ package-reports task completed"
    echo "Output available in: ${PACKAGED_REPORTS_DIR}"
}

# Function to execute notify task
function run_notify() {
    echo "Running notify task..."

    local message="${MESSAGE:-Test notification from local execution}"
    local notification_type="${NOTIFICATION_TYPE:-info}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would send notification: ${message}"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/notify"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export MESSAGE="${message}"
    export NOTIFICATION_TYPE="${notification_type}"
    export WEBHOOK_URL="${TEAMS_WEBHOOK_URL}"

    if [[ -z "${WEBHOOK_URL}" ]]; then
        echo "Warning: TEAMS_WEBHOOK_URL not set, skipping notification"
        return 0
    fi

    bash task.sh

    echo "✅ notify task completed"
}

# Function to execute run-tests task
function run_tests() {
    echo "Running test suite..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/run-tests/task.sh"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/run-tests"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export TEST_OUTPUT_DIR="${OUTPUT_DIR}/test-results"

    mkdir -p "${TEST_OUTPUT_DIR}"

    bash task.sh

    echo "✅ run-tests task completed"
    echo "Test results available in: ${TEST_OUTPUT_DIR}"
}

# Function to execute validate-scripts task
function run_validate_scripts() {
    echo "Running script validation..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute: ${REPO_ROOT}/ci/tasks/validate-scripts/task.sh"
        return 0
    fi

    cd "${REPO_ROOT}/ci/tasks/validate-scripts"

    # Set up task inputs
    export TASK_ROOT_DIR="${PWD}"
    export TKGI_APP_TRACKER_REPO="${REPO_ROOT}"
    export VALIDATION_OUTPUT_DIR="${OUTPUT_DIR}/validation-results"

    mkdir -p "${VALIDATION_OUTPUT_DIR}"

    bash task.sh

    echo "✅ validate-scripts task completed"
    echo "Validation results available in: ${VALIDATION_OUTPUT_DIR}"
}

# Function to execute full pipeline
function run_full_pipeline() {
    echo "Running full pipeline locally..."

    if [[ -z "${FOUNDATION}" ]]; then
        echo "Error: Foundation must be specified for full pipeline execution"
        echo "Use -f option to specify foundation (e.g., -f dc01-k8s-n-01)"
        exit 1
    fi

    echo "Executing full pipeline for foundation: ${FOUNDATION}"
    echo "Output directory: ${OUTPUT_DIR}"
    echo ""

    # Execute tasks in sequence
    run_collect_data
    echo ""

    run_aggregate_data
    echo ""

    run_generate_reports
    echo ""

    run_package_reports
    echo ""

    # Optional: send success notification
    if [[ -n "${TEAMS_WEBHOOK_URL}" ]]; then
        export MESSAGE="Local pipeline execution completed successfully for foundation ${FOUNDATION}"
        export NOTIFICATION_TYPE="success"
        run_notify
    fi

    echo ""
    echo "🎉 Full pipeline execution completed successfully!"
    echo ""
    echo "Generated outputs:"
    echo "  📊 Reports: ${OUTPUT_DIR}/generated-reports/"
    echo "  📦 Archive: ${OUTPUT_DIR}/packaged-reports/"
    echo "  📁 All outputs: ${OUTPUT_DIR}/"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
fi

TASK="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--foundation)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option $1 requires an argument"
                usage
            fi
            FOUNDATION="$2"
            shift 2
            ;;
        -o|--output-dir)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option $1 requires an argument"
                usage
            fi
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

# Validate task
if [[ ! " ${AVAILABLE_TASKS[*]} " =~ ${TASK} ]]; then
    echo "Error: Unknown task: ${TASK}"
    echo "Available tasks: ${AVAILABLE_TASKS[*]}"
    exit 1
fi

# Show deprecation warning
echo "⚠️  DEPRECATION WARNING: This local wrapper script has limitations and cannot"
echo "   replicate the exact Concourse execution environment. Consider using:"
echo ""
echo "   make docker-test TASK=${TASK} FOUNDATION=${FOUNDATION:-dc01-k8s-n-01}"
echo ""
echo "   See docs/docker-testing-guide.md for comprehensive testing instructions."
echo ""
echo "   Continuing with local execution in 3 seconds..."
sleep 3

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
    set -x
fi

# Setup environment
setup_local_environment
load_foundation_parameters

# Execute the requested task
case "${TASK}" in
    collect-data)
        run_collect_data
        ;;
    aggregate-data)
        run_aggregate_data
        ;;
    generate-reports)
        run_generate_reports
        ;;
    package-reports)
        run_package_reports
        ;;
    notify)
        run_notify
        ;;
    run-tests)
        run_tests
        ;;
    validate-scripts)
        run_validate_scripts
        ;;
    full-pipeline)
        run_full_pipeline
        ;;
    *)
        echo "Error: Task '${TASK}' not implemented"
        exit 1
        ;;
esac
