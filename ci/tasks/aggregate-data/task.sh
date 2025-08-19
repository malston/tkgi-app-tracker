#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Starting data aggregation..."

# Change to scripts directory and run aggregation
cd tkgi-app-tracker-repo/scripts
chmod +x ./*.py

# Create output directory (relative to working directory)
mkdir -p ../../aggregated-data/reports

# Run aggregation with proper paths
python3 aggregate-data.py -d ../../collected-data/data -r ../../aggregated-data/reports

# Validate output (back to working directory for output validation)
cd ../../
if ! ls aggregated-data/reports/applications_*.json >/dev/null 2>&1; then
  echo "Error: Aggregation failed"
  exit 1
fi

echo "Data aggregation completed successfully"
ls -la aggregated-data/reports/