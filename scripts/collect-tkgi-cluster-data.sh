#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Enhanced data collection script for TKGI clusters with proper authentication
# Uses om CLI to get credentials and tkgi CLI to authenticate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Source helper functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/helpers.sh"

# Initialize output file
OUTPUT_FILE="${DATA_DIR}/cluster_data_${TIMESTAMP}.json"

# Function to display usage
function usage() {
    echo "Usage: $0 -f FOUNDATION -c CLUSTER [-o OUTPUT_FILE] [-h]"
    echo "  -f FOUNDATION   Foundation name (dc01|dc02|dc03|dc04)"
    echo "  -c CLUSTER      TKGI cluster name"
    echo "  -o OUTPUT_FILE  Output file path (default: ${OUTPUT_FILE})"
    echo "  -h              Display this help message"
    echo ""
    echo "Environment variables required (or fetched from Vault):"
    echo "  OM_TARGET          Ops Manager URL"
    echo "  OM_CLIENT_ID       Ops Manager client ID"
    echo "  OM_CLIENT_SECRET   Ops Manager client secret"
    echo "  TKGI_API_ENDPOINT  TKGI API endpoint"
    exit 1
}

# Parse command line arguments
FOUNDATION=""
CLUSTER=""

while getopts "f:c:o:h" opt; do
    case ${opt} in
        f )
            FOUNDATION=$OPTARG
            ;;
        c )
            CLUSTER=$OPTARG
            ;;
        o )
            OUTPUT_FILE=$OPTARG
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

# Validate required parameters
if [[ -z "${FOUNDATION}" ]] || [[ -z "${CLUSTER}" ]]; then
    error "Foundation and cluster parameters are required"
    usage
fi

# Ensure data directory exists
mkdir -p "${DATA_DIR}"

# Set foundation-specific environment variables
function setup_foundation_env() {
    local foundation=$1

    # These would typically be loaded from Vault or environment
    # For now, using environment variables with foundation prefix
    export OM_TARGET="${OM_TARGET:-${foundation^^}_OM_TARGET}"
    export OM_CLIENT_ID="${OM_CLIENT_ID:-${foundation^^}_OM_CLIENT_ID}"
    export OM_CLIENT_SECRET="${OM_CLIENT_SECRET:-${foundation^^}_OM_CLIENT_SECRET}"
    export TKGI_API_ENDPOINT="${TKGI_API_ENDPOINT:-${foundation^^}_TKGI_API_ENDPOINT}"

    # Validate required environment variables
    if [[ -z "${!OM_TARGET}" ]] || [[ -z "${!OM_CLIENT_ID}" ]] || [[ -z "${!OM_CLIENT_SECRET}" ]] || [[ -z "${!TKGI_API_ENDPOINT}" ]]; then
        error "Missing required environment variables for foundation ${foundation}"
        error "Please set: ${foundation^^}_OM_TARGET, ${foundation^^}_OM_CLIENT_ID, ${foundation^^}_OM_CLIENT_SECRET, ${foundation^^}_TKGI_API_ENDPOINT"
        exit 1
    fi
}

# Function to authenticate with TKGI
function authenticate_tkgi() {
    local foundation=$1
    local cluster=$2

    info "Authenticating with TKGI for foundation: ${foundation}"

    # Set up foundation environment
    setup_foundation_env "${foundation}"

    # Use the helper function to login to TKGI and get cluster credentials
    if ! tkgi_login "${cluster}" "${!TKGI_API_ENDPOINT}" "${!OM_TARGET}" "${!OM_CLIENT_ID}" "${!OM_CLIENT_SECRET}"; then
        error "Failed to authenticate with TKGI cluster: ${cluster}"
        return 1
    fi

    completed "Successfully authenticated with cluster: ${cluster}"
    return 0
}

# Function to check if a namespace is a system namespace
function is_system_namespace() {
    local ns=$1
    case $ns in
        kube-*|default|istio-*|gatekeeper-*|cert-manager|pks-system|observability|monitoring|logging|trident|vmware-*|tanzu-*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get namespace data
function collect_namespace_data() {
    local ns=$1
    local is_system="false"

    if is_system_namespace "$ns"; then
        is_system="true"
    fi

    # Get namespace details
    local ns_json
    ns_json=$(kubectl get namespace "$ns" -o json 2>/dev/null || echo '{}')

    local labels
    labels=$(echo "$ns_json" | jq -c '.metadata.labels // {}')

    local annotations
    annotations=$(echo "$ns_json" | jq -c '.metadata.annotations // {}')

    local creation_timestamp
    creation_timestamp=$(echo "$ns_json" | jq -r '.metadata.creationTimestamp // "unknown"')

    # Extract AppID from labels or annotations
    local app_id
    app_id=$(echo "$labels" | jq -r '.appId // .appID // ."app-id" // .application // empty' 2>/dev/null)
    if [[ -z "$app_id" ]]; then
        app_id=$(echo "$annotations" | jq -r '.appId // .appID // ."app-id" // .application // empty' 2>/dev/null)
    fi
    if [[ -z "$app_id" ]]; then
        # Try to extract from namespace name pattern (e.g., app-12345-dev)
        app_id=$(echo "$ns" | grep -oE '^[a-zA-Z]+-[0-9]+' || echo "")
    fi

    # Get pod counts and status
    local pod_count
    pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')

    local running_pods
    running_pods=$(kubectl get pods -n "$ns" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

    # Get deployment information
    local deployments
    deployments=$(kubectl get deployments -n "$ns" -o json 2>/dev/null | jq -c '[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas, updated: .status.updatedReplicas, lastUpdate: .metadata.annotations."deployment.kubernetes.io/revision" // "unknown"}]')

    local deployment_count
    deployment_count=$(echo "$deployments" | jq 'length')

    # Get statefulsets information
    local statefulsets
    statefulsets=$(kubectl get statefulsets -n "$ns" -o json 2>/dev/null | jq -c '[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas}]')

    local statefulset_count
    statefulset_count=$(echo "$statefulsets" | jq 'length')

    # Get last pod creation/restart time (indicates activity)
    local last_activity
    last_activity=$(kubectl get pods -n "$ns" -o json 2>/dev/null | jq -r '[.items[].status.startTime] | max // "unknown"')

    # Get resource quota if exists
    local resource_quota
    resource_quota=$(kubectl get resourcequota -n "$ns" -o json 2>/dev/null | jq -c '[.items[] | {name: .metadata.name, hard: .status.hard, used: .status.used}]')

    # Get services
    local services
    services=$(kubectl get services -n "$ns" -o json 2>/dev/null | jq -c '[.items[] | {name: .metadata.name, type: .spec.type, ports: [.spec.ports[].port]}]')

    local service_count
    service_count=$(echo "$services" | jq 'length')

    # Create namespace data object
    cat <<EOF
{
    "namespace": "$ns",
    "cluster": "${CLUSTER}",
    "foundation": "${FOUNDATION}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "is_system": $is_system,
    "app_id": "${app_id:-unknown}",
    "labels": $labels,
    "annotations": $annotations,
    "creation_timestamp": "$creation_timestamp",
    "pod_count": $pod_count,
    "running_pods": $running_pods,
    "deployment_count": $deployment_count,
    "deployments": $deployments,
    "statefulset_count": $statefulset_count,
    "statefulsets": $statefulsets,
    "service_count": $service_count,
    "services": $services,
    "last_activity": "$last_activity",
    "resource_quota": $resource_quota
}
EOF
}

# Main collection logic
info "Starting TKGI data collection for ${FOUNDATION}/${CLUSTER}"

# Authenticate with TKGI
if ! authenticate_tkgi "${FOUNDATION}" "${CLUSTER}"; then
    error "Authentication failed"
    exit 1
fi

info "Starting namespace data collection..."

# Initialize JSON array
echo "[" > "$OUTPUT_FILE"

# Get all namespaces
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
mapfile -t namespace_array <<< "$namespaces"
total_namespaces=${#namespace_array[@]}

info "Found ${total_namespaces} namespaces to process"

# Process each namespace
for i in "${!namespace_array[@]}"; do
    ns="${namespace_array[$i]}"
    echo "Processing namespace $((i+1))/${total_namespaces}: $ns"

    namespace_data=$(collect_namespace_data "$ns")

    # Add comma separator except for last item
    if [[ $i -lt $((total_namespaces - 1)) ]]; then
        echo "${namespace_data}," >> "$OUTPUT_FILE"
    else
        echo "${namespace_data}" >> "$OUTPUT_FILE"
    fi
done

# Close JSON array
echo "]" >> "$OUTPUT_FILE"

# Add environment classification based on cluster name
environment="nonproduction"
if [[ "$CLUSTER" == *"-prod-"* ]] || [[ "$CLUSTER" == *"prod"* ]]; then
    environment="production"
fi

# Update JSON with environment information
jq --arg env "$environment" '[.[] | . + {environment: $env}]' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

# Validate JSON output
if jq empty "$OUTPUT_FILE" 2>/dev/null; then
    completed "Data collection completed successfully"
    completed "Output saved to: $OUTPUT_FILE"
    info "Total namespaces processed: ${total_namespaces}"

    # Generate quick statistics
    app_namespaces=$(jq '[.[] | select(.is_system == false)] | length' "$OUTPUT_FILE")
    system_namespaces=$(jq '[.[] | select(.is_system == true)] | length' "$OUTPUT_FILE")
    total_pods=$(jq '[.[].pod_count] | add' "$OUTPUT_FILE")

    info "Application namespaces: ${app_namespaces}"
    info "System namespaces: ${system_namespaces}"
    info "Total pods: ${total_pods}"
else
    error "Invalid JSON generated in output file"
    exit 1
fi
