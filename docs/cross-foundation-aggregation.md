# Cross-Foundation Data Aggregation

## Overview

The cross-foundation aggregation pipeline combines application tracking data from multiple foundations (DC01, DC02, DC03, DC04) into a single, comprehensive Excel workbook. This provides enterprise-wide visibility into TKGI applications across all environments.

## Architecture

```sh
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Foundation    │    │   Foundation     │    │   Foundation        │
│   Reports (S3)  │    │   Reports (S3)   │    │   Reports (S3)      │
│                 │    │                  │    │                     │
│ ├─ dc01/        │    │ ├─ dc02/         │    │ ├─ dc03/            │
│ ├─ weekly-*.gz  │    │ ├─ weekly-*.gz   │    │ ├─ weekly-*.gz      │
│ └─ latest       │    │ └─ latest        │    │ └─ latest           │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
              ┌──────────────────────────────────┐
              │   Cross-Foundation Pipeline      │
              │                                  │
              │ 1. Retrieve Latest Reports       │
              │ 2. Consolidate Data              │
              │ 3. Generate Excel Workbook       │
              │ 4. Upload to S3                  │
              └──────────────────────────────────┘
                                 │
                ┌─────────────────────────────────────┐
                │ TKGI_App_Tracker_Analysis_{ts}.xlsx │
                │                                     │
                │ • Combined Applications Data        │
                │ • Cross-Foundation Summary          │
                │ • Migration Priority Rankings       │
                │ • Cluster Utilization Overview      │
                │ • Charts and Visualizations         │
                └─────────────────────────────────────┘
```

## Pipeline Components

### 1. Data Retrieval Task

**File**: `ci/tasks/retrieve-foundation-reports/`

- Downloads the most recent weekly reports from each foundation's S3 bucket
- Filters reports by age (default: 7 days) to ensure fresh data
- Extracts tar.gz archives into structured directories
- Creates retrieval summary for downstream tasks

**Key Features:**

- Age-based filtering to avoid stale data
- Graceful handling of missing foundations
- Comprehensive error reporting
- Cross-platform date handling

### 2. Data Consolidation Script

**File**: `scripts/aggregate-cross-foundation.py`

- Combines CSV reports from multiple foundations into unified datasets
- Generates cross-foundation executive summary
- Maintains data quality indicators
- Handles missing or incomplete data gracefully

**Consolidated Outputs:**

- `consolidated_applications_{timestamp}.csv` - All applications across foundations
- `consolidated_clusters_{timestamp}.csv` - All cluster information
- `consolidated_migration_priority_{timestamp}.csv` - Migration candidates ranking
- `consolidated_executive_summary_{timestamp}.csv` - Cross-foundation metrics
- `consolidation_metadata_{timestamp}.json` - Process metadata

### 3. Excel Generation Task

**File**: `ci/tasks/generate-cross-foundation-excel/`

- Creates comprehensive Excel workbook with multiple worksheets
- Includes charts and visualizations (configurable)
- Uses the existing `generate-excel-template.py` script
- Generates timestamped workbook names

**Excel Workbook Structure:**

- **Executive Summary** - High-level cross-foundation metrics
- **Applications** - Detailed application inventory
- **Migration Priority** - Applications ranked for migration readiness
- **Clusters** - Infrastructure utilization overview
- **Charts** - Visual representations (optional)

### 4. Pipeline Orchestration

**File**: `ci/pipelines/cross-foundation-report.yml`

- Scheduled execution (default: daily)
- Sequential task execution with proper dependencies
- S3 artifact management
- Error handling and retry logic

## Configuration

### Pipeline Parameters

The cross-foundation pipeline leverages the same parameters as the regular foundation pipelines, plus some specific settings.

**Shared Parameters (from global.yml, k8s-global.yml):**

- Git configuration (`git_uri`, `git_release_tag`, `git_private_key`)
- S3 configuration (`s3_bucket`, `concourse_sgs3_access_key_id`, `concourse_sgs3_secret_access_key`)
- Concourse settings

**Cross-Foundation Specific Parameters (from cross-foundation.yml):**

```yaml
# Cross-Foundation Specific Parameters
# These supplement the standard global params

# Cross-foundation specific settings
cross_foundation_list: "dc01,dc02,dc03,dc04"  # Comma-separated list of foundations to aggregate
cross_foundation_schedule: "24h"              # How often to run aggregation (daily)
cross_foundation_max_age_days: "7"            # Only include reports newer than this
cross_foundation_include_charts: "true"       # Include charts in Excel workbook
```

### Environment Variables

The pipeline uses the same parameter placeholders as regular pipelines:

- `((git_uri))` - Git repository URL
- `((git_private_key))` - SSH private key for git access
- `((concourse_sgs3_access_key_id))` - S3 access key ID
- `((concourse_sgs3_secret_access_key))` - S3 secret access key
- `((concourse-sgs3-endpoint))` - S3 endpoint
- `((s3_bucket))` - S3 bucket for reports

## Deployment

### Prerequisites

1. **Concourse CI/CD**: Pipeline requires Concourse for orchestration
2. **S3 Access**: Read access to foundation report buckets, write access to output bucket
3. **Python Dependencies**: pandas, openpyxl (installed automatically)
4. **Git Access**: Repository access for pipeline definition

### Deploy Pipeline

```bash
# Deploy with defaults
./ci/fly.sh cross-foundation

# Deploy to specific target and team
./ci/fly.sh cross-foundation -t tkgi-reports

# Deploy with dry-run to preview
./ci/fly.sh cross-foundation --dry-run

# Unpause the pipeline
fly -t tkgi unpause-pipeline -p cross-foundation-report

# Trigger manually
fly -t tkgi trigger-job -j cross-foundation-report/aggregate-cross-foundation-data
```

## Usage

### Automated Execution

The pipeline runs automatically on the configured schedule (default: daily at midnight UTC). It will:

1. Check for new foundation reports (within the last 7 days)
2. Download and consolidate data from available foundations
3. Generate the Excel workbook with all available data
4. Upload to S3 with timestamped filename

### Manual Execution

```bash
# Trigger immediate execution
fly -t tkgi trigger-job -j cross-foundation-report/aggregate-cross-foundation-data

# Watch execution progress
fly -t tkgi watch -j cross-foundation-report/aggregate-cross-foundation-data
```

### Local Testing

```bash
# Test data retrieval
./ci/tasks/retrieve-latest-foundation-reports/task.sh

# Test data consolidation
python3 scripts/aggregate-cross-foundation.py foundation-reports/data

# Test Excel generation
python3 scripts/generate-excel-template.py \
  -o test-output.xlsx \
  --applications consolidated_applications.csv \
  --executive-summary consolidated_executive_summary.csv \
  --include-charts
```

## Output Files

### Excel Workbook

**Format**: `TKGI_App_Tracker_Analysis_{YYYYMMDD_HHMMSS}.xlsx`

**Location**: S3 bucket specified in pipeline configuration

**Contents**:

- Multiple worksheets with cross-foundation data
- Interactive charts and pivot tables (if enabled)
- Executive summary with key metrics
- Detailed application inventory
- Migration readiness rankings

### Archive

**Format**: `cross-foundation-archive_{YYYYMMDD_HHMMSS}.tar.gz`

**Contents**:

- All consolidated CSV files
- Excel workbook
- Generation metadata
- Processing logs

## Data Quality

### Validation Checks

The consolidation process includes several data quality validations:

1. **Timestamp Validation**: Ensures reports are within the acceptable age range
2. **Schema Validation**: Verifies CSV files contain expected columns
3. **Data Completeness**: Tracks missing or incomplete data
4. **Cross-Foundation Consistency**: Identifies data format inconsistencies

### Quality Indicators

Each consolidated dataset includes quality metadata:

- `data_quality` field indicating completeness
- Foundation-specific statistics
- Processing timestamps
- Source file references

## Troubleshooting

### Common Issues

#### Pipeline Fails with "No foundation reports found"

- Check S3 permissions for source buckets
- Verify foundation names in configuration match S3 structure
- Ensure reports exist within the `max_age_days` window

#### Excel Generation Fails

- Verify dependencies are installed: `pip3 install -r requirements.txt`
- Check consolidated CSV files are present and valid
- Review task logs for Python errors

#### Empty or Partial Data

- Check individual foundation pipelines are running successfully
- Verify S3 upload process is completing
- Review foundation-specific error logs

### Debugging

```bash
# Check pipeline status
fly -t tkgi pipelines | grep cross-foundation

# View recent build logs
fly -t tkgi builds -p cross-foundation-report

# Download build artifacts
fly -t tkgi download-cli-binary -j cross-foundation-report/aggregate-cross-foundation-data
```

### Log Analysis

Key log messages to monitor:

- "Successfully retrieved reports from X foundations"
- "Combined total: X applications across Y foundations"
- "Excel workbook generated successfully"
- Data quality warnings for incomplete data

## Monitoring and Alerts

### Key Metrics

Monitor these metrics for pipeline health:

- **Success Rate**: Percentage of successful pipeline executions
- **Data Freshness**: Age of the most recent foundation data processed
- **Foundation Coverage**: Number of foundations successfully processed
- **Processing Time**: Duration of each pipeline execution

### Recommended Alerts

1. **Pipeline Failure**: Alert if pipeline fails 2 consecutive times
2. **Stale Data**: Alert if no new data processed for 48 hours
3. **Foundation Outage**: Alert if a foundation consistently fails data retrieval
4. **Data Volume**: Alert on significant changes in application counts

## Integration

### Downstream Systems

The generated Excel workbooks can be:

- Downloaded directly from S3 for manual analysis
- Integrated into business intelligence dashboards
- Used for executive reporting and presentations
- Processed by additional automation for notifications

### API Access

Consider developing REST API endpoints for:

- Pipeline status and metrics
- Latest workbook download URLs
- Foundation-specific data queries
- Historical trend analysis

## Security

### Access Control

- S3 buckets use IAM policies for least-privilege access
- Pipeline service accounts have read-only access to source data
- Generated workbooks may contain sensitive application information

### Data Handling

- All data processing occurs within secure pipeline environment
- Temporary files are cleaned up after processing
- S3 transfers use encryption in transit
- Consider enabling S3 bucket encryption for stored reports

## Future Enhancements

### Planned Improvements

1. **Real-time Aggregation**: Move from batch to near real-time processing
2. **Historical Trending**: Track changes in application states over time
3. **Advanced Analytics**: Include predictive migration recommendations
4. **Custom Dashboards**: Web-based interactive dashboards
5. **Automated Notifications**: Email/Slack alerts for significant changes

### Extensibility

The pipeline architecture supports:

- Additional foundation environments
- Custom data sources beyond TKGI clusters
- Alternative output formats (PowerBI, Tableau)
- Integration with CMDB and ITSM systems

## Related Documentation

- [Pipeline Architecture](./pipeline-architecture.md) - Overall system design
- [Excel Report Guide](./excel-report-guide.md) - Excel workbook structure
- [Migration Readiness Guide](./migration-readiness-guide.md) - Migration scoring algorithm
- [Inactivity Detection](./inactivity-detection.md) - Application activity classification
