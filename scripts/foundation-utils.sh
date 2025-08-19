#!/usr/bin/env bash

# Foundation utility functions following the same patterns as ns-mgmt
# Foundation format: {datacenter}-{type}-{environment}-{instance}
# Example: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-p-01

# Function to get datacenter from foundation name
# Arguments:
#   $1 - The foundation name
# Returns:
#   The datacenter name (first part)
function get_datacenter() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f1
}

# Function to get datacenter type from foundation name
# Arguments:
#   $1 - The foundation name
# Returns:
#   The datacenter type (second part, usually "k8s")
function get_datacenter_type() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f2
}

# Function to get environment code from foundation name
# Arguments:
#   $1 - The foundation name
# Returns:
#   The environment code (third part: n=nonprod, p=prod)
function get_environment_code() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f3
}

# Function to get instance number from foundation name
# Arguments:
#   $1 - The foundation name
# Returns:
#   The instance number (fourth part)
function get_instance() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f4
}

# Function to determine environment from foundation name
# Arguments:
#   $1 - The foundation name
# Returns:
#   The environment name (lab|nonprod|prod)
function get_environment_from_foundation() {
    local foundation="$1"
    local datacenter
    datacenter=$(get_datacenter "$foundation")
    local env_code
    env_code=$(get_environment_code "$foundation")

    # Determine environment based on datacenter and environment code
    case "$datacenter" in
        dc01)
            # DC01 is always lab environment regardless of env_code
            echo "lab"
            ;;
        *)
            # For other datacenters, use environment code
            case "$env_code" in
                n)
                    echo "nonprod"
                    ;;
                p)
                    echo "prod"
                    ;;
                *)
                    echo "unknown"
                    ;;
            esac
            ;;
    esac
}

# Function to validate foundation format
# Arguments:
#   $1 - The foundation name
# Returns:
#   0 if valid, 1 if invalid
function validate_foundation_format() {
    local foundation="$1"

    # Check if foundation matches expected pattern: datacenter-type-env-instance
    # Instance must be exactly 2 digits (01, 02, etc.)
    if [[ ! "$foundation" =~ ^[a-z0-9]+-[a-z0-9]+-[lnp]-[0-9]{2}$ ]]; then
        return 1
    fi

    return 0
}

# Function to get environment-specific Concourse pipeline name
# Arguments:
#   $1 - The base pipeline name
#   $2 - The foundation name
# Returns:
#   The environment-specific pipeline name
function get_pipeline_name() {
    local base_pipeline="$1"
    local foundation="$2"
    local environment
    environment=$(get_environment_from_foundation "$foundation")

    echo "${base_pipeline}-${environment}"
}

# Function to determine foundations for an environment
# Arguments:
#   $1 - Environment (lab|nonprod|prod)
#   $@ - List of all foundations
# Returns:
#   Space-separated list of foundations for the environment
function get_foundations_for_environment() {
    local target_env="$1"
    shift
    local foundations=("$@")
    local result=()

    for foundation in "${foundations[@]}"; do
        local env
        env=$(get_environment_from_foundation "$foundation")
        if [[ "$env" == "$target_env" ]]; then
            result+=("$foundation")
        fi
    done

    echo "${result[@]}"
}
