#!/usr/bin/env bats

# Unit tests for data collection functionality

setup() {
    # Create temporary directory for test data
    export TEST_DATA_DIR=$(mktemp -d)
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../scripts"
}

teardown() {
    # Clean up test data
    rm -rf "$TEST_DATA_DIR"
}

@test "collect-tkgi-cluster-data.sh shows usage when no arguments provided" {
    run "${SCRIPT_DIR}/collect-tkgi-cluster-data.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "collect-tkgi-cluster-data.sh shows usage when foundation missing" {
    run "${SCRIPT_DIR}/collect-tkgi-cluster-data.sh" -c test-cluster
    [ "$status" -eq 1 ]
    [[ "$output" == *"Foundation and cluster parameters are required"* ]]
}

@test "collect-all-tkgi-clusters.sh shows usage with help flag" {
    run "${SCRIPT_DIR}/collect-all-tkgi-clusters.sh" -h
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "aggregate-data.py shows help when run with --help" {
    run python3 "${SCRIPT_DIR}/aggregate-data.py" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aggregate TKGI application tracking data"* ]]
}

@test "generate-reports.py shows help when run with --help" {
    run python3 "${SCRIPT_DIR}/generate-reports.py" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Generate TKGI application tracking reports"* ]]
}