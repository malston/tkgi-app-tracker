#!/usr/bin/env bats

# Unit tests for helper functions

setup() {
    # Source the helpers file
    source "${BATS_TEST_DIRNAME}/../scripts/helpers.sh"
}

@test "info function displays message with cyan color" {
    run info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "error function displays message with red color" {
    run error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"error message"* ]]
}

@test "warn function displays message with yellow color" {
    run warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning message"* ]]
}

@test "completed function displays message with green color" {
    run completed "success message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"success message"* ]]
}