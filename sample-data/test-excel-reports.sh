#!/bin/bash
#
# Test Excel Reports with Sample Data
# Generates sample data and creates Excel workbooks for testing and validation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source helper functions
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/helpers.sh"

# Default values
SEED=""
VERBOSE=false
CLEAN_FIRST=false

function usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate sample data and test Excel report generation for TKGI Application Tracker.

OPTIONS:
    --seed SEED         Random seed for reproducible sample data
    --clean             Remove existing sample data first
    -v, --verbose       Verbose output
    -h, --help          Display this help message

EXAMPLES:
    # Generate sample data and test Excel reports
    $0

    # Generate reproducible sample data
    $0 --seed 12345

    # Clean existing data and regenerate
    $0 --clean

    # Verbose execution
    $0 -v

WORKFLOW:
    1. Generates realistic sample data (150+ applications across foundations)
    2. Creates CSV reports using the sample data
    3. Generates Excel workbook with pivot tables and charts
    4. Validates all report formats

SAMPLE DATA INCLUDES:
    ✓ 150 applications across 8 foundations
    ✓ Realistic migration readiness scores
    ✓ Multiple environments (lab, nonprod, prod)
    ✓ Various application sizes and complexity
    ✓ Historical trend data (12 weeks)
    ✓ Multi-foundation application deployments

EOF
}

function check_dependencies() {
    info "Checking dependencies..."

    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
        exit 1
    fi

    # Check if openpyxl is available for Excel generation
    if ! python3 -c "import openpyxl" &> /dev/null 2>&1; then
        warn "openpyxl not available - installing dependencies for Excel generation"
        if [[ -f "../requirements.txt" ]]; then
            pip3 install -r ../requirements.txt --user
        else
            pip3 install openpyxl --user
        fi
    fi

    completed "Dependencies checked"
}

function clean_existing_data() {
    if [[ "$CLEAN_FIRST" == "true" ]]; then
        info "Cleaning existing sample data..."

        if [[ -d "${SCRIPT_DIR}/reports" ]]; then
            rm -rf "${SCRIPT_DIR}/reports"
            info "Removed existing sample data"
        fi
    fi
}

function generate_sample_data() {
    info "Generating sample data..."

    local cmd="python3 '${SCRIPT_DIR}/generate-sample-data.py'"
    cmd+=" --output-dir '${SCRIPT_DIR}'"

    if [[ -n "$SEED" ]]; then
        cmd+=" --seed $SEED"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Command: $cmd"
    fi

    if eval "$cmd"; then
        completed "Sample data generated successfully"
    else
        error "Sample data generation failed"
        exit 1
    fi
}

function generate_csv_reports() {
    info "Generating CSV reports from sample data..."

    local reports_dir="${SCRIPT_DIR}/reports"

    if [[ ! -d "$reports_dir" ]]; then
        error "Sample data not found. Run sample data generation first."
        exit 1
    fi

    # Use the main report generator with sample data
    local cmd="python3 '${REPO_ROOT}/scripts/generate-reports.py'"
    cmd+=" --reports-dir '$reports_dir'"

    if [[ "$VERBOSE" == "true" ]]; then
        cmd+=" --verbose"
        info "Command: $cmd"
    fi

    if eval "$cmd"; then
        completed "CSV reports generated successfully"
    else
        error "CSV report generation failed"
        exit 1
    fi
}

function generate_excel_workbook() {
    info "Generating Excel workbook with sample data..."

    local reports_dir="${SCRIPT_DIR}/reports"

    local cmd="python3 '${REPO_ROOT}/scripts/generate-excel-template.py'"
    cmd+=" --output-dir '$reports_dir'"

    if [[ "$VERBOSE" == "true" ]]; then
        cmd+=" --verbose"
        info "Command: $cmd"
    fi

    if eval "$cmd"; then
        completed "Excel workbook generated successfully"
    else
        error "Excel workbook generation failed"
        exit 1
    fi
}

function validate_outputs() {
    info "Validating generated reports..."

    local reports_dir="${SCRIPT_DIR}/reports"
    local validation_passed=true

    # Check for JSON files
    if ! ls "${reports_dir}"/applications_*.json 1> /dev/null 2>&1; then
        error "Missing applications JSON file"
        validation_passed=false
    fi

    if ! ls "${reports_dir}"/summary_*.json 1> /dev/null 2>&1; then
        error "Missing summary JSON file"
        validation_passed=false
    fi

    # Check for CSV files
    if ! ls "${reports_dir}"/application_report_*.csv 1> /dev/null 2>&1; then
        error "Missing application CSV report"
        validation_passed=false
    fi

    if ! ls "${reports_dir}"/executive_summary_*.csv 1> /dev/null 2>&1; then
        error "Missing executive summary CSV"
        validation_passed=false
    fi

    # Check for Excel file
    if ! ls "${reports_dir}"/TKGI_App_Tracker_Analysis_*.xlsx 1> /dev/null 2>&1; then
        error "Missing Excel workbook"
        validation_passed=false
    fi

    if [[ "$validation_passed" == "true" ]]; then
        completed "All report formats validated successfully"
    else
        error "Report validation failed"
        exit 1
    fi
}

function show_results() {
    info "Sample data and reports generated successfully!"
    info ""
    info "📊 Generated Files:"

    local reports_dir="${SCRIPT_DIR}/reports"

    info "📈 JSON Data Files:"
    find "${reports_dir}" -maxdepth 1 -name "*.json" -print0 | while IFS= read -r -d '' file; do
        ls -la "$file"
        echo "    $file"
    done

    info ""
    info "📋 CSV Report Files:"
    find "${reports_dir}" -maxdepth 1 -name "*.csv" -print0 | while IFS= read -r -d '' file; do
        ls -la "$file"
        echo "    $file"
    done

    info ""
    info "📊 Excel Workbook:"
    find "${reports_dir}" -maxdepth 1 -name "*.xlsx" -print0 | while IFS= read -r -d '' file; do
        ls -la "$file"
        echo "    $file"
    done

    info ""
    info "🎯 Next Steps:"
    info "  1. Open the Excel workbook to test pivot tables and charts"
    info "  2. Follow the 'Pivot Table Instructions' sheet for analysis examples"
    info "  3. Test the executive dashboard and trend analysis features"
    info "  4. Validate the sample data represents realistic scenarios"
    info ""
    info "📁 All files are located in: ${reports_dir}"
}

function main() {
    info "TKGI Application Tracker - Excel Report Testing"
    info "=============================================="

    # Check dependencies
    check_dependencies

    # Clean existing data if requested
    clean_existing_data

    # Generate sample data
    generate_sample_data

    # Generate CSV reports
    generate_csv_reports

    # Generate Excel workbook
    generate_excel_workbook

    # Validate all outputs
    validate_outputs

    # Show results
    show_results

    completed "Excel report testing setup complete!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)
            SEED="$2"
            shift 2
            ;;
        --clean)
            CLEAN_FIRST=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

main "$@"
