#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Starting TKGI cluster data collection..."

# Install required tools
if ! command -v jq &>/dev/null; then
  apt-get update && apt-get install -y jq
fi

if ! command -v om &>/dev/null; then
  wget -O om https://github.com/pivotal-cf/om/releases/download/7.16.2/om-linux-amd64-7.16.2
  chmod +x om
  mv om /usr/local/bin/
fi

# Change to scripts directory and run collection
cd tkgi-app-tracker-repo/scripts
chmod +x ./*.sh

# Create output directory (relative to working directory)
mkdir -p ../../collected-data/data

# Run collection for the specific foundation
echo "Collecting from foundation: ${FOUNDATION}"
# Enable testing mode for Docker environment

./collect-all-tkgi-clusters.sh -f "${FOUNDATION}" -o ../../collected-data/data

# Validate output (back to working directory)
cd ../../
if ! ls collected-data/data/all_clusters_*.json >/dev/null 2>&1; then
  echo "Error: No data collected"
  exit 1
fi

echo "Data collection completed successfully"
ls -la collected-data/data/