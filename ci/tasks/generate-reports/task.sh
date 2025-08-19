#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Starting report generation..."

# Change to scripts directory and run report generation
cd tkgi-app-tracker-repo/scripts
chmod +x ./*.py

# Create output directory (relative to working directory)
mkdir -p ../../generated-reports/reports

# Generate all report formats with proper paths
python3 generate-reports.py -r ../../aggregated-data/reports

# Copy all reports to output (adjust paths since we're in scripts dir)
cp ../../aggregated-data/reports/*.csv ../../generated-reports/reports/ 2>/dev/null || true
cp ../../aggregated-data/reports/*.json ../../generated-reports/reports/ 2>/dev/null || true

# Validate output (back to working directory)
cd ../../
if ! ls generated-reports/reports/application_report_*.csv >/dev/null 2>&1; then
  echo "Error: Report generation failed"
  exit 1
fi

echo "Report generation completed successfully"
echo "Generated reports:"
ls -la generated-reports/reports/