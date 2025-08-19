#!/usr/bin/env bash
#
# Script: config-utils.sh
# Description: Utilities for reading configuration data from config repo
#
# The config repo contains authoritative information about:
# - Which clusters exist in each foundation
# - Cluster specifications and metadata
# - Namespace configurations with app metadata
#
# This script provides functions to extract this data for use by the
# TKGI Application Tracker.
#

set -o errexit
set -o pipefail

# Function to get cluster list from config repo
# Usage: get_clusters_from_config <config_repo_path> <foundation>
function get_clusters_from_config() {
    local config_repo_path="$1"
    local foundation="$2"

    if [[ -z "${config_repo_path}" || -z "${foundation}" ]]; then
        echo "Error: config_repo_path and foundation are required" >&2
        return 1
    fi

    local clusters_file="${config_repo_path}/foundations/${foundation}/clusters.yml"

    if [[ ! -f "${clusters_file}" ]]; then
        echo "Warning: Clusters file not found: ${clusters_file}" >&2
        echo "[]"  # Return empty JSON array
        return 0
    fi

    # Parse YAML to extract cluster list
    if command -v yq &> /dev/null; then
        yq e '.clusters[]' "${clusters_file}" | jq -R . | jq -s .
    else
        # Fallback: simple grep-based extraction
        grep -E '^\s*-\s+' "${clusters_file}" | sed 's/^\s*-\s*//' | jq -R . | jq -s .
    fi
}

# Function to get cluster metadata from config repo
# Usage: get_cluster_metadata <config_repo_path> <foundation> <cluster>
function get_cluster_metadata() {
    local config_repo_path="$1"
    local foundation="$2"
    local cluster="$3"

    if [[ -z "${config_repo_path}" || -z "${foundation}" || -z "${cluster}" ]]; then
        echo "Error: config_repo_path, foundation, and cluster are required" >&2
        return 1
    fi

    local cluster_file="${config_repo_path}/foundations/${foundation}/${cluster}/cluster.yaml"

    if [[ ! -f "${cluster_file}" ]]; then
        echo "Warning: Cluster file not found: ${cluster_file}" >&2
        echo "{}" # Return empty JSON object
        return 0
    fi

    # Parse cluster metadata
    if command -v yq &> /dev/null; then
        yq e '. | {
            "name": .name,
            "plan_name": .plan_name,
            "worker_count": .worker_count,
            "cluster_admins": .cluster_admins,
            "cluster_viewer": .cluster_viewer,
            "add_cluster_to_astra": .add_cluster_to_astra
        }' "${cluster_file}" -o json
    else
        echo "{\"name\": \"${cluster}\", \"source\": \"${cluster_file}\"}"
    fi
}

# Function to get namespace configurations from config repo
# Usage: get_namespace_configs <config_repo_path> <foundation> <cluster>
function get_namespace_configs() {
    local config_repo_path="$1"
    local foundation="$2"
    local cluster="$3"

    if [[ -z "${config_repo_path}" || -z "${foundation}" || -z "${cluster}" ]]; then
        echo "Error: config_repo_path, foundation, and cluster are required" >&2
        return 1
    fi

    local cluster_dir="${config_repo_path}/foundations/${foundation}/${cluster}"
    local namespace_configs=()

    if [[ ! -d "${cluster_dir}" ]]; then
        echo "Warning: Cluster directory not found: ${cluster_dir}" >&2
        echo "[]"
        return 0
    fi

    # Find all nameSpaceInfo.yml files
    while IFS= read -r -d '' namespace_file; do
        local namespace_dir
        namespace_dir=$(dirname "${namespace_file}")
        local namespace_name
       namespace_name=$(basename "${namespace_dir}")

        # Skip if namespace name looks like a system directory
        if [[ "${namespace_name}" == "compute-profiles" ||
              "${namespace_name}" == "network-profiles" ]]; then
            continue
        fi

        # Parse namespace configuration
        if command -v yq &> /dev/null; then
            local ns_config
            ns_config=$(yq e '. | {
                "namespace": .name // env(NAMESPACE_NAME),
                "app_id": .labels.app_id // null,
                "app_guid": .labels.app_guid // null,
                "environment": .environment // .labels.environment // null,
                "data_classification": .labels.data_classfication // null,
                "au": .labels.au // null,
                "country": .labels.country // null,
                "org": .labels.org // null,
                "ci_environment": .labels.ci_environment // null,
                "created_on": .labels.created_on // null,
                "requests_cpu": .requestscpu // null,
                "limits_cpu": .limitscpu // null,
                "requests_memory": .requestsmemory // null,
                "limits_memory": .limitsmemory // null,
                "requests_storage": .requestsstorage // null,
                "usergroups": .usergroups // []
            }' "${namespace_file}" --arg NAMESPACE_NAME "${namespace_name}" -o json)

            # Add source information
            ns_config=$(echo "${ns_config}" | jq --arg source "${namespace_file}" '. + {"config_source": $source}')

            namespace_configs+=("${ns_config}")
        else
            # Fallback: create basic structure
            local basic_config
            basic_config=$(jq -n \
                --arg namespace "${namespace_name}" \
                --arg source "${namespace_file}" \
                '{
                    "namespace": $namespace,
                    "config_source": $source,
                    "app_id": null,
                    "app_guid": null
                }')
            namespace_configs+=("${basic_config}")
        fi

    done < <(find "${cluster_dir}" -name "nameSpaceInfo.yml" -print0)

    # Convert array to JSON
    if [[ ${#namespace_configs[@]} -gt 0 ]]; then
        printf '%s\n' "${namespace_configs[@]}" | jq -s .
    else
        echo "[]"
    fi
}

# Function to get all foundation data from config repo
# Usage: get_foundation_config <config_repo_path> <foundation>
function get_foundation_config() {
    local config_repo_path="$1"
    local foundation="$2"

    if [[ -z "${config_repo_path}" || -z "${foundation}" ]]; then
        echo "Error: config_repo_path and foundation are required" >&2
        return 1
    fi

    echo "Reading foundation configuration for: ${foundation}" >&2

    # Get cluster list
    local clusters_json cluster_count
    clusters_json=$(get_clusters_from_config "${config_repo_path}" "${foundation}")
    cluster_count=$(echo "${clusters_json}" | jq length)

    echo "Found ${cluster_count} clusters in config" >&2

    # Build complete foundation configuration
    local foundation_config
    foundation_config=$(jq -n \
        --arg foundation "${foundation}" \
        --argjson clusters "${clusters_json}" \
        '{
            "foundation": $foundation,
            "clusters": $clusters,
            "cluster_count": ($clusters | length),
            "cluster_configs": {},
            "namespace_configs": {}
        }')

    # Get detailed config for each cluster
    while IFS= read -r cluster; do
        if [[ -n "${cluster}" && "${cluster}" != "null" ]]; then
            echo "Processing cluster: ${cluster}" >&2

            # Get cluster metadata
            local cluster_metadata
            cluster_metadata=$(get_cluster_metadata "${config_repo_path}" "${foundation}" "${cluster}")
            foundation_config=$(echo "${foundation_config}" | jq \
                --arg cluster "${cluster}" \
                --argjson metadata "${cluster_metadata}" \
                '.cluster_configs[$cluster] = $metadata')

            # Get namespace configurations
            local namespace_configs
            namespace_configs=$(get_namespace_configs "${config_repo_path}" "${foundation}" "${cluster}")
            foundation_config=$(echo "${foundation_config}" | jq \
                --arg cluster "${cluster}" \
                --argjson configs "${namespace_configs}" \
                '.namespace_configs[$cluster] = $configs')
        fi
    done < <(echo "${clusters_json}" | jq -r '.[]')

    echo "${foundation_config}"
}

# Function to compare actual vs configured namespaces
# Usage: compare_actual_vs_config <actual_namespaces_json> <config_namespaces_json>
function compare_actual_vs_config() {
    local actual_json="$1"
    local config_json="$2"

    if [[ -z "${actual_json}" || -z "${config_json}" ]]; then
        echo "Error: Both actual and config JSON are required" >&2
        return 1
    fi

    # Create comparison analysis
    local comparison
    comparison=$(jq -n \
        --argjson actual "${actual_json}" \
        --argjson config "${config_json}" \
        '{
            "actual_namespaces": ($actual | map(.namespace) | sort),
            "configured_namespaces": ($config | map(.namespace) | sort),
            "only_in_actual": (($actual | map(.namespace)) - ($config | map(.namespace)) | sort),
            "only_in_config": (($config | map(.namespace)) - ($actual | map(.namespace)) | sort),
            "in_both": (($actual | map(.namespace)) as $a | ($config | map(.namespace)) as $c |
                       [$a[] | select(. as $ns | $c | index($ns))] | sort),
            "app_id_mismatches": []
        }')

    # Find app_id mismatches for namespaces that exist in both
    local in_both
    in_both=$(echo "${comparison}" | jq -r '.in_both[]')

    while IFS= read -r ns; do
        if [[ -n "${ns}" ]]; then
            local actual_app_id config_app_id
            actual_app_id=$(echo "${actual_json}" | jq -r --arg ns "${ns}" '.[] | select(.namespace == $ns) | .app_id // null')
            config_app_id=$(echo "${config_json}" | jq -r --arg ns "${ns}" '.[] | select(.namespace == $ns) | .app_id // null')

            if [[ "${actual_app_id}" != "${config_app_id}" ]]; then
                local mismatch
                mismatch=$(jq -n \
                    --arg namespace "${ns}" \
                    --arg actual "${actual_app_id}" \
                    --arg config "${config_app_id}" \
                    '{
                        "namespace": $namespace,
                        "actual_app_id": $actual,
                        "configured_app_id": $config
                    }')

                comparison=$(echo "${comparison}" | jq --argjson mismatch "${mismatch}" '.app_id_mismatches += [$mismatch]')
            fi
        fi
    done <<< "${in_both}"

    echo "${comparison}"
}

# Function to enrich actual namespace data with config data
# Usage: enrich_with_config <actual_namespaces_json> <config_namespaces_json>
function enrich_with_config() {
    local actual_json="$1"
    local config_json="$2"

    if [[ -z "${actual_json}" || -z "${config_json}" ]]; then
        echo "Error: Both actual and config JSON are required" >&2
        return 1
    fi

    # Enrich actual data with configuration
    echo "${actual_json}" | jq --argjson config "${config_json}" '
        map(. as $actual |
            ($config[] | select(.namespace == $actual.namespace)) as $conf |
            if $conf then
                . + {
                    "configured_app_id": ($conf.app_id // null),
                    "configured_app_guid": ($conf.app_guid // null),
                    "configured_environment": ($conf.environment // null),
                    "config_source": ($conf.config_source // null),
                    "has_config": true,
                    "app_id_matches": ((.app_id // null) == ($conf.app_id // null)),
                    "config_metadata": $conf
                }
            else
                . + {
                    "configured_app_id": null,
                    "configured_app_guid": null,
                    "configured_environment": null,
                    "config_source": null,
                    "has_config": false,
                    "app_id_matches": null,
                    "config_metadata": null
                }
            end
        )'
}

# Function to validate config repo structure
# Usage: validate_config_repo <config_repo_path>
function validate_config_repo() {
    local config_repo_path="$1"

    if [[ -z "${config_repo_path}" ]]; then
        echo "Error: config_repo_path is required" >&2
        return 1
    fi

    if [[ ! -d "${config_repo_path}" ]]; then
        echo "Error: Config repo directory not found: ${config_repo_path}" >&2
        return 1
    fi

    local foundations_dir="${config_repo_path}/foundations"
    if [[ ! -d "${foundations_dir}" ]]; then
        echo "Error: Foundations directory not found: ${foundations_dir}" >&2
        return 1
    fi

    echo "Config repo validation passed: ${config_repo_path}" >&2

    # List available foundations
    local foundations=()
    while IFS= read -r -d '' foundation_dir; do
        local foundation_name
        foundation_name=$(basename "${foundation_dir}")
        foundations+=("${foundation_name}")
    done < <(find "${foundations_dir}" -mindepth 1 -maxdepth 1 -type d -print0)

    printf '%s\n' "${foundations[@]}" | jq -R . | jq -s '{
        "config_repo_path": env.config_repo_path,
        "foundations": .,
        "foundation_count": length
    }' --arg config_repo_path "${config_repo_path}"
}

# Main function for testing
function main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <function> [args...]"
        echo ""
        echo "Available functions:"
        echo "  get_clusters_from_config <config_repo_path> <foundation>"
        echo "  get_cluster_metadata <config_repo_path> <foundation> <cluster>"
        echo "  get_namespace_configs <config_repo_path> <foundation> <cluster>"
        echo "  get_foundation_config <config_repo_path> <foundation>"
        echo "  validate_config_repo <config_repo_path>"
        echo ""
        echo "Example:"
        echo "  $0 get_foundation_config ~/git/config-lab dc01-k8s-n-01"
        exit 1
    fi

    local function_name="$1"
    shift

    if declare -f "${function_name}" > /dev/null; then
        "${function_name}" "$@"
    else
        echo "Error: Unknown function: ${function_name}" >&2
        exit 1
    fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
