#!/bin/sh

set -e

echo "Packaging reports..."

# Create timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create archive with environment prefix
cd generated-reports
tar -czf ../packaged-reports/weekly-report-"${ENVIRONMENT}"-"${TIMESTAMP}".tar.gz reports/

echo "Reports packaged successfully for environment: ${ENVIRONMENT}"
ls -la ../packaged-reports/