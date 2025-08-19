#!/usr/bin/env bats

# BATS tests for foundation-utils.sh
# Tests foundation parsing and utility functions

setup() {
    # Source the foundation utilities
    source "${BATS_TEST_DIRNAME}/../scripts/foundation-utils.sh"
}

@test "get_datacenter should extract datacenter from foundation name" {
    result=$(get_datacenter "dc01-k8s-n-01")
    [ "$result" = "dc01" ]
    
    result=$(get_datacenter "dc02-k8s-n-02")
    [ "$result" = "dc02" ]
    
    result=$(get_datacenter "dc03-k8s-p-01")
    [ "$result" = "dc03" ]
}

@test "get_datacenter_type should extract type from foundation name" {
    result=$(get_datacenter_type "dc01-k8s-n-01")
    [ "$result" = "k8s" ]
    
    result=$(get_datacenter_type "dc02-cf-n-01")
    [ "$result" = "cf" ]
}

@test "get_environment_code should extract environment code" {
    result=$(get_environment_code "dc01-k8s-n-01")
    [ "$result" = "l" ]
    
    result=$(get_environment_code "dc02-k8s-n-01") 
    [ "$result" = "n" ]
    
    result=$(get_environment_code "dc03-k8s-p-01")
    [ "$result" = "p" ]
}

@test "get_instance should extract instance number" {
    result=$(get_instance "dc01-k8s-n-01")
    [ "$result" = "01" ]
    
    result=$(get_instance "dc02-k8s-n-02")
    [ "$result" = "02" ]
}

@test "get_environment_from_foundation should determine correct environment" {
    # DC01 is always lab regardless of environment code
    result=$(get_environment_from_foundation "dc01-k8s-n-01")
    [ "$result" = "lab" ]
    
    result=$(get_environment_from_foundation "dc01-k8s-p-01")
    [ "$result" = "lab" ]
    
    # Other datacenters use environment code
    result=$(get_environment_from_foundation "dc02-k8s-n-01")
    [ "$result" = "nonprod" ]
    
    result=$(get_environment_from_foundation "dc03-k8s-p-01")
    [ "$result" = "prod" ]
    
    result=$(get_environment_from_foundation "dc04-k8s-p-01")
    [ "$result" = "prod" ]
}

@test "validate_foundation_format should validate foundation name format" {
    # Valid formats
    run validate_foundation_format "dc01-k8s-n-01"
    [ "$status" -eq 0 ]
    
    run validate_foundation_format "dc02-k8s-n-02"
    [ "$status" -eq 0 ]
    
    run validate_foundation_format "dc03-k8s-p-01"
    [ "$status" -eq 0 ]
    
    # Invalid formats
    run validate_foundation_format "invalid"
    [ "$status" -eq 1 ]
    
    run validate_foundation_format "dc01-k8s-n"
    [ "$status" -eq 1 ]
    
    run validate_foundation_format "dc01-n-01"
    [ "$status" -eq 1 ]
    
    run validate_foundation_format ""
    [ "$status" -eq 1 ]
}

@test "get_pipeline_name should generate environment-specific pipeline names" {
    result=$(get_pipeline_name "tkgi-app-tracker" "dc01-k8s-n-01")
    [ "$result" = "tkgi-app-tracker-lab" ]
    
    result=$(get_pipeline_name "tkgi-app-tracker" "dc02-k8s-n-01")
    [ "$result" = "tkgi-app-tracker-nonprod" ]
    
    result=$(get_pipeline_name "tkgi-app-tracker" "dc03-k8s-p-01")
    [ "$result" = "tkgi-app-tracker-prod" ]
}

@test "get_foundations_for_environment should filter foundations by environment" {
    foundations=("dc01-k8s-n-01" "dc02-k8s-n-01" "dc02-k8s-n-02" "dc03-k8s-p-01" "dc04-k8s-p-01")
    
    # Test lab environment
    result=$(get_foundations_for_environment "lab" "${foundations[@]}")
    [ "$result" = "dc01-k8s-n-01" ]
    
    # Test nonprod environment  
    result=$(get_foundations_for_environment "nonprod" "${foundations[@]}")
    echo "Nonprod result: '$result'" >&2
    [[ "$result" == *"dc02-k8s-n-01"* ]]
    [[ "$result" == *"dc02-k8s-n-02"* ]]
    
    # Test prod environment
    result=$(get_foundations_for_environment "prod" "${foundations[@]}")
    echo "Prod result: '$result'" >&2
    [[ "$result" == *"dc03-k8s-p-01"* ]]
    [[ "$result" == *"dc04-k8s-p-01"* ]]
}

@test "foundation parsing should handle edge cases" {
    # Test with uppercase (should fail validation)
    run validate_foundation_format "DC01-K8S-L-01"
    [ "$status" -eq 1 ]
    
    # Test with extra components
    run validate_foundation_format "dc01-k8s-n-01-extra"
    [ "$status" -eq 1 ]
    
    # Test with invalid instance format
    run validate_foundation_format "dc01-k8s-l-1"
    [ "$status" -eq 1 ]
}

@test "environment determination should handle unknown environment codes" {
    result=$(get_environment_from_foundation "dc02-k8s-x-01")
    [ "$result" = "unknown" ]
    
    # But DC01 should always return lab
    result=$(get_environment_from_foundation "dc01-k8s-x-01") 
    [ "$result" = "lab" ]
}