#!/bin/sh

set -e

echo "Validating scripts and configuration..."

# Install required tools
if ! command -v jq >/dev/null 2>&1; then
  apt-get update && apt-get install -y jq
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  apt-get update && apt-get install -y shellcheck
fi


# Change to repository directory for validation
cd tkgi-app-tracker-repo

# Validate shell scripts
echo "Validating shell scripts..."
for script in scripts/*.sh; do
  if [ -f "$script" ]; then
    echo "Checking syntax of $script..."
    bash -n "$script"
    echo "✓ $script syntax OK"
  fi
done

# Validate Python scripts
echo "Validating Python scripts..."
for script in scripts/*.py; do
  if [ -f "$script" ]; then
    echo "Checking syntax of $script..."
    python3 -m py_compile "$script"
    echo "✓ $script syntax OK"
  fi
done

# Validate pipeline YAML
echo "Validating pipeline YAML..."
if [ -f ci/pipelines/single-foundation-report.yml ]; then
  # Basic YAML validation
  python3 -c "
import yaml
import sys
try:
    with open('ci/pipelines/single-foundation-report.yml', 'r') as f:
        yaml.safe_load(f)
    print('✓ ci/pipelines/single-foundation-report.yml is valid YAML')
except yaml.YAMLError as e:
    print(f'✗ ci/pipelines/single-foundation-report.yml YAML error: {e}')
    sys.exit(1)
"
fi

echo "Script validation completed successfully"
