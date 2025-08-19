#!/bin/bash
#
# Excel Report Generator for TKGI Application Tracker
# Convenience script to generate Excel workbooks with pivot tables and charts
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/helpers.sh"

# Default values
OUTPUT_DIR="reports"
VERBOSE=false
DRY_RUN=false
TEMPLATE_ONLY=false

function usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Excel workbooks for TKGI Application Tracker analysis with pivot tables and charts.

OPTIONS:
    -o, --output-dir DIR    Output directory for Excel files (default: reports)
    -t, --template-only     Generate template workbook without data
    -v, --verbose           Verbose output
    --dry-run              Show what would be executed without running
    -h, --help             Display this help message

EXAMPLES:
    # Generate Excel workbook from latest CSV reports
    $0

    # Generate with custom output directory
    $0 -o /tmp/excel-reports

    # Generate template workbook only
    $0 --template-only

    # Verbose execution
    $0 -v

FEATURES:
    ✓ Application data with professional formatting
    ✓ Executive dashboard with key metrics
    ✓ Charts and visualizations
    ✓ Pivot table instructions and examples
    ✓ Trend analysis template with formulas
    ✓ Ready-to-use Excel workbook for management reporting

REQUIREMENTS:
    • Python 3.9+ virtual environment (run 'make setup' to install)
    • Latest CSV reports generated (run generate-reports first)

EOF
}

function install_dependencies() {
    info "Checking Python dependencies..."

    # Determine which Python to use - prefer virtual environment
    local python_cmd="python3"

    # Check if we're in a virtual environment or if venv exists
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        python_cmd="python"
        info "Using virtual environment: ${VIRTUAL_ENV}"
    elif [[ -f "${SCRIPT_DIR}/../venv/bin/python" ]]; then
        python_cmd="${SCRIPT_DIR}/../venv/bin/python"
        info "Using project virtual environment: ${SCRIPT_DIR}/../venv"
    fi

    if ! command -v "$python_cmd" &> /dev/null; then
        error "Python 3 is required but not installed"
        exit 1
    fi

    # Check if openpyxl is available
    if ! "$python_cmd" -c "import openpyxl" &> /dev/null; then
        error "openpyxl not available. Please install dependencies:"
        error "  make install"
        error "Or set up the complete environment with: make setup"
        exit 1
    fi

    # Update the command to use the determined python
    PYTHON_CMD="$python_cmd"

    completed "Dependencies checked"
}

function check_csv_reports() {
    info "Checking for CSV reports..."

    local csv_found=false

    for pattern in "application_report_*.csv" "executive_summary_*.csv" "migration_priority_*.csv"; do
        if ls "${OUTPUT_DIR}"/"${pattern}" 1> /dev/null 2>&1; then
            csv_found=true
            break
        fi
    done

    if [[ "$csv_found" == "false" ]]; then
        warn "No CSV reports found in ${OUTPUT_DIR}"
        info "Generate CSV reports first:"
        info "  ./scripts/generate.sh"
        return 1
    fi

    completed "CSV reports found"
}

function generate_excel() {
    local excel_script="${SCRIPT_DIR}/generate-excel-template.py"

    if [[ ! -f "$excel_script" ]]; then
        error "Excel generator script not found: $excel_script"
        exit 1
    fi

    info "Generating Excel workbook..."

    local cmd="${PYTHON_CMD:-python3} '$excel_script'"

    # Add options
    cmd+=" --output-dir '$OUTPUT_DIR'"

    if [[ "$TEMPLATE_ONLY" == "true" ]]; then
        cmd+=" --template-only"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        cmd+=" --verbose"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        info "Would execute: $cmd"
        return 0
    fi

    if eval "$cmd"; then
        completed "Excel workbook generated successfully"

        # Show generated files
        info "Generated Excel files:"
        if [[ "$TEMPLATE_ONLY" == "true" ]]; then
            ls -la "${OUTPUT_DIR}"/TKGI_App_Tracker_Template.xlsx 2>/dev/null || true
        else
            ls -la "${OUTPUT_DIR}"/TKGI_App_Tracker_Analysis_*.xlsx 2>/dev/null || true
        fi
    else
        error "Excel generation failed"
        exit 1
    fi
}

function main() {
    info "TKGI Application Tracker - Excel Report Generator"
    info "================================================"

    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN MODE - No files will be modified"
    fi

    # Install dependencies
    install_dependencies

    # Check for CSV reports (unless template-only)
    if [[ "$TEMPLATE_ONLY" == "false" ]]; then
        check_csv_reports
    fi

    # Generate Excel workbook
    generate_excel

    info ""
    info "Excel generation complete!"

    if [[ "$TEMPLATE_ONLY" == "true" ]]; then
        info "Template workbook created. Populate with data and follow"
        info "the 'Pivot Table Instructions' sheet for analysis."
    else
        info "Excel workbook ready for analysis. Open in Excel and:"
        info "  1. Review the Executive Dashboard"
        info "  2. Create pivot tables using the Instructions sheet"
        info "  3. Use Charts & Analysis sheet for visualizations"
        info "  4. Track trends using the Trend Analysis sheet"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--template-only)
            TEMPLATE_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Make output directory absolute
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" 2>/dev/null && pwd || echo "${PWD}/${OUTPUT_DIR}")"

main "$@"
