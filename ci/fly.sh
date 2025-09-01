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
GITHUB_ORG="malston"
GIT_RELEASE_BRANCH="master"
CONFIG_GIT_BRANCH="master"
DRY_RUN=false
ENVIRONMENT=""
TEAMS_WEBHOOK_URL=""
S3_BUCKET="reports"
TIMER_DURATION="3h"
COMMAND="set"

# Function to display usage
function usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  set               Deploy the pipeline (default)
  unpause           Deploy and unpause the pipeline
  destroy           Destroy the pipeline
  validate          Validate pipeline YAML
  cross-foundation  Deploy cross-foundation reporting pipeline

Options:
  -f FOUNDATION   Foundation name (e.g., dc01-k8s-n-01, dc02-k8s-n-01)
                  Not required for cross-foundation command
  -t TARGET       Concourse target (defaults to foundation name)
  -b BRANCH       Git branch (default: $GIT_RELEASE_BRANCH)
  -v              Verbose output
  --dry-run       Show what would be done without executing
  -h, --help      Display this help message

Foundation Format: {datacenter}-{type}-{environment}-{instance}
  Examples: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-n-02

Examples:
  $0 set -f dc01-k8s-n-01                      Deploy pipeline for dc01 foundation
  $0 unpause -f dc02-k8s-n-01               Deploy and unpause pipeline for ILAB
  $0 cross-foundation                         Deploy cross-foundation aggregation pipeline
  $0 cross-foundation -t tkgi-tkgi-reporting  Deploy cross-foundation with specific target

Parameter Files (loaded in order of precedence):
  Global: $HOME/git/params/global.yml, $HOME/git/params/k8s-global.yml
  Datacenter: $HOME/git/params/{datacenter}/{datacenter}.yml
  Datacenter Type: $HOME/git/params/{datacenter}/{datacenter}-{type}.yml
  Foundation: $HOME/git/params/{datacenter}/{foundation}.yml
  Pipeline: $HOME/git/params/{datacenter}/{datacenter}-{type}-tkgi-app-tracker.yml
  Example: $HOME/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml

Cross-Foundation Parameters:
  Uses same global params: $HOME/git/params/global.yml, $HOME/git/params/k8s-global.yml
  Plus specific settings: $HOME/git/params/tkgi-app-tracker-cross-foundation.yml
EOF
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
        echo "Example: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-n-02"
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

# S3 Configuration for Reports
s3_bucket: reports
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
    local pipeline_name
    local pipeline_file
    local vars_files_array

    # Check if this is a cross-foundation pipeline call
    if [[ "${COMMAND}" == "cross-foundation" ]]; then
        pipeline_name="tkgi-app-tracker-cross-foundation"
        pipeline_file="${SCRIPT_DIR}/pipelines/cross-foundation-report.yml"

        # Load parameter files using the standard function (global params only for cross-foundation)
        IFS=" " read -r -a vars_files_array <<<"$(load_params_files "${REPO_ROOT}" "" "" "" "")"

        # Add cross-foundation specific parameters
        local params_path="${REPO_ROOT}/../params"
        if [[ -f "${params_path}/tkgi-app-tracker-cross-foundation.yml" ]]; then
            vars_files_array+=("-l" "${params_path}/tkgi-app-tracker-cross-foundation.yml")
        else
            # Create minimal cross-foundation params with only the specific values needed
            local default_params_file="${params_path}/tkgi-app-tracker-cross-foundation.yml"
            mkdir -p "${params_path}"

            cat > "${default_params_file}" <<'EOF'
# Cross-Foundation Specific Parameters
# These supplement the standard global params

# Cross-foundation specific settings
cross_foundation_list: "dc01,dc02,dc03,dc04" # Comma-separated list of foundations to aggregate
cross_foundation_schedule: "24h"             # How often to run aggregation (daily)
cross_foundation_max_age_days: "7"           # Only include reports newer than this
cross_foundation_include_charts: "true"      # Include charts in Excel workbook
EOF
            echo "Created cross-foundation params at: ${default_params_file}"
            echo "This file supplements your existing global params (global.yml, k8s-global.yml)"
            vars_files_array+=("-l" "${default_params_file}")
        fi
    else
        # Regular foundation-specific pipeline
        pipeline_name="tkgi-${PIPELINE}-${FOUNDATION}"
        pipeline_file="${SCRIPT_DIR}/pipelines/single-foundation-report.yml"

        # Load parameter files using gatekeeper pattern
        IFS=" " read -r -a vars_files_array <<<"$(load_params_files "${REPO_ROOT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${FOUNDATION}" "tkgi-app-tracker")"
    fi

    if [ ! -f "${pipeline_file}" ]; then
        echo "Error: Pipeline file not found: ${pipeline_file}"
        exit 1
    fi

    # Display deployment information
    if [[ "${COMMAND}" == "cross-foundation" ]]; then
        echo "Deploying cross-foundation aggregation pipeline..."
        echo "  Target: ${TARGET}"
        echo "  Pipeline: ${pipeline_name}"
        echo "  Pipeline file: ${pipeline_file}"
        echo "  Parameter files: ${vars_files_array[*]}"
        echo ""
    else
        echo "Deploying pipeline: ${pipeline_name}"
        echo "  Foundation: ${FOUNDATION} (${ENVIRONMENT})"
        echo "  Target: ${TARGET}"
        echo "  Pipeline file: ${pipeline_file}"
        echo "  Parameter files: ${vars_files_array[*]}"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY RUN] Would execute:"
        echo "fly -t ${TARGET} set-pipeline -p ${pipeline_name} -c ${pipeline_file} ${vars_files_array[*]}"
        return 0
    fi

    # Deploy the pipeline with appropriate variables
    if [[ "${COMMAND}" == "cross-foundation" ]]; then
        if fly -t "${TARGET}" set-pipeline \
              -p "${pipeline_name}" \
              -c "${pipeline_file}" \
              "${vars_files_array[@]}" \
              -v git_uri="${GIT_URI:-git@github.com:your-org/tkgi-app-tracker.git}" \
              -v git_release_tag="${GIT_RELEASE_BRANCH:-master}" \
              -v s3_bucket="${S3_BUCKET:-reports}"; then
            echo ""
            echo "Pipeline deployed successfully!"
            echo ""
            echo "To unpause the pipeline, run:"
            echo "  fly -t ${TARGET} unpause-pipeline -p ${pipeline_name}"
            echo ""
            echo "To trigger the pipeline manually, run:"
            echo "  fly -t ${TARGET} trigger-job -j ${pipeline_name}/aggregate-cross-foundation-data"
            echo ""
            echo "To view the pipeline in the web UI:"
            echo "  fly -t ${TARGET} pipelines | grep ${pipeline_name}"
        else
            echo "Error: Failed to deploy cross-foundation pipeline"
            exit 1
        fi
    else
        if fly -t "${TARGET}" set-pipeline \
              -p "${pipeline_name}" \
              -c "${pipeline_file}" \
              "${vars_files_array[@]}" \
              -v foundation="$FOUNDATION" \
              -v datacenter="$DATACENTER" \
              -v environment="$ENVIRONMENT" \
              -v git_uri="$GIT_URI" \
              -v git_release_tag="$GIT_RELEASE_BRANCH" \
              -v config_git_uri="$CONFIG_GIT_URI" \
              -v config_git_branch="$CONFIG_GIT_BRANCH" \
              -v s3_bucket="$S3_BUCKET" \
              -v teams_webhook_url="$TEAMS_WEBHOOK_URL"; then
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
        echo "fly -t ${TARGET} destroy-pipeline -p ${pipeline_name}"
        return 0
    fi

    if fly -t "${TARGET}" destroy-pipeline \
          -p "${pipeline_name}"; then
        echo "Pipeline destroyed successfully!"
    else
        echo "Error: Failed to destroy pipeline"
        exit 1
    fi
}

# Function to validate pipeline
function validate_pipeline() {
    local pipeline_file="${SCRIPT_DIR}/pipelines/single-foundation-report.yml"

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
        set|unpause|destroy|validate|cross-foundation)
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

# Handle cross-foundation command separately (doesn't require foundation)
if [[ "${COMMAND}" == "cross-foundation" ]]; then
    # Set default target if not provided
    if [[ -z "${TARGET}" ]]; then
        TARGET="tkgi-reporting"  # Default target for cross-foundation
    fi

    # Check if fly is logged in
    if ! fly -t "${TARGET}" status &> /dev/null; then
        echo "Error: Not logged in to target '${TARGET}'. Please run: fly -t ${TARGET} login"
        exit 1
    fi

    # Execute cross-foundation pipeline deployment
    set_pipeline
    exit 0
fi

# Validate required parameters for foundation-specific commands
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
