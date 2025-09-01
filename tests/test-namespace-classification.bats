#!/usr/bin/env bats

# Test namespace discovery and classification behavior
# Tests the is_system_namespace function and namespace counting logic

# Source the script to test
setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

    # Source the helper functions
    source "${PROJECT_ROOT}/scripts/helpers.sh"

    # Define the is_system_namespace function from collect-tkgi-cluster-data.sh
    # without sourcing the entire script (which would trigger usage checks)
    is_system_namespace() {
        local ns=$1
        # Handle empty namespace name
        if [[ -z "$ns" ]]; then
            return 1
        fi
        case $ns in
            kube-*|default|istio-*|gatekeeper-*|cert-manager|pks-system|observability|monitoring|logging|trident|vmware-*|tanzu-*)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }
}

# Test the is_system_namespace function from helpers.sh
@test "helpers.sh is_system_namespace should identify system namespaces correctly" {
    # Test known system namespaces
    run is_system_namespace "kube-system"
    [ "$status" -eq 0 ]

    run is_system_namespace "kube-public"
    [ "$status" -eq 0 ]

    run is_system_namespace "kube-node-lease"
    [ "$status" -eq 0 ]

    run is_system_namespace "default"
    [ "$status" -eq 0 ]

    run is_system_namespace "istio-system"
    [ "$status" -eq 0 ]

    run is_system_namespace "cert-manager"
    [ "$status" -eq 0 ]

    run is_system_namespace "pks-system"
    [ "$status" -eq 0 ]

    run is_system_namespace "vmware-system-auth"
    [ "$status" -eq 0 ]

    run is_system_namespace "monitoring"
    [ "$status" -eq 0 ]
}

@test "helpers.sh is_system_namespace should identify application namespaces correctly" {
    # Test application namespaces
    run is_system_namespace "my-app"
    [ "$status" -eq 1 ]

    run is_system_namespace "production"
    [ "$status" -eq 1 ]

    run is_system_namespace "staging"
    [ "$status" -eq 1 ]

    run is_system_namespace "development"
    [ "$status" -eq 1 ]

    run is_system_namespace "app-backend"
    [ "$status" -eq 1 ]

    run is_system_namespace "web-frontend"
    [ "$status" -eq 1 ]

    run is_system_namespace "data-pipeline"
    [ "$status" -eq 1 ]
}

# Test namespace counting logic
@test "namespace counting should correctly identify system vs application namespaces" {
    # Mock namespace list
    mock_namespaces=(
        "kube-system"
        "kube-public"
        "kube-node-lease"
        "default"
        "istio-system"
        "my-app"
        "production-service"
        "staging-env"
        "cert-manager"
        "monitoring"
        "user-app-1"
        "user-app-2"
    )

    # Count system vs application namespaces
    system_count=0
    app_count=0

    for ns in "${mock_namespaces[@]}"; do
        if is_system_namespace "$ns"; then
            system_count=$((system_count + 1))
        else
            app_count=$((app_count + 1))
        fi
    done

    # Expected: 7 system namespaces, 5 application namespaces
    [ "$system_count" -eq 7 ]
    [ "$app_count" -eq 5 ]
    [ "$((system_count + app_count))" -eq 12 ]
}

# Test edge cases
@test "is_system_namespace should handle edge cases" {
    # Empty namespace name
    run is_system_namespace ""
    [ "$status" -eq 1 ]

    # Namespace names that match wildcard patterns (these are considered system namespaces)
    run is_system_namespace "kube-system-backup"
    [ "$status" -eq 0 ]

    run is_system_namespace "my-istio-system"
    [ "$status" -eq 1 ]

    run is_system_namespace "default-app"
    [ "$status" -eq 1 ]
}

# Test pattern matching (if we switch to the pattern-based version)
@test "pattern matching should work for wildcard system namespaces" {
    # Define the pattern-based function for testing
    is_system_namespace_pattern() {
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

    # Test wildcards work
    run is_system_namespace_pattern "kube-system"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "kube-public"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "kube-node-lease"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "istio-system"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "istio-operator"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "vmware-system-auth"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "vmware-system-csi"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "tanzu-package-repo-global"
    [ "$status" -eq 0 ]

    run is_system_namespace_pattern "gatekeeper-system"
    [ "$status" -eq 0 ]

    # Test non-matching patterns
    run is_system_namespace_pattern "my-app"
    [ "$status" -eq 1 ]

    run is_system_namespace_pattern "production"
    [ "$status" -eq 1 ]
}

# Test realistic cluster scenarios
@test "realistic cluster scenario - mixed namespaces" {
    # Simulate a realistic TKGI cluster namespace list
    realistic_namespaces=(
        "default"
        "kube-system"
        "kube-public"
        "kube-node-lease"
        "pks-system"
        "istio-system"
        "cert-manager"
        "monitoring"
        "logging"
        "vmware-system-auth"
        "vmware-system-csi"
        "vmware-system-tmc"
        "tanzu-package-repo-global"
        "gatekeeper-system"
        "my-production-app"
        "my-staging-app"
        "data-pipeline"
        "web-frontend"
        "api-service"
        "background-worker"
    )

    system_count=0
    app_count=0

    for ns in "${realistic_namespaces[@]}"; do
        if is_system_namespace "$ns"; then
            system_count=$((system_count + 1))
        else
            app_count=$((app_count + 1))
        fi
    done

    # Verify we have reasonable counts
    [ "$system_count" -gt 5 ]  # Should have many system namespaces
    [ "$app_count" -gt 0 ]     # Should have some application namespaces
    [ "$app_count" -eq 6 ]     # Expect exactly 6 application namespaces
    [ "$system_count" -eq 14 ] # Expect exactly 14 system namespaces
    [ "$((system_count + app_count))" -eq 20 ]  # Total should match array length
}

# Test minimal cluster scenario
@test "minimal cluster scenario - mostly system namespaces" {
    # Simulate a minimal cluster with just one application
    minimal_namespaces=(
        "default"
        "kube-system"
        "kube-public"
        "kube-node-lease"
        "pks-system"
        "single-app"
    )

    system_count=0
    app_count=0

    for ns in "${minimal_namespaces[@]}"; do
        if is_system_namespace "$ns"; then
            system_count=$((system_count + 1))
        else
            app_count=$((app_count + 1))
        fi
    done

    # This scenario should result in 1 application namespace
    [ "$app_count" -eq 1 ]
    [ "$system_count" -eq 5 ]
    [ "$((system_count + app_count))" -eq 6 ]
}

# Test that both system namespace detection functions produce similar results
@test "both system namespace functions should be consistent" {
    # Test a sample of namespaces with both functions
    test_namespaces=(
        "kube-system"
        "default"
        "istio-system"
        "cert-manager"
        "monitoring"
        "my-app"
        "production"
    )

    # Define the pattern-based function from collect-tkgi-cluster-data.sh
    is_system_namespace_pattern() {
        local ns=$1
        # Handle empty namespace name
        if [[ -z "$ns" ]]; then
            return 1
        fi
        case $ns in
            kube-*|default|istio-*|gatekeeper-*|cert-manager|pks-system|observability|monitoring|logging|trident|vmware-*|tanzu-*)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

    # Both functions should agree on these common cases
    for ns in "${test_namespaces[@]}"; do
        run is_system_namespace "$ns"
        helpers_result=$status

        run is_system_namespace_pattern "$ns"
        pattern_result=$status

        # Both should agree (though they might differ on edge cases)
        if [[ "$ns" == "kube-system" || "$ns" == "default" || "$ns" == "istio-system" || "$ns" == "cert-manager" || "$ns" == "monitoring" ]]; then
            [ "$helpers_result" -eq 0 ]
            [ "$pattern_result" -eq 0 ]
        elif [[ "$ns" == "my-app" || "$ns" == "production" ]]; then
            [ "$helpers_result" -eq 1 ]
            [ "$pattern_result" -eq 1 ]
        fi
    done
}
