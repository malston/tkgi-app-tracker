#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Running unit tests..."

# Install additional tools needed for tests
if ! command -v jq &>/dev/null; then
  apt-get update && apt-get install -y jq
fi

if ! command -v shellcheck &>/dev/null; then
  apt-get update && apt-get install -y shellcheck
fi

# Change to repository directory to run tests like a developer would
cd tkgi-app-tracker-repo
chmod +x scripts/*.sh

# Run shellcheck on all shell scripts
echo "Running shellcheck validation..."
for script in scripts/*.sh; do
  echo "Checking $script..."
  shellcheck "$script" || true
done

# Run BATS tests if they exist
if ls tests/test-*.bats >/dev/null 2>&1; then
  echo "Running BATS tests..."
  bats tests/test-*.bats
else
  echo "No BATS tests found, skipping"
fi

echo "Unit tests completed"