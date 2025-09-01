# Cross-Foundation Data Aggregation

This directory contains the pipeline components for aggregating TKGI application data across multiple foundations into a single Excel workbook.

## Quick Start

```bash
# Deploy the pipeline using fly.sh
./ci/fly.sh cross-foundation

# Deploy with specific target and team
./ci/fly.sh cross-foundation -f dc01-k8s-n-01

# Unpause and trigger
fly -t tkgi unpause-pipeline -p cross-foundation-report
fly -t tkgi trigger-job -j cross-foundation-report/aggregate-cross-foundation-data
```

## Components

- **`ci/pipelines/cross-foundation-report.yml`** - Main pipeline definition
- **`../params/cross-foundation.yml`** - Cross-foundation specific parameters
- **`ci/fly.sh cross-foundation`** - Deployment command (integrated into main fly.sh)
- **`ci/tasks/retrieve-foundation-reports/`** - S3 data retrieval task using MinIO CLI
- **`ci/tasks/generate-cross-foundation-excel/`** - Excel generation task

## Output

Generates `TKGI_App_Tracker_Analysis_{timestamp}.xlsx` containing:

- Combined application data from all foundations
- Cross-foundation executive summary
- Migration priority rankings
- Cluster utilization overview

## Configuration

The pipeline uses the same global parameters as regular pipelines (global.yml, k8s-global.yml) plus cross-foundation specific settings.

Edit `../params/cross-foundation.yml` to customize:

- `cross_foundation_list`: Foundations to aggregate (default: dc01,dc02,dc03,dc04)
- `cross_foundation_schedule`: Execution frequency (default: 24h)
- `cross_foundation_max_age_days`: Data freshness window (default: 7 days)
- `cross_foundation_include_charts`: Excel chart generation (default: true)

## Documentation

See [docs/cross-foundation-report.md](../docs/cross-foundation-report.md) for detailed documentation.
