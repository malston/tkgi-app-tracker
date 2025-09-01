# TKGI Application Tracker

> **Note**: This is a reference implementation demonstrating automated TKGI cluster monitoring and reporting capabilities. The code uses generic datacenter references (DC01, DC02, etc.) and is designed to be adapted for specific enterprise environments.

An automated tracking and reporting system for TKGI (Tanzu Kubernetes Grid Integrated) clusters that helps identify active applications versus those that have migrated to other platforms like OpenShift Container Platform (OCP).

## Overview

This system provides comprehensive visibility into the TKGI application landscape by:

- Collecting metadata from all TKGI clusters across multiple foundations
- Aggregating application data to identify active vs inactive apps
- Generating management reports for migration planning
- Tracking historical trends to monitor migration progress
- Automating weekly report generation via Concourse CI/CD

## Architecture

The TKGI Application Tracker uses a foundation-specific Concourse CI/CD pipeline that automatically collects, processes, and reports on application workloads across TKGI clusters.

### High-Level Flow

```sh
┌─────────────────────┐
│  Concourse Pipeline │ (Weekly Timer - Mon 6:00 AM ET)
└──────────┬──────────┘
           │
    ┌──────▼──────┐
    │   Collect   │──► om CLI → TKGI API → kubectl
    │    Data     │    Foundation-specific collection
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Aggregate  │──► Multi-cluster data processing
    │    Data     │    Migration readiness scoring
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Generate   │──► CSV reports for Excel analysis
    │   Reports   │    JSON data for automation
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Package &  │──► S3 versioned storage
    │   Upload    │    Teams notifications
    └─────────────┘
```

**📖 For detailed pipeline architecture, task flows, and deployment diagrams, see:**

- **[Pipeline Architecture Guide](docs/pipeline-architecture.md)** - Complete technical documentation
- **[Pipeline Flow Diagram](docs/pipeline-flow-diagram.md)** - Visual workflow representation

## Features

### Data Collection

- Automated collection from all TKGI clusters
- Namespace metadata extraction (labels, annotations, creation time)
- Pod counts and deployment status
- Resource utilization metrics
- Service and statefulset inventory

### Application Intelligence

- Automatic AppID extraction from namespace labels/annotations
- System vs application namespace classification
- Active/inactive status determination (30-day activity window)
- Environment classification (production/nonproduction)
- Migration readiness scoring (0-100 scale)

### Reporting Capabilities

- **Application Report**: Detailed app inventory with status and metrics
- **Cluster Report**: Utilization and application distribution by cluster
- **Executive Summary**: High-level metrics for management
- **Migration Priority**: Ranked list of migration candidates
- **Cross-Foundation Aggregation**: Combine all foundation reports into a single Excel workbook

### Data Management

- Weekly snapshot storage with timestamps
- 12-month rolling historical window
- CSV format optimized for Excel analysis
- JSON format for programmatic processing

## Installation

### Prerequisites

- Access to TKGI clusters with kubectl configured
- Concourse CI/CD environment
- Python 3.9+ (for local testing)
- S3 bucket or file storage for reports
- Teams webhook URL for notifications (optional)

### Setup Steps

1. **Clone the repository**

    ```bash
    git clone <repository-url>
    cd tkgi-app-tracker
    ```

1. **Configure cluster access**

    Ensure kubectl contexts are configured for all TKGI clusters:

    ```bash
    kubectl config get-contexts
    ```

    Expected contexts:

    - `dc01-<cluster-name>`
    - `dc02-<cluster-name>`
    - `dc03-<cluster-name>`
    - `dc04-<cluster-name>`
</br>

1. **Set up parameters**

    Create parameter files for each datacenter:

    ```bash
    # Parameter files are named by datacenter and pipeline
    # Examples:
    ~/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml
    ~/git/params/dc02/dc02-k8s-tkgi-app-tracker.yml
    ~/git/params/dc03/dc03-k8s-tkgi-app-tracker.yml
    ~/git/params/dc04/dc04-k8s-tkgi-app-tracker.yml
    ```

1. **Deploy the pipeline**

    ```bash
    ./ci/fly.sh set -f dc01-k8s-n-01    # Deploy for DC01 foundation
    ./ci/fly.sh set -f dc02-k8s-n-01    # Deploy for DC02 foundation
    ./ci/fly.sh set -f dc03-k8s-p-01    # Deploy for DC03 foundation
    ./ci/fly.sh set -f dc04-k8s-p-01    # Deploy for DC04 foundation
    ```

## Usage

### Local Testing with Docker (Recommended)

The TKGI Application Tracker uses Docker containers to provide local testing that mirrors the Concourse production environment:

**Build test environment:**

```bash
make docker-build
```

**Run complete pipeline:**

```bash
make docker-test TASK=full-pipeline FOUNDATION=dc01-k8s-n-01
```

**Test individual tasks:**

```bash
make docker-test TASK=collect-data FOUNDATION=dc01-k8s-n-01
make docker-test TASK=aggregate-data
make docker-test TASK=generate-reports
```

**Interactive development:**

```bash
make docker-dev
```

**Run tests and validation:**

```bash
make docker-test TASK=run-tests
```

See the [Docker Testing Guide](docs/docker-testing-guide.md) for comprehensive testing instructions.

**📖 For comprehensive testing and development documentation, see:**

- **[Docker Testing Guide](docs/docker-testing-guide.md)** - Docker-based local testing and development

### Pipeline Operations

**Trigger manual run:**

```bash
fly -t dc01-k8s-n-01 trigger-job -j tkgi-app-tracker-dc01-k8s-n-01/collect-and-report
```

**Pause/unpause pipeline:**

```bash
fly -t dc01-k8s-n-01 pause-pipeline -p tkgi-app-tracker-dc01-k8s-n-01
fly -t dc01-k8s-n-01 unpause-pipeline -p tkgi-app-tracker-dc01-k8s-n-01
```

**View pipeline status:**

```bash
fly -t dc01-k8s-n-01 pipelines
```

## Report Formats

### Application Report (CSV)

- Application ID
- Active/Inactive status
- Environment (Production/Nonproduction)
- Foundation and cluster locations
- Pod counts and deployment metrics
- Migration readiness score
- Recommendations

### Executive Summary (CSV)

- Total application counts
- Active vs inactive breakdown
- Migration readiness statistics
- Foundation-level summaries

### Migration Priority (CSV)

- Prioritized list of applications
- Migration complexity assessment
- Required actions for each app

## Migration Readiness Scoring

The system calculates a migration readiness score (0-100) based on:

- **Activity Status**: Active apps score lower (need more planning)
- **Size**: Large apps (>10 pods) score lower (more complex)
- **Environment**: Production apps score lower (require careful migration)
- **Services**: Many services indicate complex networking
- **Data Quality**: Missing metadata reduces score

Score interpretation:

- **80-100**: Ready for immediate migration
- **60-79**: Minor planning needed
- **40-59**: Significant planning required
- **0-39**: Complex migration, detailed analysis needed

**📖 For detailed migration readiness scoring methodology and business value analysis, see:**

- **[Migration Readiness Guide](docs/migration-readiness-guide.md)** - Comprehensive guide covering:
  - Detailed scoring algorithm and methodology
  - Business impact assessment by score category
  - Executive and operational benefits
  - Sample outputs and analysis examples
  - Custom scoring models and integration opportunities

## Directory Structure

```sh
tkgi-app-tracker/
├── scripts/                     # Core data collection and processing
│   ├── collect-tkgi-cluster-data.sh      # Single foundation/cluster collection
│   ├── collect-all-tkgi-clusters.sh      # Multi-cluster collection for foundation
│   ├── aggregate-data.py                 # Data aggregation and analysis
│   ├── generate-reports.py               # Report generation (CSV/JSON)
│   ├── foundation-utils.sh               # Foundation parsing utilities
│   └── helpers.sh                        # Common helper functions
├── ci/                          # Concourse pipeline configuration
│   ├── pipelines/
│   │   ├── single-foundation-report.yml                 # Main Concourse pipeline configuration
│   │   └── cross-foundation-report.yml  # Cross-foundation pipeline
│   ├── fly.sh                           # Pipeline deployment script
│   └── tasks/                           # Individual pipeline tasks (ns-mgmt convention)
│       ├── collect-data/                # Data collection task
│       │   ├── task.yml                 # Task definition
│       │   └── task.sh                  # Task implementation
│       ├── aggregate-data/              # Data aggregation task
│       ├── generate-reports/            # Report generation task
│       ├── package-reports/             # Report packaging task
│       ├── notify/                      # Notification task
│       ├── run-tests/                   # Unit testing task
│       └── validate-scripts/            # Script validation task
├── data/                        # Raw collected data (git-ignored)
├── reports/                     # Generated reports (git-ignored)
├── config/                      # Configuration templates
├── tests/                       # Test scripts and test data
└── docs/                        # Additional documentation
    ├── pipeline-architecture.md         # Complete pipeline technical docs
    ├── pipeline-flow-diagram.md         # Visual workflow diagrams
    └── deployment-guide.md              # Step-by-step deployment guide
```

## Troubleshooting

### Common Issues

**No cluster access:**

```bash
# Verify kubectl context
kubectl config current-context
kubectl get namespaces
```

**Pipeline fails to deploy:**

```bash
# Check Concourse login
fly -t {foundation} status
# Validate pipeline YAML
fly validate-pipeline -c ci/pipelines/single-foundation-report.yml
```

**Data collection errors:**

```bash
# View recent builds
fly -t {foundation} builds -j tkgi-app-tracker-{foundation}/collect-and-report
# Watch live build output
fly -t {foundation} watch -j tkgi-app-tracker-{foundation}/collect-and-report
# Access failed build container for debugging
fly -t {foundation} hijack -b {build-number}
# Check for JSON validity
jq empty data/cluster_data_*.json
```

## Documentation

### Pipeline Documentation

- **[Pipeline Architecture Guide](docs/pipeline-architecture.md)** - Complete technical documentation covering:
  - Detailed task flows and authentication processes
  - Data collection schemas and processing logic
  - Error handling and notification strategies
  - Performance characteristics and resource requirements
  - Security model and monitoring approach

- **[Pipeline Flow Diagram](docs/pipeline-flow-diagram.md)** - Comprehensive visual workflow including:
  - Complete pipeline execution flow
  - Task-by-task breakdown with durations
  - Parallel job execution (collect-and-report, test-pipeline)
  - Error handling and notification paths
  - Deployment architecture across datacenters

- **[Deployment Guide](docs/deployment-guide.md)** - Step-by-step deployment instructions for all environments

### Analysis and Reporting Documentation

- **[Cross-Foundation Aggregation](docs/cross-foundation-README.md)** - Combine reports from multiple foundations into a single Excel workbook:
  - Automated collection from S3 storage
  - Cross-foundation data consolidation
  - Unified Excel workbook generation
  - Enterprise-wide visibility

- **[Inactivity Detection Guide](docs/inactivity-detection.md)** - Detailed explanation of how applications are determined to be active or inactive:
  - Data collection methodology (pod start times)
  - 30-day activity window calculation
  - Limitations and edge cases
  - Future enhancement possibilities

- **[Migration Readiness Guide](docs/migration-readiness-guide.md)** - Understanding application migration scores

- **[Excel Report Guide](docs/excel-report-guide.md)** - How to use generated Excel reports for analysis

### Key Pipeline Features

- **Foundation-Specific Deployment**: Each foundation gets one pipeline with two jobs (collect-and-report, test-pipeline)
- **Manual Trigger Support**: Uses manual-trigger resource pattern for on-demand execution without job duplication
- **Automated Authentication**: om CLI → TKGI API → kubectl credential chain
- **Multi-Format Reporting**: CSV for Excel analysis, JSON for automation
- **Comprehensive Error Handling**: Task-level failure notifications with Teams integration
- **S3 Versioned Storage**: 12-month retention with organized foundation-specific paths

## Contributing

1. Create feature branch from `main`
2. Make changes and test locally
3. Ensure all scripts are executable
4. Update documentation as needed
5. Submit pull request

## Security Considerations

- Uses read-only kubectl commands
- No modification of cluster resources
- Credentials stored securely in Concourse
- Reports contain no sensitive data
- Access controlled via S3 permissions

## Support

For issues or questions:

- Create an issue in the repository
- Contact the Platform Engineering team
- Check the docs/ directory for additional guides
