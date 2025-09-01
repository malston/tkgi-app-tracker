#!/usr/bin/env bash

# Test script to validate jq syntax in collect-tkgi-cluster-data.sh
# This ensures all jq commands have valid syntax before deployment

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Track test results
FAILED_TESTS=0
PASSED_TESTS=0

# Function to test jq expression
test_jq() {
    local description="$1"
    local jq_expression="$2"
    local sample_json="$3"
    
    printf "Testing: %s\n" "$description"
    
    # Create temp files to avoid quoting issues
    local temp_json=$(mktemp)
    local temp_output=$(mktemp)
    local temp_error=$(mktemp)
    
    echo "$sample_json" > "$temp_json"
    
    if jq "$jq_expression" < "$temp_json" > "$temp_output" 2> "$temp_error"; then
        printf "${GREEN}✓${NC} %s\n" "$description"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        rm -f "$temp_json" "$temp_output" "$temp_error"
        return 0
    else
        printf "${RED}✗${NC} %s\n" "$description"
        printf "  Expression: %s\n" "$jq_expression"
        printf "  Error: %s\n" "$(cat "$temp_error")"
        rm -f "$temp_json" "$temp_output" "$temp_error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo "========================================="
echo "JQ Syntax Validation Test"
echo "========================================="
echo ""

# Test 1: Deployment with annotation
echo "Testing deployment data extraction..."
test_jq "Deployment with revision annotation" \
'[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas, updated: .status.updatedReplicas, lastUpdate: (.metadata.annotations["deployment.kubernetes.io/revision"] // "unknown")}]' \
'{
  "items": [
    {
      "metadata": {
        "name": "test-deployment",
        "annotations": {
          "deployment.kubernetes.io/revision": "3"
        }
      },
      "spec": {
        "replicas": 3
      },
      "status": {
        "readyReplicas": 3,
        "updatedReplicas": 3
      }
    }
  ]
}'

# Test 2: Deployment without annotation
test_jq "Deployment without revision annotation" \
'[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas, updated: .status.updatedReplicas, lastUpdate: (.metadata.annotations["deployment.kubernetes.io/revision"] // "unknown")}]' \
'{
  "items": [
    {
      "metadata": {
        "name": "test-deployment",
        "annotations": {}
      },
      "spec": {
        "replicas": 3
      },
      "status": {
        "readyReplicas": 3,
        "updatedReplicas": 3
      }
    }
  ]
}'

# Test 3: Empty deployment list
test_jq "Empty deployment list" \
'[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas, updated: .status.updatedReplicas, lastUpdate: (.metadata.annotations["deployment.kubernetes.io/revision"] // "unknown")}]' \
'{"items": []}'

# Test 4: StatefulSet extraction
echo ""
echo "Testing statefulset data extraction..."
test_jq "StatefulSet extraction" \
'[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas}]' \
'{
  "items": [
    {
      "metadata": {
        "name": "test-statefulset"
      },
      "spec": {
        "replicas": 2
      },
      "status": {
        "readyReplicas": 2
      }
    }
  ]
}'

# Test 5: Pod startTime extraction
echo ""
echo "Testing pod activity extraction..."
test_jq "Pod startTime extraction with max" \
'[.items[].status.startTime] | max // "unknown"' \
'{
  "items": [
    {
      "status": {
        "startTime": "2025-01-20T10:00:00Z"
      }
    },
    {
      "status": {
        "startTime": "2025-01-20T11:00:00Z"
      }
    }
  ]
}'

# Test 6: Empty pod list
test_jq "Empty pod list handling" \
'[.items[].status.startTime] | max // "unknown"' \
'{"items": []}'

# Test 7: Resource quota extraction
echo ""
echo "Testing resource quota extraction..."
test_jq "Resource quota extraction" \
'[.items[] | {name: .metadata.name, hard: .status.hard, used: .status.used}]' \
'{
  "items": [
    {
      "metadata": {
        "name": "compute-quota"
      },
      "status": {
        "hard": {
          "cpu": "100",
          "memory": "200Gi"
        },
        "used": {
          "cpu": "50",
          "memory": "100Gi"
        }
      }
    }
  ]
}'

# Test 8: Services extraction
echo ""
echo "Testing services extraction..."
test_jq "Service with ports extraction" \
'[.items[] | {name: .metadata.name, type: .spec.type, ports: [.spec.ports[].port]}]' \
'{
  "items": [
    {
      "metadata": {
        "name": "test-service"
      },
      "spec": {
        "type": "ClusterIP",
        "ports": [
          {"port": 80},
          {"port": 443}
        ]
      }
    }
  ]
}'

# Test 9: Namespace metadata extraction
echo ""
echo "Testing namespace metadata extraction..."
test_jq "Namespace creation timestamp" \
'.metadata.creationTimestamp // "unknown"' \
'{
  "metadata": {
    "creationTimestamp": "2025-01-15T10:00:00Z"
  }
}'

# Test 10: Missing timestamp
test_jq "Missing creation timestamp" \
'.metadata.creationTimestamp // "unknown"' \
'{"metadata": {}}'

# Test 11: Array length operations
echo ""
echo "Testing array length operations..."
test_jq "Array length calculation" \
'length' \
'["item1", "item2", "item3"]'

test_jq "Empty array length" \
'length' \
'[]'

# Test all actual jq expressions from the script
echo ""
echo "========================================="
echo "Testing actual expressions from collect-tkgi-cluster-data.sh..."
echo "========================================="
echo ""

# List of actual jq expressions used in the script
declare -a JQ_EXPRESSIONS=(
    '.metadata.creationTimestamp // "unknown"'
    '[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas, updated: .status.updatedReplicas, lastUpdate: (.metadata.annotations["deployment.kubernetes.io/revision"] // "unknown")}]'
    'length'
    '[.items[] | {name: .metadata.name, replicas: .spec.replicas, ready: .status.readyReplicas}]'
    '[.items[].status.startTime] | max // "unknown"'
    '[.items[] | {name: .metadata.name, hard: .status.hard, used: .status.used}]'
    '[.items[] | {name: .metadata.name, type: .spec.type, ports: [.spec.ports[].port]}]'
)

for expr in "${JQ_EXPRESSIONS[@]}"; do
    # Create a minimal valid JSON that should work with all expressions
    MINIMAL_JSON='{
        "metadata": {
            "creationTimestamp": "2025-01-20T10:00:00Z",
            "name": "test",
            "annotations": {}
        },
        "items": [],
        "spec": {},
        "status": {}
    }'
    
    test_jq "Script expression: $(echo "$expr" | head -c 50)..." \
        "$expr" \
        "$MINIMAL_JSON"
done

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
printf "${GREEN}Passed:${NC} %d\n" "$PASSED_TESTS"
printf "${RED}Failed:${NC} %d\n" "$FAILED_TESTS"

if [[ $FAILED_TESTS -eq 0 ]]; then
    printf "${GREEN}✓ All jq syntax tests passed!${NC}\n"
    exit 0
else
    printf "${RED}✗ Some jq syntax tests failed!${NC}\n"
    exit 1
fi