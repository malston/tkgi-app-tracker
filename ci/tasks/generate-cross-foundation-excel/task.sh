#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Generating cross-foundation Excel workbook..."

# Source helper functions
# shellcheck disable=SC1091
source tkgi-app-tracker-repo/scripts/helpers.sh

info "=== SCRIPT START DEBUG ==="
info "Script starting at: $(date)"
info "Working directory: $(pwd)"
info "Available directories:"
ls -la . || true
info "======================="

# Set defaults
INCLUDE_CHARTS="${INCLUDE_CHARTS:-true}"
WORKBOOK_NAME="${WORKBOOK_NAME:-}"

# Create output directory
mkdir -p cross-foundation-excel

info "Starting cross-foundation Excel generation"
info "Include charts: ${INCLUDE_CHARTS}"

# Find the consolidated data directory
CONSOLIDATED_DIR=""

# Check multiple possible locations for consolidated data
info "=== Consolidated Data Directory Discovery ==="
info "Checking for consolidated data directories..."

if [[ -d "consolidated-data/consolidated" ]]; then
    CONSOLIDATED_DIR="consolidated-data/consolidated"
    info "Found: consolidated-data/consolidated"
elif [[ -d "consolidated-data" ]]; then
    CONSOLIDATED_DIR="consolidated-data"
    info "Found: consolidated-data"
elif [[ -d "consolidated" ]]; then
    CONSOLIDATED_DIR="consolidated"
    info "Found: consolidated"
else
    error "Could not find consolidated data directory"
    error "Checked locations:"
    error "  - consolidated-data/consolidated"
    error "  - consolidated-data"
    error "  - consolidated"
    error "Available directories in current location:"
    ls -la . || true
    exit 1
fi

info "Selected CONSOLIDATED_DIR: ${CONSOLIDATED_DIR}"
info "=== End Directory Discovery ==="

info "Using consolidated data from: ${CONSOLIDATED_DIR}"

# Find the latest consolidated CSV files
LATEST_TIMESTAMP=""
declare -A CONSOLIDATED_FILES

# Look for timestamped consolidated files
info "=== File Pattern Matching Debug ==="
info "Looking for files matching: ${CONSOLIDATED_DIR}/consolidated_*_*.csv"
for csv_file in "${CONSOLIDATED_DIR}"/consolidated_*_*.csv; do
    info "Processing glob result: '${csv_file}'"
    if [[ -f "${csv_file}" ]]; then
        # Extract timestamp from filename (format: consolidated_<type>_YYYYMMDD_HHMMSS.csv)
        filename=$(basename "${csv_file}")
        info "Processing file: '${filename}'"
        if [[ "${filename}" =~ consolidated_[a-z_]+_([0-9]{8}_[0-9]{6})\.csv ]]; then
            file_timestamp="${BASH_REMATCH[1]}"
            info "Extracted timestamp: '${file_timestamp}'"

            # Use the first timestamp we find as the reference
            if [[ -z "${LATEST_TIMESTAMP}" ]]; then
                LATEST_TIMESTAMP="${file_timestamp}"
                info "Set LATEST_TIMESTAMP to: '${LATEST_TIMESTAMP}'"
            fi

            # Only process files with the latest timestamp
            if [[ "${file_timestamp}" == "${LATEST_TIMESTAMP}" ]]; then
                if [[ "${filename}" =~ consolidated_([a-z_]+)_[0-9]{8}_[0-9]{6}\.csv ]]; then
                    report_type="${BASH_REMATCH[1]}"
                    CONSOLIDATED_FILES["${report_type}"]="${csv_file}"
                    info "Found ${report_type} report: ${filename}"
                else
                    info "Second regex failed for: '${filename}'"
                fi
            else
                info "Timestamp mismatch: '${file_timestamp}' != '${LATEST_TIMESTAMP}'"
            fi
        else
            info "First regex failed for: '${filename}'"
        fi
    else
        info "Not a file: '${csv_file}'"
    fi
done
info "=== End File Pattern Matching Debug ==="

# Debug: Show what we found in the discovery phase
info "=== File Discovery Debug ==="
info "CONSOLIDATED_DIR: ${CONSOLIDATED_DIR}"
info "Files found in consolidated directory:"
ls -la "${CONSOLIDATED_DIR}" || error "Could not list consolidated directory"
info "LATEST_TIMESTAMP: ${LATEST_TIMESTAMP}"
info "CONSOLIDATED_FILES keys: ${!CONSOLIDATED_FILES[*]}"
for key in "${!CONSOLIDATED_FILES[@]}"; do
    info "  ${key} -> ${CONSOLIDATED_FILES[$key]}"
done
info "=========================="

# Verify we have the essential files
required_files=("applications" "executive_summary")
missing_files=()

for required in "${required_files[@]}"; do
    if [[ -z "${CONSOLIDATED_FILES[$required]:-}" ]]; then
        missing_files+=("${required}")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    error "Missing required consolidated files: ${missing_files[*]}"
    error "Available files:"
    for key in "${!CONSOLIDATED_FILES[@]}"; do
        error "  ${key}: ${CONSOLIDATED_FILES[$key]}"
    done
    exit 1
fi

info "Using consolidated data with timestamp: ${LATEST_TIMESTAMP}"

# Create a working directory with properly named CSV files for the Excel generator
# Use absolute path to ensure it works after changing directories
WORK_DIR="$(pwd)/cross-foundation-excel/work"
mkdir -p "${WORK_DIR}"

info "Preparing CSV files for Excel generation..."

# Debug: Show what files we found
info "CONSOLIDATED_FILES array contents:"
for key in "${!CONSOLIDATED_FILES[@]}"; do
    info "  ${key}: ${CONSOLIDATED_FILES[$key]}"
done

# Debug: Show the work directory path resolution
info "WORK_DIR: ${WORK_DIR}"
info "Resolved work directory: $(realpath "${WORK_DIR}" 2>/dev/null || echo "cannot resolve")"

# Copy consolidated files with the naming convention expected by generate-excel-template.py
# The script looks for patterns like application_report_*.csv, executive_summary_*.csv, etc.
if [[ -n "${CONSOLIDATED_FILES[applications]:-}" ]]; then
    if cp "${CONSOLIDATED_FILES[applications]}" "${WORK_DIR}/application_report_${LATEST_TIMESTAMP}.csv"; then
        info "✓ Copied applications data successfully"
    else
        error "✗ Failed to copy applications data"
        exit 1
    fi
fi

if [[ -n "${CONSOLIDATED_FILES[executive_summary]:-}" ]]; then
    if cp "${CONSOLIDATED_FILES[executive_summary]}" "${WORK_DIR}/executive_summary_${LATEST_TIMESTAMP}.csv"; then
        info "✓ Copied executive summary data successfully"
    else
        error "✗ Failed to copy executive summary data"
        exit 1
    fi
fi

if [[ -n "${CONSOLIDATED_FILES[clusters]:-}" ]]; then
    if cp "${CONSOLIDATED_FILES[clusters]}" "${WORK_DIR}/cluster_report_${LATEST_TIMESTAMP}.csv"; then
        info "✓ Copied clusters data successfully"
    else
        error "✗ Failed to copy clusters data"
        exit 1
    fi
fi

if [[ -n "${CONSOLIDATED_FILES[migration_priority]:-}" ]]; then
    if cp "${CONSOLIDATED_FILES[migration_priority]}" "${WORK_DIR}/migration_priority_${LATEST_TIMESTAMP}.csv"; then
        info "✓ Copied migration priority data successfully"
    else
        error "✗ Failed to copy migration priority data"
        exit 1
    fi
fi

info "=== POST-COPY DEBUG ==="
info "Files in work directory after copying:"
ls -la "${WORK_DIR}" || info "Could not list work directory"
info "======================="

# Change to scripts directory
cd tkgi-app-tracker-repo/scripts

# Generate Excel workbook name
if [[ -z "${WORKBOOK_NAME}" ]]; then
    WORKBOOK_NAME="TKGI_App_Tracker_Analysis_${LATEST_TIMESTAMP}.xlsx"
fi

info "Generating Excel workbook: ${WORKBOOK_NAME}"

# Check if the Excel generation script exists
if [[ ! -f "generate-excel-template.py" ]]; then
    error "Excel generation script not found: generate-excel-template.py"
    error "Available scripts in $(pwd):"
    ls -la ./*.py || true
    exit 1
fi

# Install required Python packages from requirements.txt
info "Installing required Python packages..."
if [[ -f "../../tkgi-app-tracker-repo/requirements.txt" ]]; then
    if ! pip3 install -r ../../tkgi-app-tracker-repo/requirements.txt; then
        error "Failed to install Python packages from requirements.txt"
        error "This is required for Excel generation. Pipeline cannot continue."
        exit 1
    fi
else
    # Fallback to direct installation if requirements.txt not found
    if ! pip3 install pandas openpyxl; then
        error "Failed to install required Python packages (pandas, openpyxl)"
        error "This is required for Excel generation. Pipeline cannot continue."
        exit 1
    fi
fi

# Verify critical packages are available
info "Verifying Python dependencies..."
python3 -c "
import sys
try:
    import pandas
    import openpyxl
    print('✓ All required Python packages are available')
except ImportError as e:
    print(f'✗ Missing required Python package: {e}')
    sys.exit(1)
" || {
    error "Python dependency verification failed"
    exit 1
}

# Generate the Excel workbook
# The script expects the -o argument to point to a directory containing CSV files
info "Executing: python3 generate-excel-template.py -o ${WORK_DIR}"

# Debug: Show what CSV files are in the work directory
info "CSV files in work directory before generation:"
ls -la "${WORK_DIR}"/*.csv 2>/dev/null || info "No CSV files found in work directory"

# Debug: Check if the script exists
if [[ ! -f "generate-excel-template.py" ]]; then
    error "generate-excel-template.py not found in $(pwd)"
    ls -la . | head -10
    exit 1
fi

# Run with explicit error capture
info "Running Excel generation with error capture..."
if python3 generate-excel-template.py -o "${WORK_DIR}" 2>&1; then
    info "Excel workbook generated successfully"

    # Debug: List all files in work directory
    info "Files in work directory after generation:"
    ls -la "${WORK_DIR}" || true

    # The script generates a file with its own timestamp, find it
    GENERATED_FILE=$(find "${WORK_DIR}" -name "TKGI_App_Tracker_Analysis_*.xlsx" -type f | head -1)

    # Debug: Show what find command found
    info "Find command result: '${GENERATED_FILE}'"

    if [[ -n "${GENERATED_FILE}" && -f "${GENERATED_FILE}" ]]; then
        # Move the generated file to the expected location with our preferred name
        OUTPUT_FILE="../../cross-foundation-excel/${WORKBOOK_NAME}"
        mv "${GENERATED_FILE}" "${OUTPUT_FILE}"
        info "Moved Excel workbook to: ${OUTPUT_FILE}"
        file_size=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null || echo "unknown")
        info "Output file: ${OUTPUT_FILE} (${file_size} bytes)"

        # Create a summary file
        cat > "../../cross-foundation-excel/generation-summary.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "workbook_name": "${WORKBOOK_NAME}",
    "data_timestamp": "${LATEST_TIMESTAMP}",
    "input_files": {
$(
        keys=("${!CONSOLIDATED_FILES[@]}")
        last_key="${keys[-1]}"
        for key in "${keys[@]}"; do
            echo -n "        \"${key}\": \"$(basename "${CONSOLIDATED_FILES[$key]}")\""
            if [[ "${key}" != "${last_key}" ]]; then echo ","; else echo ""; fi
        done
)
    },
    "include_charts": ${INCLUDE_CHARTS},
    "file_size_bytes": ${file_size:-0}
}
EOF

        info "Generation summary saved to: generation-summary.json"

        # Clean up work directory
        rm -rf "${WORK_DIR}"
    else
        error "Excel file was not generated"
        exit 1
    fi
else
    error "Excel generation failed"
    exit 1
fi

echo ""
echo "========================================="
completed "Cross-Foundation Excel Generation Complete"
echo "========================================="
echo "Workbook: ${WORKBOOK_NAME}"
echo "Data timestamp: ${LATEST_TIMESTAMP}"
echo "Foundations included: $(python3 -c "
import pandas as pd
try:
    df = pd.read_csv('../../${CONSOLIDATED_FILES[applications]}')
    if 'foundation' in df.columns:
        foundations = sorted(df['foundation'].unique())
        print(', '.join(foundations))
    else:
        print('foundation data not available')
except:
    print('unable to determine')
")"
echo "Total applications: $(python3 -c "
import pandas as pd
try:
    df = pd.read_csv('../../${CONSOLIDATED_FILES[applications]}')
    print(len(df))
except:
    print('unknown')
")"
echo "========================================="
