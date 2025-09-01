#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Multi-foundation TKGI cluster data collection script
# Uses om CLI and tkgi CLI for proper authentication

echo "DEBUG: Script starting..."
echo "DEBUG: Current directory: $(pwd)"
echo "DEBUG: Script arguments: $*"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEBUG: Script directory: ${SCRIPT_DIR}"
DATA_DIR="${SCRIPT_DIR}/../data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Source helper functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/helpers.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/foundation-utils.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config-utils.sh"

# Config repo path (for enrichment data, not source of truth)
CONFIG_REPO_PATH="${CONFIG_REPO_PATH:-${HOME}/git/config-lab}"

# Function to display usage
function usage() {
    echo "Usage: $0 [-f FOUNDATIONS] [-c CLUSTER] [-o OUTPUT_DIR] [-h]"
    echo "  -f FOUNDATIONS  Space-separated list of foundations to collect from"
    echo "                  (e.g., 'dc01-k8s-n-01 dc01-k8s-n-02' or 'dc02-k8s-n-01')"
    echo "  -c CLUSTER      Specific cluster name to collect from"
    echo "  -o OUTPUT_DIR   Output directory for collected data"
    echo "  -h              Display this help message"
    echo ""
    echo "Foundation Format: {datacenter}-{type}-{environment}-{instance}"
    echo "  Examples: dc01-k8s-n-01, dc02-k8s-n-01, dc03-k8s-p-01"
    echo ""
    echo "Environment variables required per foundation:"
    echo "  OM_TARGET                       From foundation parameter file"
    echo "  OM_CLIENT_ID                    From pipeline parameters"
    echo "  OM_CLIENT_SECRET                From pipeline parameters"
    echo "  TKGI_API_ENDPOINT               From pipeline parameters"
    exit 1
}

# Parse command line arguments
FOUNDATION_FILTER=""
CLUSTER_FILTER=""
OUTPUT_DIR="${DATA_DIR}"

while getopts "f:c:o:h" opt; do
    case ${opt} in
        f )
            FOUNDATION_FILTER=$OPTARG
            ;;
        c )
            CLUSTER_FILTER=$OPTARG
            ;;
        o )
            OUTPUT_DIR=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            error "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Create combined output file
COMBINED_OUTPUT="${OUTPUT_DIR}/all_clusters_${TIMESTAMP}.json"

# Function to get clusters from TKGI API
function get_tkgi_clusters() {
    local foundation=$1

    info "Getting cluster list from TKGI API for foundation: ${foundation}"

    # Set foundation-specific environment variables
    # Convert foundation name to valid variable name (replace hyphens with underscores)
    local foundation_var="${foundation^^}"
    foundation_var="${foundation_var//-/_}"
    local om_target_var="${foundation_var}_OM_TARGET"
    local om_client_id_var="${foundation_var}_OM_CLIENT_ID"
    local om_client_secret_var="${foundation_var}_OM_CLIENT_SECRET"
    local pks_api_var="${foundation_var}_TKGI_API_ENDPOINT"

    local om_target="${!om_target_var:-}"
    local om_client_id="${!om_client_id_var:-}"
    local om_client_secret="${!om_client_secret_var:-}"
    local pks_api_endpoint="${!pks_api_var:-}"

    # Fall back to generic environment variables if foundation-specific ones aren't available
    if [[ -z "$om_target" ]]; then
        om_target="${OM_TARGET:-}"
    fi
    if [[ -z "$om_client_id" ]]; then
        om_client_id="${OM_CLIENT_ID:-}"
    fi
    if [[ -z "$om_client_secret" ]]; then
        om_client_secret="${OM_CLIENT_SECRET:-}"
    fi
    if [[ -z "$pks_api_endpoint" ]]; then
        pks_api_endpoint="${TKGI_API_ENDPOINT:-}"
    fi

    if [[ -z "$om_target" ]] || [[ -z "$om_client_id" ]] || [[ -z "$om_client_secret" ]] || [[ -z "$pks_api_endpoint" ]]; then
        warn "Missing environment variables for foundation ${foundation}, skipping"
        return 1
    fi

    # Get TKGI admin password from Ops Manager
    local admin_password
    if ! admin_password=$(om -t "${om_target}" \
        -c "${om_client_id}" \
        -s "${om_client_secret}" \
        credentials \
        -p pivotal-container-service \
        -c '.properties.uaa_admin_password' \
        -f secret 2>/dev/null); then
        error "Failed to get TKGI admin password for foundation ${foundation}"
        return 1
    fi

    # Login to TKGI
    if ! tkgi login -a "https://${pks_api_endpoint}" \
        --skip-ssl-validation \
        -u "admin" \
        -p "${admin_password}" > /dev/null 2>&1; then
        error "Failed to login to TKGI API for foundation ${foundation}"
        return 1
    fi

    # Get clusters
    local clusters
    if ! clusters=$(tkgi clusters --json 2>/dev/null | jq -r '.[].name' 2>/dev/null); then
        error "Failed to get cluster list for foundation ${foundation}"
        return 1
    fi

    echo "$clusters"
}

# Function to collect data from a single cluster
function collect_cluster() {
    local foundation=$1
    local cluster=$2

    info "Collecting data from ${foundation}/${cluster}"

    # Run the TKGI cluster collection script
    local cluster_output="${OUTPUT_DIR}/${foundation}_${cluster}_${TIMESTAMP}.json"
    if "${SCRIPT_DIR}/collect-tkgi-cluster-data.sh" -f "${foundation}" -c "${cluster}" -o "${cluster_output}"; then
        echo "${cluster_output}"
        return 0
    else
        error "Failed to collect data from ${foundation}/${cluster}"
        return 1
    fi
}

# Function to enrich collected data with config repo information
function enrich_with_config_data() {
    local combined_file="$1"

    if [[ ! -f "${CONFIG_REPO_PATH}/foundations" ]]; then
        info "Config repo not found at ${CONFIG_REPO_PATH}, skipping enrichment"
        return 0
    fi

    # Create enriched output file
    local enriched_file="${combined_file%.json}_enriched.json"
    local temp_file="${combined_file}.temp"

    info "Validating config repository structure..."
    if ! validate_config_repo "${CONFIG_REPO_PATH}" >/dev/null 2>&1; then
        warn "Config repo validation failed, skipping enrichment"
        return 0
    fi

    # Process each foundation found in the actual data
    local foundations
    foundations=$(jq -r '[.[].foundation] | unique | .[]' "${combined_file}")

    # Create working copy of data
    cp "${combined_file}" "${temp_file}"

    while IFS= read -r foundation; do
        [[ -z "$foundation" ]] && continue

        info "Enriching data for foundation: ${foundation}"

        # Get config data for this foundation
        local foundation_config
        if foundation_config=$(get_foundation_config "${CONFIG_REPO_PATH}" "${foundation}" 2>/dev/null); then

            # Extract foundation's actual namespace data
            local actual_namespaces
            actual_namespaces=$(jq "[.[] | select(.foundation == \"${foundation}\")]" "${temp_file}")

            # Get the config namespace data for all clusters in this foundation
            local all_config_namespaces="[]"
            local clusters
            clusters=$(echo "${foundation_config}" | jq -r '.clusters[]')

            while IFS= read -r cluster; do
                [[ -z "$cluster" ]] && continue

                local cluster_config_namespaces
                cluster_config_namespaces=$(echo "${foundation_config}" | jq ".namespace_configs[\"${cluster}\"] // []")

                # Add cluster info to each namespace config
                cluster_config_namespaces=$(echo "${cluster_config_namespaces}" | jq --arg cluster "${cluster}" '
                    map(. + {"cluster": $cluster})
                ')

                # Merge into all config namespaces
                all_config_namespaces=$(echo "${all_config_namespaces}" "${cluster_config_namespaces}" | jq -s '.[0] + .[1]')

            done <<< "${clusters}"

            # Enrich actual data with config data
            if [[ "${all_config_namespaces}" != "[]" ]]; then
                local enriched_foundation_data
                enriched_foundation_data=$(enrich_with_config "${actual_namespaces}" "${all_config_namespaces}")

                # Update the temp file with enriched data for this foundation
                local other_foundations_data
                other_foundations_data=$(jq "[.[] | select(.foundation != \"${foundation}\")]" "${temp_file}")

                # Combine enriched foundation data with other foundations
                echo "${other_foundations_data}" "${enriched_foundation_data}" | jq -s '.[0] + .[1]' > "${temp_file}.new"
                mv "${temp_file}.new" "${temp_file}"

                info "  Enhanced $(echo "${enriched_foundation_data}" | jq length) namespaces with config data"
            else
                info "  No config data found for foundation ${foundation}"
            fi

        else
            info "  Could not load config data for foundation ${foundation}"
        fi

    done <<< "${foundations}"

    # Create final enriched file
    mv "${temp_file}" "${enriched_file}"

    info "Enriched data saved to: ${enriched_file}"

    # Generate config comparison report
    local comparison_file="${combined_file%.json}_config_comparison.json"
    generate_config_comparison_report "${enriched_file}" "${comparison_file}"

    info "Config comparison report saved to: ${comparison_file}"
}

# Function to generate config comparison report
function generate_config_comparison_report() {
    local enriched_file="$1"
    local comparison_file="$2"

    # Analyze configuration drift and missing data
    local report
    report=$(jq '{
        "summary": {
            "total_namespaces": length,
            "namespaces_with_config": [.[] | select(.has_config == true)] | length,
            "namespaces_without_config": [.[] | select(.has_config == false)] | length,
            "app_id_matches": [.[] | select(.app_id_matches == true)] | length,
            "app_id_mismatches": [.[] | select(.app_id_matches == false)] | length,
            "app_id_unknown": [.[] | select(.app_id_matches == null)] | length
        },
        "foundations": (
            group_by(.foundation) |
            map({
                "foundation": .[0].foundation,
                "total_namespaces": length,
                "with_config": [.[] | select(.has_config == true)] | length,
                "without_config": [.[] | select(.has_config == false)] | length,
                "app_id_drift": [.[] | select(.app_id_matches == false)] | length
            })
        ),
        "missing_configs": [.[] | select(.has_config == false) | {
            "foundation": .foundation,
            "cluster": .cluster,
            "namespace": .namespace,
            "app_id": .app_id
        }],
        "app_id_drift": [.[] | select(.app_id_matches == false) | {
            "foundation": .foundation,
            "cluster": .cluster,
            "namespace": .namespace,
            "actual_app_id": .app_id,
            "configured_app_id": .configured_app_id,
            "config_source": .config_source
        }]
    }' "${enriched_file}")

    echo "${report}" > "${comparison_file}"
}

# Main collection logic
info "Starting multi-foundation TKGI data collection..."
info "Timestamp: ${TIMESTAMP}"

# Track collected clusters
declare -a COLLECTED_FILES=()
info "DEBUG: COLLECTED_FILES array declared"
FAILED_CLUSTERS=""

# For Docker testing, create mock output if no TKGI environment is available
if [[ "${TESTING_MODE:-false}" == "true" ]]; then
    info "Running in testing mode - generating mock data"
    mock_output="${OUTPUT_DIR}/all_clusters_${TIMESTAMP}.json"
    echo '[{"namespace":"test-namespace","cluster":"test-cluster","foundation":"dc01-k8s-n-01","app_id":"test-app"}]' > "${mock_output}"
    info "Mock data generated: ${mock_output}"
    exit 0
fi

# Determine which foundations to process
if [[ -n "${FOUNDATION_FILTER}" ]]; then
    FOUNDATIONS="${FOUNDATION_FILTER}"
else
    FOUNDATIONS="dc01 dc02 dc03 dc04"
fi

# Process each foundation
for foundation in $FOUNDATIONS; do
    echo ""
    info "Processing foundation: ${foundation}"

    # Get clusters for this foundation from TKGI API
    clusters=""
    if clusters=$(get_tkgi_clusters "${foundation}"); then
        if [[ -z "$clusters" ]]; then
            warn "No clusters found for foundation ${foundation}"
            continue
        fi
    else
        warn "Failed to get clusters for foundation ${foundation}, skipping"
        FAILED_CLUSTERS="${FAILED_CLUSTERS} ${foundation}/*"
        continue
    fi

    # Clean the clusters output to remove any extraneous output
    # Filter to keep only valid cluster names (alphanumeric, dots, hyphens, underscores)
    # Note: hyphen is at the end of character class to avoid range interpretation
    clusters=$(echo "$clusters" | grep -E '^[a-zA-Z0-9][a-zA-Z0-9._-]*$' || true)

    info "Found clusters: $(echo "$clusters" | tr '\n' ' ')"

    # Process each cluster in the foundation
    while IFS= read -r cluster; do
        [[ -z "$cluster" ]] && continue

        # Apply cluster filter if specified
        if [[ -n "${CLUSTER_FILTER}" ]] && [[ "${cluster}" != "${CLUSTER_FILTER}" ]]; then
            continue
        fi

        # Collect data from cluster
        if output_file=$(collect_cluster "${foundation}" "${cluster}"); then
            COLLECTED_FILES+=("${output_file}")
            info "DEBUG: Added ${output_file} to COLLECTED_FILES. Array now has ${#COLLECTED_FILES[@]} entries"
        else
            FAILED_CLUSTERS="${FAILED_CLUSTERS} ${foundation}/${cluster}"
            info "DEBUG: Failed to collect from ${foundation}/${cluster}"
        fi
    done <<< "$clusters"
done

# Combine all collected data into a single file
echo ""
info "Combining data from all clusters..."

# Check if array exists and has elements
array_size=${#COLLECTED_FILES[@]}
info "DEBUG: Final COLLECTED_FILES array size: ${array_size}"
if [[ "${array_size}" -eq 0 ]]; then
    error "No data collected from any cluster"
    if [[ -n "${FAILED_CLUSTERS}" ]]; then
        error "Failed clusters: ${FAILED_CLUSTERS}"
    fi
    exit 1
fi

# Start with empty array
echo "[" > "${COMBINED_OUTPUT}"

# Process each collected file
for i in "${!COLLECTED_FILES[@]}"; do
    file="${COLLECTED_FILES[$i]}"
    info "DEBUG: Processing file ${i}: ${file}"

    # Check if file exists and is readable
    if [[ ! -f "${file}" ]]; then
        error "File does not exist: ${file}"
        continue
    fi

    # Show file size for debugging
    file_size=$(wc -c < "${file}" 2>/dev/null || echo "unknown")
    info "DEBUG: File size: ${file_size} bytes"

    # Validate individual file first
    if ! jq empty "${file}" 2>/dev/null; then
        error "Invalid JSON in file: ${file}"
        info "DEBUG: First few lines of invalid file:"
        head -5 "${file}" >&2 || true
        continue
    fi

    # Count records in file
    record_count=$(jq 'length' "${file}" 2>/dev/null || echo "0")
    info "DEBUG: File contains ${record_count} records"

    # Extract array contents and add to combined file
    if [[ $i -eq 0 ]]; then
        # First file - extract array contents without brackets, add commas between objects
        info "DEBUG: Processing first file - extracting array contents"
        if ! jq -c '.[]' "${file}" | awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' >> "${COMBINED_OUTPUT}"; then
            error "Failed to process file: ${file}"
            continue
        fi
    else
        # Subsequent files - add comma and extract contents with commas between objects
        info "DEBUG: Processing subsequent file - adding comma and contents"
        echo "," >> "${COMBINED_OUTPUT}"
        if ! jq -c '.[]' "${file}" | awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' >> "${COMBINED_OUTPUT}"; then
            error "Failed to process file: ${file}"
            continue
        fi
    fi

    info "DEBUG: Successfully processed file ${i}"
done

# Close the array
echo "]" >> "${COMBINED_OUTPUT}"

# Debug combined output
combined_size=$(wc -c < "${COMBINED_OUTPUT}" 2>/dev/null || echo "unknown")
info "DEBUG: Combined file size: ${combined_size} bytes"
info "DEBUG: Combined file location: ${COMBINED_OUTPUT}"

# Validate combined JSON
info "DEBUG: Validating combined JSON..."
if jq empty "${COMBINED_OUTPUT}" 2>/dev/null; then
    echo ""
    completed "Data collection completed successfully"
    completed "Combined output saved to: ${COMBINED_OUTPUT}"
    info "Total clusters processed: ${#COLLECTED_FILES[@]}"

    # Enrich with config repo data
    echo ""
    info "Enriching data with configuration repository information..."
    enrich_with_config_data "${COMBINED_OUTPUT}"

    # Report statistics
    total_namespaces=$(jq 'length' "${COMBINED_OUTPUT}")
    app_namespaces=$(jq '[.[] | select(.is_system == false)] | length' "${COMBINED_OUTPUT}")
    system_namespaces=$(jq '[.[] | select(.is_system == true)] | length' "${COMBINED_OUTPUT}")
    total_pods=$(jq '[.[].pod_count] | add' "${COMBINED_OUTPUT}")

    echo ""
    info "Statistics:"
    info "  Total namespaces: ${total_namespaces}"
    info "  Application namespaces: ${app_namespaces}"
    info "  System namespaces: ${system_namespaces}"
    info "  Total pods: ${total_pods}"

    # Foundation breakdown
    foundations=$(jq -r '[.[].foundation] | unique | .[]' "${COMBINED_OUTPUT}")
    while IFS= read -r foundation; do
        [[ -z "$foundation" ]] && continue
        foundation_apps=$(jq "[.[] | select(.foundation == \"$foundation\" and .is_system == false)] | length" "${COMBINED_OUTPUT}")
        info "  ${foundation^^}: ${foundation_apps} application namespaces"
    done <<< "$foundations"

    if [[ -n "${FAILED_CLUSTERS}" ]]; then
        echo ""
        warn "Failed to collect from clusters:${FAILED_CLUSTERS}"
    fi
else
    error "Invalid JSON generated in combined output file"
    info "DEBUG: Attempting to identify JSON syntax error..."

    # Try to get more specific error information
    jq_error=$(jq empty "${COMBINED_OUTPUT}" 2>&1 || true)
    if [[ -n "${jq_error}" ]]; then
        info "DEBUG: jq error details: ${jq_error}"
    fi

    # Show first and last few lines of combined output for debugging
    info "DEBUG: First 10 lines of combined output:"
    head -10 "${COMBINED_OUTPUT}" >&2 || true

    info "DEBUG: Last 10 lines of combined output:"
    tail -10 "${COMBINED_OUTPUT}" >&2 || true

    # Check for common JSON issues
    if grep -q "^\[.*\]$" "${COMBINED_OUTPUT}"; then
        info "DEBUG: File appears to have proper array brackets"
    else
        info "DEBUG: File may be missing proper array brackets"
    fi

    exit 1
fi
