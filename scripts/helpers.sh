#!/usr/bin/env bash

# Color definitions
export GREEN='\033[0;32m'
export CYAN='\033[0;36m'
export RED='\033[0;31m'
export YELLOW='\033[0;33m'
export NOCOLOR='\033[0m'

function info() {
    printf "${CYAN}> %s\n${NOCOLOR}" "$@" >&2
}

function warn() {
    printf "${YELLOW}! %s\n${NOCOLOR}" "$@" >&2
}

function error() {
    printf "${RED}x %s\n${NOCOLOR}" "$@" >&2
}

function completed() {
    printf "${GREEN}✔ %s\n${NOCOLOR}" "$@" >&2
}

function login_tkgi() {
    local pks_api_url=$1
    local pks_user=$2
    local pks_password=$3

    echo "Logging into TKGI (${pks_api_url})..."
    tkgi login -a "$pks_api_url" -u "${pks_user}" -p "${pks_password}" -k
}

function login_k8s() {
    local admin_password=$1
    local cluster_name=$2

    echo "$admin_password" | tkgi get-credentials "$cluster_name" >/dev/null 2>&1
    kubectl config use-context "$cluster_name"
    return $?
}

function tkgi_login() {
  local cluster=$1
  local tkgi_api_endpoint=${2:-$TKGI_API_ENDPOINT}
  local om_target=${3:-$OM_TARGET}
  local om_client_id=${4:-$OM_CLIENT_ID}
  local om_client_secret=${5:-$OM_CLIENT_SECRET}
  local admin_password
  admin_password=$(om-linux -t "${om_target}" \
      -c "${om_client_id}" \
      -s "${om_client_secret}" \
      credentials \
      -p pivotal-container-service \
      -c '.properties.uaa_admin_password' \
      -f secret)

  tkgi login -a \
      "https://${tkgi_api_endpoint}" \
      --skip-ssl-validation \
      -u "admin" \
      -p "${admin_password}" > /dev/null 2>&1

  if [[ -z ${admin_password} ]]; then
    printf "${cluster}: ${RED}%s${NOCOLOR}\n" "Error retrieving the pks admin password. Goodbye."
    exit 1
  fi

  ## Now get the credentials for the cluster
  ##
  tkgi_get_credentials "$cluster" "$admin_password" "$om_target" "$om_client_id" "$om_client_secret"
}

function tkgi_get_credentials() {
  local cluster=$1
  local admin_password=$2
  local om_target=${3:-$OM_TARGET}
  local om_client_id=${4:-$OM_CLIENT_ID}
  local om_client_secret=${5:-$OM_CLIENT_SECRET}

  if [[ -z $admin_password ]]; then
    admin_password=$(om-linux -t "${om_target}" \
      -c "${om_client_id}" \
      -s "${om_client_secret}" \
      credentials \
      -p pivotal-container-service \
      -c '.properties.uaa_admin_password' \
      -f secret)
  fi
  if ! echo "${admin_password}" | tkgi get-credentials "${cluster}" > /dev/null 2>&1; then
    printf "${cluster}: ${RED}%s${NOCOLOR}\n\n" "Could not retrieve credentials for ${cluster}. Skipping."
    exit 1
  fi

  kubectl config use-context "${cluster}" &>/dev/null
  printf "${GREEN}%s${NOCOLOR}\n" "Switched to context \"${cluster}\"." >&2
}

# Environment validation
function validate_required_env() {
    local var_name="$1"
    if [[ -z "${!var_name}" ]]; then
        error "Required environment variable $var_name is not set"
        return 1
    fi
    return 0
}

# Dependency checking
function check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Directory management
function create_output_directory() {
    local dir_path="$1"

    if [[ -z "$dir_path" ]]; then
        error "Directory path is required"
        return 1
    fi

    mkdir -p "$dir_path"
    info "Created output directory: $dir_path"
}

# Execution timing
function log_execution_time() {
    local operation="$1"
    shift
    local command=("$@")

    local start_time
    start_time=$(date +%s)

    info "Starting $operation..."
    "${command[@]}"
    local exit_code=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        completed "$operation completed in ${duration}s"
    else
        error "$operation failed after ${duration}s"
    fi

    return $exit_code
}

# Retry mechanism
function retry_command() {
    local max_attempts="$1"
    shift
    local command=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi

        warn "Command failed (attempt $attempt/$max_attempts)"
        if [[ $attempt -lt $max_attempts ]]; then
            info "Retrying in 5 seconds..."
            sleep 5
        fi

        ((attempt++))
    done

    error "Command failed after $max_attempts attempts"
    return 1
}

# JSON processing
function parse_json_field() {
    local json_file="$1"
    local field_path="$2"

    if [[ ! -f "$json_file" ]]; then
        error "JSON file not found: $json_file"
        return 1
    fi

    jq -r "$field_path" "$json_file"
}

# Date/time utilities
function format_timestamp() {
    local timestamp="$1"

    if [[ -z "$timestamp" ]]; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        # Convert input timestamp to standard format
        date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +"%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || echo "$timestamp"
    fi
}

function calculate_days_since() {
    local timestamp="$1"

    if [[ -z "$timestamp" ]]; then
        echo "999"
        return
    fi

    # Parse the timestamp and calculate days since
    local epoch_timestamp
    if command -v gdate &> /dev/null; then
        # GNU date (Linux/with gdate on macOS)
        epoch_timestamp=$(gdate -d "$timestamp" +%s 2>/dev/null || echo "0")
    else
        # BSD date (macOS) - handle ISO format
        # Remove Z and parse as UTC
        local clean_timestamp="${timestamp%Z}"
        epoch_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_timestamp" +%s 2>/dev/null || echo "0")
    fi

    if [[ "$epoch_timestamp" == "0" ]]; then
        echo "999"
        return
    fi

    local current_epoch
    current_epoch=$(date +%s)
    local diff_seconds=$((current_epoch - epoch_timestamp))
    local diff_days=$((diff_seconds / 86400))

    echo "$diff_days"
}

# Application ID utilities
function sanitize_app_id() {
    local app_id="$1"

    # Convert to lowercase and replace special characters with hyphens
    echo "$app_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

function extract_app_id() {
    local namespace_name="$1"

    # Extract application ID from namespace name
    # Assumes format: app-{id}-{env} or similar
    if [[ "$namespace_name" =~ ^app-([^-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$namespace_name" =~ ^([^-]+)-app ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Fallback: use namespace name as app ID
        sanitize_app_id "$namespace_name"
    fi
}

# Namespace classification
function is_system_namespace() {
    local namespace="$1"

    local system_namespaces=(
        "kube-system"
        "kube-public"
        "kube-node-lease"
        "default"
        "istio-system"
        "knative-serving"
        "tekton-pipelines"
        "cert-manager"
        "ingress-nginx"
        "monitoring"
        "logging"
        "velero"
        "pks-system"
        "vmware-system-auth"
        "vmware-system-csi"
        "vmware-system-tmc"
    )

    for sys_ns in "${system_namespaces[@]}"; do
        if [[ "$namespace" == "$sys_ns" ]]; then
            return 0
        fi
    done

    return 1
}
