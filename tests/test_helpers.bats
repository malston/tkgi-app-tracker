#!/usr/bin/env bats

# BATS tests for helpers.sh
# Tests common helper functions and utilities

setup() {
    # Source the helper functions
    source "${BATS_TEST_DIRNAME}/../scripts/helpers.sh"
}

@test "info function should display info messages" {
    run info "Test info message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test info message"* ]]
}

@test "error function should display error messages" {
    run error "Test error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test error message"* ]]
}

@test "warn function should display warning messages" {
    run warn "Test warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test warning message"* ]]
}

@test "completed function should display success messages" {
    run completed "Test completed message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test completed message"* ]]
}

@test "validate_required_env should check for required environment variables" {
    # Test with missing variable
    unset TEST_VAR
    run validate_required_env "TEST_VAR"
    [ "$status" -eq 1 ]
    
    # Test with present variable
    export TEST_VAR="test_value"
    run validate_required_env "TEST_VAR"
    [ "$status" -eq 0 ]
}

@test "tkgi_login function should handle authentication flow" {
    # Mock the external commands for testing
    function om-linux() { echo "mock_password"; return 0; }
    function tkgi() { echo "Mock tkgi command: $*"; return 0; }
    function kubectl() { echo "Mock kubectl command: $*"; return 0; }
    export -f om-linux tkgi kubectl
    
    # Test successful login
    run tkgi_login "test-cluster"
    [ "$status" -eq 0 ]
    # Should contain some output from the login process
    [[ "$output" != "" ]]
}

@test "check_dependencies should verify required tools" {
    # This function checks for required CLI tools
    # Mock some tools for testing
    function kubectl() { echo "kubectl version"; }
    function jq() { echo "jq version"; }
    export -f kubectl jq
    
    # Test dependency checking
    run check_dependencies "kubectl" "jq"
    [ "$status" -eq 0 ]
}

@test "create_output_directory should create directories" {
    # Test directory creation
    local test_dir="/tmp/test-$$"
    
    run create_output_directory "$test_dir"
    [ "$status" -eq 0 ]
    [ -d "$test_dir" ]
    
    # Clean up
    rmdir "$test_dir"
}

@test "log_execution_time should track execution time" {
    # Test timing function
    run log_execution_time "test_operation" echo 'test command'
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_operation"* ]]
}

@test "retry_command should retry failed commands" {
    # Test retry with successful command
    run retry_command 3 "true"
    [ "$status" -eq 0 ]
    
    # Test retry with failing command
    run retry_command 2 "false"
    [ "$status" -eq 1 ]
}

@test "parse_json_field should extract JSON values" {
    # Create temporary JSON file
    local json_file="/tmp/test-$$.json"
    echo '{"test_field": "test_value", "number": 42}' > "$json_file"
    
    # Test string field extraction
    run parse_json_field "$json_file" ".test_field"
    [ "$status" -eq 0 ]
    [ "$output" = "test_value" ]
    
    # Test number field extraction  
    run parse_json_field "$json_file" ".number"
    [ "$status" -eq 0 ]
    [ "$output" = "42" ]
    
    # Clean up
    rm "$json_file"
}

@test "format_timestamp should format dates consistently" {
    # Test timestamp formatting
    run format_timestamp "2025-01-19T12:34:56Z"
    [ "$status" -eq 0 ]
    # Should return a formatted date string
    [[ "$output" != "" ]]
}

@test "calculate_days_since should calculate date differences" {
    # Test with empty timestamp
    run calculate_days_since ""
    [ "$status" -eq 0 ]
    [ "$output" -eq 999 ]
    
    # Test with valid recent timestamp (within last few days)
    local recent_date="2025-01-19T12:00:00Z"
    run calculate_days_since "$recent_date"
    [ "$status" -eq 0 ]
    # Should be a reasonable number (not 999)
    [ "$output" -ne 999 ]
}

@test "sanitize_app_id should clean application IDs" {
    # Test app ID sanitization
    run sanitize_app_id "APP-12345-test"
    [ "$status" -eq 0 ]
    [ "$output" = "app-12345-test" ]
    
    # Test with special characters
    run sanitize_app_id "app@#$%^&*()"
    [ "$status" -eq 0 ]
    # Should remove special characters
    [[ "$output" != *"@"* ]]
}

@test "is_system_namespace should identify system namespaces" {
    # Test system namespace identification
    run is_system_namespace "kube-system"
    [ "$status" -eq 0 ]
    
    run is_system_namespace "default"
    [ "$status" -eq 0 ]
    
    run is_system_namespace "istio-system"
    [ "$status" -eq 0 ]
    
    # Test application namespace
    run is_system_namespace "my-app-namespace"
    [ "$status" -eq 1 ]
}

@test "extract_app_id should extract application IDs from namespace names" {
    # Test app ID extraction from namespace patterns
    run extract_app_id "app-12345-prod"
    [ "$status" -eq 0 ]
    [ "$output" = "12345" ]
    
    # Test with different pattern
    run extract_app_id "web-frontend-app"
    [ "$status" -eq 0 ]
    [[ "$output" != "" ]]
}

@test "color output functions should work with and without color support" {
    # Test with color support
    export TERM="xterm-256color"
    run info "Colored message"
    [ "$status" -eq 0 ]
    
    # Test without color support
    export NO_COLOR=1
    run info "Uncolored message" 
    [ "$status" -eq 0 ]
    unset NO_COLOR
}