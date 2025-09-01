#!/usr/bin/env bats

# Test JSON combination logic from collect-all-tkgi-clusters.sh
# This ensures proper comma separation between JSON objects when combining files

# Source the script to test
setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    
    # Create temporary directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
    
    # Source helper functions for logging
    source "${PROJECT_ROOT}/scripts/helpers.sh"
}

teardown() {
    # Clean up temporary files
    if [[ -n "${TEST_TEMP_DIR}" && -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Test combining two valid JSON array files
@test "should combine two JSON array files into valid JSON" {
    # Create test input files
    local file1="${TEST_TEMP_DIR}/cluster1.json"
    local file2="${TEST_TEMP_DIR}/cluster2.json"
    local combined_output="${TEST_TEMP_DIR}/combined.json"
    
    # Create first test file with 2 objects
    cat > "${file1}" << 'EOF'
[
  {
    "namespace": "default",
    "cluster": "cluster1",
    "is_system": true
  },
  {
    "namespace": "app1", 
    "cluster": "cluster1",
    "is_system": false
  }
]
EOF

    # Create second test file with 2 objects
    cat > "${file2}" << 'EOF'
[
  {
    "namespace": "kube-system",
    "cluster": "cluster2", 
    "is_system": true
  },
  {
    "namespace": "app2",
    "cluster": "cluster2",
    "is_system": false
  }
]
EOF

    # Simulate the combination logic from the script
    echo "[" > "${combined_output}"
    
    # Process first file - extract objects and add commas
    local temp_file1="${TEST_TEMP_DIR}/temp1"
    jq -c '.[]' "${file1}" > "${temp_file1}"
    awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp_file1}" >> "${combined_output}"
    
    # Process second file
    echo "," >> "${combined_output}"
    local temp_file2="${TEST_TEMP_DIR}/temp2"
    jq -c '.[]' "${file2}" > "${temp_file2}"
    awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp_file2}" >> "${combined_output}"
    
    # Close array
    echo "]" >> "${combined_output}"
    
    # Validate the combined JSON
    run jq empty "${combined_output}"
    [ "$status" -eq 0 ]
    
    # Verify it contains 4 objects
    run jq 'length' "${combined_output}"
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
    
    # Verify content is correct
    cluster1_count=$(jq '[.[] | select(.cluster == "cluster1")] | length' "${combined_output}")
    cluster2_count=$(jq '[.[] | select(.cluster == "cluster2")] | length' "${combined_output}")
    
    [ "$cluster1_count" = "2" ]
    [ "$cluster2_count" = "2" ]
}

# Test that demonstrates the original bug would fail
@test "should fail with improper comma placement (demonstrates original bug)" {
    local file1="${TEST_TEMP_DIR}/bug_demo1.json"
    local file2="${TEST_TEMP_DIR}/bug_demo2.json"
    local buggy_output="${TEST_TEMP_DIR}/buggy_combined.json"
    
    # Create test files
    echo '[{"obj": 1}, {"obj": 2}]' > "${file1}"
    echo '[{"obj": 3}]' > "${file2}"
    
    # Simulate the ORIGINAL buggy logic (without comma fix)
    echo "[" > "${buggy_output}"
    jq -c '.[]' "${file1}" >> "${buggy_output}"  # No commas added between objects!
    echo "," >> "${buggy_output}"
    jq -c '.[]' "${file2}" >> "${buggy_output}"  # No commas added between objects!
    echo "]" >> "${buggy_output}"
    
    # This should fail jq validation due to missing commas
    run jq empty "${buggy_output}"
    [ "$status" -ne 0 ]  # Should fail validation
}

# Test combining realistic namespace data
@test "should combine realistic cluster namespace data" {
    local cluster1_data="${TEST_TEMP_DIR}/cluster1_namespaces.json"
    local cluster2_data="${TEST_TEMP_DIR}/cluster2_namespaces.json"
    local final_output="${TEST_TEMP_DIR}/combined_namespaces.json"
    
    # Create realistic cluster data
    cat > "${cluster1_data}" << 'EOF'
[
  {
    "namespace": "default",
    "cluster": "cluster01.example.com",
    "foundation": "test-foundation",
    "is_system": true,
    "pod_count": 0,
    "deployment_count": 0
  },
  {
    "namespace": "my-app",
    "cluster": "cluster01.example.com", 
    "foundation": "test-foundation",
    "is_system": false,
    "pod_count": 3,
    "deployment_count": 1
  }
]
EOF

    cat > "${cluster2_data}" << 'EOF'
[
  {
    "namespace": "kube-system",
    "cluster": "cluster02.example.com",
    "foundation": "test-foundation", 
    "is_system": true,
    "pod_count": 15,
    "deployment_count": 5
  }
]
EOF

    # Combine using the production logic
    echo "[" > "${final_output}"
    
    # Process first file
    local temp1="${TEST_TEMP_DIR}/temp1"
    jq -c '.[]' "${cluster1_data}" > "${temp1}"
    awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp1}" >> "${final_output}"
    
    # Process second file
    echo "," >> "${final_output}"
    local temp2="${TEST_TEMP_DIR}/temp2"
    jq -c '.[]' "${cluster2_data}" > "${temp2}"
    awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp2}" >> "${final_output}"
    
    echo "]" >> "${final_output}"
    
    # Should be valid JSON
    run jq empty "${final_output}"
    [ "$status" -eq 0 ]
    
    # Should have 3 total namespaces
    run jq 'length' "${final_output}"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
    
    # Verify system vs application namespace counts
    system_count=$(jq '[.[] | select(.is_system == true)] | length' "${final_output}")
    app_count=$(jq '[.[] | select(.is_system == false)] | length' "${final_output}")
    
    [ "$system_count" = "2" ]
    [ "$app_count" = "1" ]
    
    # Verify cluster distribution
    c1_count=$(jq '[.[] | select(.cluster == "cluster01.example.com")] | length' "${final_output}")
    c2_count=$(jq '[.[] | select(.cluster == "cluster02.example.com")] | length' "${final_output}")
    
    [ "$c1_count" = "2" ]
    [ "$c2_count" = "1" ]
}

# Test empty array handling
@test "should handle empty JSON arrays gracefully" {
    local empty_file="${TEST_TEMP_DIR}/empty.json"
    local data_file="${TEST_TEMP_DIR}/data.json"
    local result_file="${TEST_TEMP_DIR}/result.json"
    
    # Create files
    echo '[]' > "${empty_file}"
    echo '[{"data": "test"}]' > "${data_file}"
    
    # Combine (modified logic to handle empty arrays)
    echo "[" > "${result_file}"
    
    # Process empty file (check if it produces any content)
    local temp_empty="${TEST_TEMP_DIR}/temp_empty"
    jq -c '.[]' "${empty_file}" > "${temp_empty}"
    
    local empty_content
    empty_content=$(awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp_empty}")
    
    # Only add content if not empty
    if [[ -n "${empty_content}" ]]; then
        echo "${empty_content}" >> "${result_file}"
        echo "," >> "${result_file}"
    fi
    
    # Process non-empty file
    local temp_data="${TEST_TEMP_DIR}/temp_data"
    jq -c '.[]' "${data_file}" > "${temp_data}"
    awk '{if(NR>1) print prev ","; prev=$0} END{if(prev) print prev}' "${temp_data}" >> "${result_file}"
    
    echo "]" >> "${result_file}"
    
    # Should be valid JSON
    run jq empty "${result_file}"
    [ "$status" -eq 0 ]
    
    # Should contain only 1 object (empty array contributes nothing)
    run jq 'length' "${result_file}"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}