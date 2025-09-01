#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Retrieving latest foundation reports from S3..."

# Source helper functions
# shellcheck disable=SC1091
source tkgi-app-tracker-repo/scripts/helpers.sh

# Set defaults
FOUNDATIONS="${FOUNDATIONS:-dc01,dc02,dc03,dc04}"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-7}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.amazonaws.com}"
S3_BUCKET="${S3_BUCKET:-reports}"

# Install MinIO client if not present
if ! command -v mc &> /dev/null; then
    info "Installing MinIO client..."
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
fi

# Configure MinIO client alias for S3
MC_ALIAS="s3-app-tracker"
info "Configuring MinIO client for S3 access..."

# Set up MinIO client configuration
mc alias set "${MC_ALIAS}" \
    "${S3_ENDPOINT}" \
    "${S3_ACCESS_KEY_ID}" \
    "${S3_SECRET_ACCESS_KEY}" \
    --api S3v4 >/dev/null 2>&1

# Create output directory
mkdir -p foundation-reports/data

# Convert comma-separated foundations to array
IFS=',' read -r -a foundation_array <<< "$FOUNDATIONS"

info "Searching for latest reports from foundations: ${FOUNDATIONS}"
info "Looking for reports newer than ${MAX_AGE_DAYS} days"

# Calculate date threshold (MAX_AGE_DAYS ago)
if command -v date >/dev/null 2>&1; then
    # Try GNU date first (Linux)
    if date --version >/dev/null 2>&1; then
        threshold_date=$(date -d "${MAX_AGE_DAYS} days ago" '+%Y-%m-%d')
    else
        # BSD date (macOS)
        threshold_date=$(date -v-"${MAX_AGE_DAYS}"d '+%Y-%m-%d')
    fi
else
    # Fallback - just use current date minus a reasonable buffer
    threshold_date=$(date '+%Y-%m-%d')
fi

info "Date threshold: ${threshold_date}"

# Function to get latest report for a foundation
function get_latest_foundation_report() {
    local foundation=$1
    local foundation_prefix="app-tracker-reports/${foundation}/"
    local mc_path="${MC_ALIAS}/${S3_BUCKET}/${foundation_prefix}"

    info "Searching for reports in: ${mc_path}"

    # List all tar.gz files for this foundation, sorted by date
    # MinIO client outputs: [date] [time] [size] [name]
    local latest_report
    if ! latest_report=$(mc ls "${mc_path}" --recursive 2>/dev/null \
        | grep "weekly-report-.*\.tar\.gz$" \
        | sort -k1,2 \
        | tail -1 \
        | awk '{print $NF}'); then
        warn "Failed to list reports for foundation: ${foundation}"
        return 1
    fi

    if [[ -z "${latest_report}" ]]; then
        warn "No reports found for foundation: ${foundation}"
        return 1
    fi

    info "Found latest report for ${foundation}: ${latest_report}"

    # Extract timestamp from filename to check age
    local timestamp
    if timestamp=$(echo "${latest_report}" | grep -o '[0-9]\{8\}_[0-9]\{6\}'); then
        local report_date
        report_date=$(echo "${timestamp}" | cut -d'_' -f1)
        local formatted_date="${report_date:0:4}-${report_date:4:2}-${report_date:6:2}"

        # Simple date comparison (works if format is YYYY-MM-DD)
        if [[ "${formatted_date}" < "${threshold_date}" ]]; then
            warn "Report for ${foundation} is older than ${MAX_AGE_DAYS} days (${formatted_date})"
            info "Skipping outdated report: ${latest_report}"
            return 1
        fi

        info "Report for ${foundation} is recent (${formatted_date})"
    else
        warn "Could not extract timestamp from filename: ${latest_report}"
    fi

    # Download the latest report
    local local_file="foundation-reports/data/${foundation}_latest.tar.gz"
    local remote_file="${mc_path}${latest_report}"

    if mc cp "${remote_file}" "${local_file}" 2>/dev/null; then
        info "Downloaded: ${latest_report} -> ${local_file}"

        # Extract the tar.gz file
        local extract_dir="foundation-reports/data/${foundation}"
        mkdir -p "${extract_dir}"

        if tar -xzf "${local_file}" -C "${extract_dir}" --strip-components=1; then
            info "Extracted ${foundation} report to: ${extract_dir}"
            rm "${local_file}"  # Clean up the tar file
            return 0
        else
            error "Failed to extract: ${local_file}"
            return 1
        fi
    else
        error "Failed to download: ${latest_report}"
        return 1
    fi
}

# Track successful downloads
successful_foundations=()
failed_foundations=()

# Process each foundation
for foundation in "${foundation_array[@]}"; do
    info "Processing foundation: ${foundation}"

    if get_latest_foundation_report "${foundation}"; then
        successful_foundations+=("${foundation}")
    else
        failed_foundations+=("${foundation}")
    fi

    echo ""  # Add spacing between foundations
done

# Summary
echo "========================================="
info "Foundation Report Retrieval Summary"
echo "========================================="

if [[ ${#successful_foundations[@]} -gt 0 ]]; then
    info "Successfully retrieved reports from ${#successful_foundations[@]} foundations:"
    for foundation in "${successful_foundations[@]}"; do
        info "  ✓ ${foundation}"
        # List CSV files found
        csv_count=$(find "foundation-reports/data/${foundation}" -name "*.csv" 2>/dev/null | wc -l)
        info "    - CSV files found: ${csv_count}"
    done
fi

if [[ ${#failed_foundations[@]} -gt 0 ]]; then
    warn "Failed to retrieve reports from ${#failed_foundations[@]} foundations:"
    for foundation in "${failed_foundations[@]}"; do
        warn "  ✗ ${foundation}"
    done
fi

# Ensure we have at least one successful download
if [[ ${#successful_foundations[@]} -eq 0 ]]; then
    error "No foundation reports were successfully retrieved"
    exit 1
fi

# Create a summary file for the next task
cat > foundation-reports/retrieval-summary.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "successful_foundations": [$(printf '"%s",' "${successful_foundations[@]}" | sed 's/,$//')],
  "failed_foundations": [$(printf '"%s",' "${failed_foundations[@]}" | sed 's/,$//')],
  "total_successful": ${#successful_foundations[@]},
  "total_failed": ${#failed_foundations[@]},
  "threshold_date": "${threshold_date}",
  "max_age_days": ${MAX_AGE_DAYS}
}
EOF

info "Retrieval summary saved to: foundation-reports/retrieval-summary.json"

# Show final directory structure
echo ""
info "Final directory structure:"
find foundation-reports -type f -name "*.csv" | head -20 || true
if [[ $(find foundation-reports -type f -name "*.csv" | wc -l) -gt 20 ]]; then
    info "... and $(( $(find foundation-reports -type f -name "*.csv" | wc -l) - 20 )) more CSV files"
fi

echo ""
completed "Foundation report retrieval completed successfully"
echo "Retrieved data from ${#successful_foundations[@]} foundation(s)"
