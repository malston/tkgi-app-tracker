#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Starting report generation..."

# Set default value for GENERATE_EXCEL if not provided
GENERATE_EXCEL="${GENERATE_EXCEL:-true}"

echo "Excel generation enabled: ${GENERATE_EXCEL}"

# Change to scripts directory and run report generation
cd tkgi-app-tracker-repo/scripts
chmod +x ./*.py

# Create output directory (relative to working directory)
mkdir -p ../../generated-reports/reports

# Generate reports with optional Excel generation
if [[ "${GENERATE_EXCEL}" == "true" ]]; then
    echo "Generating reports with Excel workbook..."
    python3 generate-reports.py -r ../../aggregated-data/reports --excel
else
    echo "Generating CSV and JSON reports only..."
    python3 generate-reports.py -r ../../aggregated-data/reports
fi

# Copy all reports to output (adjust paths since we're in scripts dir)
cp ../../aggregated-data/reports/*.csv ../../generated-reports/reports/ 2>/dev/null || true
cp ../../aggregated-data/reports/*.json ../../generated-reports/reports/ 2>/dev/null || true
# Copy Excel files if generated
if [[ "${GENERATE_EXCEL}" == "true" ]]; then
    cp ../../aggregated-data/reports/*.xlsx ../../generated-reports/reports/ 2>/dev/null || true
fi

# Validate output (back to working directory)
cd ../../
if ! ls generated-reports/reports/application_report_*.csv >/dev/null 2>&1; then
  echo "Error: Report generation failed"
  exit 1
fi

echo "Report generation completed successfully"
echo "Generated reports:"
ls -la generated-reports/reports/

# Show summary of generated files
echo ""
echo "Report summary:"
echo "  CSV files: $(find generated-reports/reports -name "*.csv" 2>/dev/null | wc -l)"
echo "  JSON files: $(find generated-reports/reports -name "*.json" 2>/dev/null | wc -l)"
if [[ "${GENERATE_EXCEL}" == "true" ]]; then
    echo "  Excel files: $(find generated-reports/reports -name "*.xlsx" 2>/dev/null | wc -l)"
fi