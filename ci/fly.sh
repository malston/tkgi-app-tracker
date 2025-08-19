#!/usr/bin/env bash
#
# Script: fly.sh
# Description: Pipeline management script for TKGI Application Tracker
# Follows the same patterns as ns-mgmt for foundation handling and parameter management
#
# Usage: ./fly.sh [options] [command]
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="${SCRIPT_DIR}"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")

# Source foundation utility functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../scripts/foundation-utils.sh"

# Initialize default values
PIPELINE="app-tracker"
GITHUB_ORG="your-org"
GIT_RELEASE_BRANCH="main"
CONFIG_GIT_BRANCH="master"
VERSION_FILE=version
DRY_RUN=false
VERBOSE=false
ENVIRONMENT=""
TIMER_DURATION="3h"
COMMAND="set"

# Function to display usage
function usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  set         Deploy the pipeline (default)"
    echo "  unpause     Deploy and unpause the pipeline"
    echo "  destroy     Destroy the pipeline"
    echo "  validate    Validate pipeline YAML"
    echo ""
    echo "Options:"
    echo "  -f FOUNDATION   Foundation name (e.g., dc01-k8s-n-01, dc02-k8s-n-01)"
    echo "  -t TARGET       Concourse target (defaults to foundation name)"
    echo "  -b BRANCH       Git branch (default: main)"
    echo "  -v              Verbose output"
    echo "  --dry-run       Show what would be done without executing"
    echo "  -h, --help      Display this help message"
    echo ""
    echo "Foundation Format: {datacenter}-{type}-{environment}-{instance}"
    echo "  Examples: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-p-01"
    echo ""
    echo "Parameter Files (loaded in order of precedence):"
    echo "  Global: ../params/global.yml, ../params/k8s-global.yml"
    echo "  Datacenter: ../params/{datacenter}/{datacenter}.yml"
    echo "  Datacenter Type: ../params/{datacenter}/{datacenter}-{type}.yml"
    echo "  Foundation: ../params/{datacenter}/{foundation}.yml"
    echo "  Pipeline: ../params/{datacenter}/{datacenter}-{type}-tkgi-app-tracker.yml"
    echo "  Example: ../params/dc01/dc01-k8s-tkgi-app-tracker.yml"
    exit 1
}

# Function to check prerequisites
function check_prerequisites() {
    # Check if fly is installed
    if ! command -v fly &> /dev/null; then
        echo "Error: 'fly' CLI not found. Please install Concourse fly CLI."
        exit 1
    fi

    # Check if logged in to target
    if ! fly -t "${TARGET}" status &> /dev/null; then
        echo "Error: Not logged in to target '${TARGET}'. Please run: fly -t ${TARGET} login"
        exit 1
    fi

    # Validate foundation format
    if ! validate_foundation_format "${FOUNDATION}"; then
        echo "Error: Invalid foundation format: ${FOUNDATION}"
        echo "Expected format: {datacenter}-{type}-{environment}-{instance}"
        echo "Example: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-p-01"
        exit 1
    fi
}

# Function to determine environment and configuration
function determine_environment() {
    # Get environment from foundation name
    ENVIRONMENT=$(get_environment_from_foundation "${FOUNDATION}")

    if [[ "${ENVIRONMENT}" == "unknown" ]]; then
        echo "Error: Could not determine environment from foundation: ${FOUNDATION}"
        exit 1
    fi

    # Determine datacenter from foundation name
    DATACENTER=$(get_datacenter "${FOUNDATION}")

    # Determine datacenter type from foundation name
    DATACENTER_TYPE=$(get_datacenter_type "${FOUNDATION}")

    # Set git URIs based on environment settings
    case "${ENVIRONMENT}" in
        lab)
            CONFIG_REPO_NAME="config-lab"
            ;;
        nonprod)
            CONFIG_REPO_NAME="config-nonprod"
            ;;
        prod)
            CONFIG_REPO_NAME="config-prod"
            ;;
    esac

    GIT_URI="git@github.com:$GITHUB_ORG/$REPO_NAME.git"
    CONFIG_GIT_URI="git@github.com:$GITHUB_ORG/$CONFIG_REPO_NAME.git"
}

# Function to load parameter files using gatekeeper pattern
function load_params_files() {
    local repo_root="$1"
    local dc="$2"
    local dctype="$3"
    local foundation="$4"
    local pipeline="$5"
    local vars_files=()

    # Params directory path - check if it exists
    local params_path="${repo_root}/../params"

    if [[ -d "$params_path" ]]; then
        # Add global params if they exist
        if [[ -f "${params_path}/global.yml" ]]; then
            vars_files+=("-l" "${params_path}/global.yml")
        fi

        if [[ -f "${params_path}/download-offline-art.yml" ]]; then
            vars_files+=("-l" "${params_path}/download-offline-art.yml")
        fi

        if [[ -f "${params_path}/k8s-global.yml" ]]; then
            vars_files+=("-l" "${params_path}/k8s-global.yml")
        fi

        if [[ -f "${params_path}/wf-root-ca-certs.yml" ]]; then
            vars_files+=("-l" "${params_path}/wf-root-ca-certs.yml")
        fi

        # Add datacenter params if they exist
        if [[ -d "${params_path}/${dc}" ]]; then
            if [[ -f "${params_path}/${dc}/${dc}.yml" ]]; then
                vars_files+=("-l" "${params_path}/${dc}/${dc}.yml")
            fi

            if [[ -f "${params_path}/${dc}/${dc}-${dctype}.yml" ]]; then
                vars_files+=("-l" "${params_path}/${dc}/${dc}-${dctype}.yml")
            fi

            if [[ -f "${params_path}/${dc}/${foundation}.yml" ]]; then
                vars_files+=("-l" "${params_path}/${dc}/${foundation}.yml")
            fi

            if [[ -f "${params_path}/${dc}/${dc}-${dctype}-${pipeline}.yml" ]]; then
                vars_files+=("-l" "${params_path}/${dc}/${dc}-${dctype}-${pipeline}.yml")
            fi
        fi
    else
        echo "Warning: Parameters directory not found: ${params_path}"
        echo "Creating default parameters structure..."

        # Create default params structure
        mkdir -p "${params_path}/${dc}"
        local default_params_file="${params_path}/${dc}/${dc}-${dctype}-${pipeline}.yml"

        cat > "${default_params_file}" <<EOF
# TKGI App Tracker Parameters for ${dc} datacenter

# Git Configuration
git_uri: ${GIT_URI}
config_git_uri: ${CONFIG_GIT_URI}
config_git_branch: ${CONFIG_GIT_BRANCH}
git_release_tag: ${GIT_RELEASE_BRANCH}
version_file: ${VERSION_FILE}

# S3 Configuration for Reports
s3_bucket: tkgi-app-tracker-reports-${ENVIRONMENT}
s3_region: us-east-1
s3_access_key_id: ((s3-access-key-id))
s3_secret_access_key: ((s3-secret-access-key))

# Concourse S3 Container Image Configuration
concourse_s3_access_key_id: ((concourse_s3_access_key_id))
concourse_s3_secret_access_key: ((concourse_s3_secret_access_key))
concourse-s3-bucket: ((concourse-s3-bucket))
concourse-s3-endpoint: ((concourse-s3-endpoint))
cflinux_current_image: ((cflinux_current_image))

# Teams Notification Configuration
teams_webhook_url: ((teams-webhook-url))

# Pipeline Configuration
timer_duration: ${TIMER_DURATION}
dry_run: ${DRY_RUN}
verbose: ${VERBOSE}

# Foundation Configuration
foundation: ${FOUNDATION}
datacenter: ${DATACENTER}
datacenter_type: ${DATACENTER_TYPE}
environment: ${ENVIRONMENT}

# TKGI/Ops Manager Configuration (use Vault interpolation)
om_target: ((${FOUNDATION}-opsman-domain))
om_client_id: ((${FOUNDATION}-om-client-id))
om_client_secret: ((${FOUNDATION}-om-client-secret))
tkgi_api_endpoint: ((${FOUNDATION}-tkgi-api-endpoint))
EOF
        echo "Default parameters file created at: ${default_params_file}"
        echo "Please edit this file with your actual values before deploying."
        vars_files+=("-l" "${default_params_file}")
    fi

    echo "${vars_files[@]}"
}

# Function to set pipeline
function set_pipeline() {
    local pipeline_name="tkgi-${PIPELINE}-${FOUNDATION}"
    local pipeline_file="${SCRIPT_DIR}/pipeline.yml"

    if [ ! -f "${pipeline_file}" ]; then
        echo "Error: Pipeline file not found: ${pipeline_file}"
        exit 1
    fi

    # Load parameter files using gatekeeper pattern
    local vars_files_array
    IFS=" " read -r -a vars_files_array <<<"$(load_params_files "${REPO_ROOT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${FOUNDATION}" "tkgi-app-tracker")"

    echo "Deploying pipeline: ${pipeline_name}"
    echo "Foundation: ${FOUNDATION} (${ENVIRONMENT})"
    echo "Pipeline file: ${pipeline_file}"
    echo "Parameter files: ${vars_files_array[*]}"
    echo "Target: ${TARGET}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute:"
        echo "fly -t ${TARGET} set-pipeline -p ${pipeline_name} -c ${pipeline_file} ${vars_files_array[*]} --non-interactive"
        return 0
    fi

    if fly -t "${TARGET}" set-pipeline \
          -p "${pipeline_name}" \
          -c "${pipeline_file}" \
          "${vars_files_array[@]}" \
          --non-interactive; then
        echo "Pipeline deployed successfully!"
        echo ""
        echo "To unpause the pipeline, run:"
        echo "  fly -t ${TARGET} unpause-pipeline -p ${pipeline_name}"
        echo ""
        echo "To trigger a manual run:"
        echo "  fly -t ${TARGET} trigger-job -j ${pipeline_name}/collect-and-report"
    else
        echo "Error: Failed to deploy pipeline"
        exit 1
    fi
}

# Function to unpause pipeline
function unpause_pipeline() {
    # First set the pipeline
    set_pipeline

    local pipeline_name="tkgi-${PIPELINE}-${FOUNDATION}"

    echo "Unpausing pipeline: ${pipeline_name}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute:"
        echo "fly -t ${TARGET} unpause-pipeline -p ${pipeline_name}"
        return 0
    fi

    
    if fly -t "${TARGET}" unpause-pipeline -p "${pipeline_name}"; then
        echo "Pipeline unpaused successfully!"
    else
        echo "Error: Failed to unpause pipeline"
        exit 1
    fi
}

# Function to destroy pipeline
function destroy_pipeline() {
    local pipeline_name="tkgi-${PIPELINE}-${FOUNDATION}"

    echo "Destroying pipeline: ${pipeline_name}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute:"
        echo "fly -t ${TARGET} destroy-pipeline -p ${pipeline_name} --non-interactive"
        return 0
    fi

    if fly -t "${TARGET}" destroy-pipeline \
          -p "${pipeline_name}" \
          --non-interactive; then
        echo "Pipeline destroyed successfully!"
    else
        echo "Error: Failed to destroy pipeline"
        exit 1
    fi
}

# Function to validate pipeline
function validate_pipeline() {
    local pipeline_file="${SCRIPT_DIR}/pipeline.yml"

    if [ ! -f "${pipeline_file}" ]; then
        echo "Error: Pipeline file not found: ${pipeline_file}"
        exit 1
    fi

    echo "Validating pipeline: ${pipeline_file}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would validate pipeline file"
        return 0
    fi

    if fly validate-pipeline -c "${pipeline_file}"; then
        echo "Pipeline validation successful!"
    else
        echo "Error: Pipeline validation failed"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        # Commands
        set|unpause|destroy|validate)
            COMMAND="$1"
            shift
            ;;
        # Options
        -f|--foundation)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option $1 requires an argument"
                usage
            fi
            FOUNDATION="$2"
            shift 2
            ;;
        -t|--target)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option $1 requires an argument"
                usage
            fi
            TARGET="$2"
            shift 2
            ;;
        -b|--branch)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: Option $1 requires an argument"
                usage
            fi
            GIT_RELEASE_BRANCH="$2"
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

# Validate required parameters
if [[ -z "${FOUNDATION}" ]]; then
    echo "Error: Foundation not specified. Use -f or --foundation option."
    usage
fi

# Set default target if not provided (foundation name for team targeting)
if [[ -z "${TARGET}" ]]; then
    TARGET="${FOUNDATION}"
fi

# Determine environment and configuration
determine_environment

# Check prerequisites
check_prerequisites

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
    set -x
fi

# Execute the requested command
case "${COMMAND}" in
    set)
        set_pipeline
        ;;
    unpause)
        unpause_pipeline
        ;;
    destroy)
        destroy_pipeline
        ;;
    validate)
        validate_pipeline
        ;;
    *)
        echo "Error: Unknown command: ${COMMAND}"
        usage
        ;;
esac
