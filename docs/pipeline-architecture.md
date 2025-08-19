# TKGI Application Tracker Pipeline Architecture

## Overview

The TKGI Application Tracker pipeline is designed to automatically collect, aggregate, and report on application workloads across all TKGI clusters within a datacenter. The pipeline follows organizational standards for Concourse CI/CD automation and integrates with existing authentication and storage systems.

## Pipeline Architecture

### High-Level Flow

```sh
┌─────────────────────┐
│  Weekly Timer       │ ◄── Triggers every Monday at 6:00 AM ET
└──────────┬──────────┘
           │
    ┌──────▼──────┐
    │   Collect   │──► Authentication via om CLI
    │    Data     │    TKGI API cluster discovery
    └──────┬──────┘    kubectl namespace queries
           │
    ┌──────▼──────┐
    │  Aggregate  │──► Combine multi-cluster data
    │    Data     │    Calculate metrics & scores
    └──────┬──────┘    Classify applications
           │
    ┌──────▼──────┐
    │  Generate   │──► CSV reports for Excel
    │   Reports   │    JSON data for automation
    └──────┬──────┘    Executive summaries
           │
    ┌──────▼──────┐
    │  Package    │──► Compress reports with timestamp
    │   Reports   │    Foundation-specific naming
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │   Upload    │──► S3 bucket storage
    │  to S3      │    Versioned archives
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │   Notify    │──► Teams webhook notification
    │   Success   │    Report availability alert
    └─────────────┘
```

## Pipeline Structure

The TKGI Application Tracker uses a **single Concourse pipeline** (`pipeline.yml`) deployed per foundation with **two jobs** for different execution scenarios.

## Pipeline Jobs

### 1. collect-and-report (Primary Job)

**Triggers**:

- Weekly timer (Monday 6:00 AM ET) - automatic execution
- Manual trigger via `fly trigger-job` - on-demand execution
**Duration**: ~15-30 minutes depending on cluster count

**Manual Execution**: Uses manual-trigger resource pattern for on-demand runs without job duplication

#### Task Flow

```sh
┌─────────────────────────────────────────────────────────────────┐
│                        collect-and-report                       │
├─────────────────────────────────────────────────────────────────┤
│ Inputs:                                                         │
│ • s3-container-image (runtime environment)                      │
│ • tkgi-app-tracker-repo (source code)                           │
│ • config-repo (foundation configurations)                       │
│ • weekly-timer (trigger)                                        │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐                                             │
│ │ collect-data    │ ◄── Foundation-specific collection          │
│ │                 │     • om CLI → TKGI admin password          │
│ │ Duration: 5-10m │     • tkgi CLI → cluster discovery          │
│ │                 │     • kubectl → namespace enumeration       │
│ └─────────┬───────┘     • Pod/service/deployment counts         │
│           │                                                     │
│ ┌─────────▼───────┐                                             │
│ │ aggregate-data  │ ◄── Multi-cluster data processing           │
│ │                 │     • JSON data consolidation               │
│ │ Duration: 2-5m  │     • Application classification            │
│ │                 │     • Migration readiness scoring           │
│ └─────────┬───────┘     • Historical trend analysis             │
│           │                                                     │
│ ┌─────────▼───────┐                                             │
│ │ generate-reports│ ◄── Report generation                       │
│ │                 │     • CSV files for Excel analysis          │
│ │ Duration: 1-3m  │     • JSON files for automation             │
│ │                 │     • Executive summary statistics          │
│ └─────────┬───────┘     • Migration priority rankings           │
│           │                                                     │
│ ┌─────────▼───────┐                                             │
│ │ package-reports │ ◄── Archive preparation                     │
│ │                 │     • Timestamp-based naming                │
│ │ Duration: <1m   │     • Compression (tar.gz)                  │
│ │                 │     • Foundation identification             │
│ └─────────┬───────┘                                             │
│           │                                                     │
│ ┌─────────▼───────┐     ┌─────────────────┐                     │
│ │ upload-to-s3    │────▶│ S3 Storage      │                     │
│ │                 │     │ Foundation/     │                     │
│ │ Duration: <1m   │     │ weekly-report-  │                     │
│ │                 │     │ TIMESTAMP.tgz   │                     │
│ └─────────┬───────┘     └─────────────────┘                     │
│           │                                                     │
│ ┌─────────▼───────┐     ┌─────────────────┐                     │
│ │ notify-success  │────▶│ Teams Channel   │                     │
│ │                 │     │ Success Alert   │                     │
│ │ Duration: <1m   │     │ S3 URL          │                     │
│ └─────────────────┘     └─────────────────┘                     │
│                                                                 │
│ Error Handling: Each task has on_failure notification           │
└─────────────────────────────────────────────────────────────────┘
```

### 2. test-pipeline (Validation Job)

**Trigger**: Git repository changes
**Purpose**: Code quality validation and continuous integration

```sh
┌─────────────────────────────────────────────────────────────────┐
│                          test-pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│ Inputs:                                                         │
│ • s3-container-image (runtime environment)                      │
│ • tkgi-app-tracker-repo (source code) [trigger]                 │
│ • config-repo (foundation configurations)                       │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐                                             │
│ │ run-unit-tests  │ ◄── BATS test execution                     │
│ │                 │     • Shell script validation               │
│ │ Duration: 2-5m  │     • Logic verification                    │
│ │                 │     • Mock data testing                     │
│ └─────────┬───────┘                                             │
│           │                                                     │
│ ┌─────────▼───────┐                                             │
│ │ validate-scripts│ ◄── Static analysis                         │
│ │                 │     • Bash syntax checking                  │
│ │ Duration: 1-2m  │     • Python syntax validation              │
│ │                 │     • YAML validation                       │
│ │                 │     • Shellcheck linting                    │
│ └─────────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Task Details

### collect-data Task

**Purpose**: Discover TKGI clusters and extract namespace metadata from all clusters within a foundation

**Container**: s3-container-image (cflinux-based)
**Tools**: om CLI, tkgi CLI, kubectl, jq, curl

**What it does**:

1. **Authenticates to Ops Manager** using OAuth2 client credentials
2. **Retrieves TKGI admin password** from Ops Manager credentials store
3. **Logs into TKGI API** using admin credentials to get cluster access
4. **Discovers all clusters** in the foundation via TKGI API
5. **For each cluster**, gets kubectl credentials and queries:
   - All namespaces with metadata (labels, annotations, creation timestamps)
   - All pods across namespaces (to determine activity and resource usage)
   - All services across namespaces (to identify application complexity)
   - All deployments across namespaces (to understand application structure)
6. **Processes and enriches data** by:
   - Extracting AppID from namespace labels/annotations
   - Classifying system vs application namespaces
   - Determining activity status based on recent pod creation
   - Associating with foundation/datacenter/environment context
7. **Outputs structured JSON** containing all namespace data for aggregation
8. **Enriches data with config repository information** to identify configuration drift and missing metadata

#### Authentication Flow

```sh
1. Environment Setup
   ├── OM_TARGET
   ├── OM_CLIENT_ID
   └── OM_CLIENT_SECRET

2. om CLI Authentication
   └── om -t ${OM_TARGET} -c ${CLIENT_ID} -s ${CLIENT_SECRET}

3. TKGI Password Retrieval
   └── om credentials -p pivotal-container-service -c '.properties.uaa_admin_password'

4. TKGI API Login
   └── tkgi login -a ${TKGI_API_ENDPOINT} -u admin -p ${ADMIN_PASSWORD}

5. Cluster Discovery
   └── tkgi clusters --json

6. Per-Cluster Data Collection
   ├── tkgi get-credentials ${CLUSTER_NAME}
   ├── kubectl get namespaces --output=json
   ├── kubectl get pods --all-namespaces --output=json
   ├── kubectl get services --all-namespaces --output=json
   └── kubectl get deployments --all-namespaces --output=json
```

#### Data Collection Schema

```json
{
  "namespace": "app-namespace-123",
  "cluster": "cluster-name",
  "foundation": "dc01-k8s-n-01",
  "datacenter": "dc01",
  "environment": "lab",
  "creation_timestamp": "2024-01-15T10:30:00Z",
  "labels": {
    "app-id": "app-12345",
    "team": "platform-engineering"
  },
  "annotations": {
    "migration.platform/ready": "true"
  },
  "pod_count": 15,
  "service_count": 3,
  "deployment_count": 2,
  "statefulset_count": 1,
  "is_system": false,
  "is_active": true,
  "last_activity": "2024-01-15T09:45:00Z"
}
```

#### Config Repository Enrichment Process

The collect-data task also enriches the actual cluster data with configuration repository information to provide insights into configuration drift and missing metadata:

```bash
# 1. Config Repository Validation
CONFIG_REPO_PATH="${CONFIG_REPO_PATH:-${HOME}/git/config-lab}"
validate_config_repo "${CONFIG_REPO_PATH}"

# 2. Load Foundation Configuration
foundation_config=$(get_foundation_config "${CONFIG_REPO_PATH}" "${foundation}")

# 3. Extract Namespace Configurations
# For each cluster in foundation:
cluster_config_namespaces=$(get_namespace_configs "${CONFIG_REPO_PATH}" "${foundation}" "${cluster}")

# 4. Enrich Actual Data with Config Data
enriched_data=$(enrich_with_config "${actual_namespaces}" "${config_namespaces}")

# 5. Generate Configuration Drift Report
generate_config_comparison_report "${enriched_data}" "${comparison_file}"
```

#### Config-Enriched Data Schema

After config enrichment, each namespace record includes additional fields:

```json
{
  "namespace": "app-namespace-123",
  "cluster": "cluster-name",
  "foundation": "dc01-k8s-n-01",
  "app_id": "app-12345",

  // Configuration enrichment fields
  "configured_app_id": "app-12345",
  "configured_app_guid": "c966d6b01b191590c0d6eb9ee54bcb0f",
  "configured_environment": "TEST",
  "config_source": "/path/to/config-lab/foundations/dc01-k8s-n-01/cluster01/app-namespace-123/nameSpaceInfo.yml",
  "has_config": true,
  "app_id_matches": true,
  "config_metadata": {
    "labels": {
      "app_id": "app-12345",
      "app_guid": "c966d6b01b191590c0d6eb9ee54bcb0f",
      "data_classfication": "01",
      "au": "0244268",
      "environment": "TEST"
    },
    "requestscpu": "4",
    "limitscpu": "20",
    "usergroups": ["PRV_ECS_SA_SRV_CF_SUPPORT"]
  }
}
```

#### Configuration Drift Analysis

The system generates a configuration comparison report identifying:

```json
{
  "summary": {
    "total_namespaces": 150,
    "namespaces_with_config": 120,
    "namespaces_without_config": 30,
    "app_id_matches": 100,
    "app_id_mismatches": 20,
    "app_id_unknown": 30
  },
  "missing_configs": [
    {
      "foundation": "dc01-k8s-n-01",
      "cluster": "cluster01",
      "namespace": "undocumented-app",
      "app_id": "app-99999"
    }
  ],
  "app_id_drift": [
    {
      "foundation": "dc01-k8s-n-01",
      "cluster": "cluster01",
      "namespace": "migrated-app",
      "actual_app_id": "app-55555",
      "configured_app_id": "app-12345",
      "config_source": "/path/to/nameSpaceInfo.yml"
    }
  ]
}
```

### aggregate-data Task

**Purpose**: Process and analyze collected namespace data to generate application intelligence and migration readiness metrics

**Container**: s3-container-image (Python 3.9+)
**Tools**: Python, pandas, json

**What it does**:

1. **Loads and consolidates JSON data** from all clusters within the foundation
2. **Validates data integrity** by checking schema compliance and identifying corrupt records
3. **Merges datasets** by removing duplicates and resolving conflicts between multiple data sources
4. **Classifies applications** by distinguishing system namespaces from actual applications
5. **Calculates migration readiness scores** using a weighted scoring algorithm (0-100 scale)
6. **Performs historical analysis** by comparing with previous week's data to identify trends
7. **Generates aggregated metrics** including foundation-level statistics and utilization patterns
8. **Outputs structured analytics data** for report generation

#### Data Processing Flow

```python
# 1. Data Consolidation and Validation
collected_files = glob("collected-data/data/all_clusters_*.json")
all_namespaces = []
for file in collected_files:
    try:
        data = json.load(file)
        validated_data = validate_schema(data)  # Check for required fields
        all_namespaces.extend(validated_data)
    except (json.JSONDecodeError, ValidationError) as e:
        log_error(f"Invalid data in {file}: {e}")
        continue

# 2. Application Classification (System vs Application)
def classify_namespace(namespace):
    system_patterns = [
        "kube-", "istio-", "gatekeeper-", "vmware-", "pks-",
        "default", "monitoring", "logging", "cert-manager",
        "ingress-", "tekton-", "harbor-", "velero-"
    ]
    namespace_name = namespace['namespace'].lower()
    return not any(pattern in namespace_name for pattern in system_patterns)

# 3. Migration Readiness Scoring Algorithm (0-100 scale)
def calculate_readiness_score(namespace):
    score = 100  # Start with perfect score

    # Activity penalty (active apps need more planning)
    if namespace['is_active']:
        score -= 20

    # Size complexity penalty
    pod_count = namespace.get('pod_count', 0)
    if pod_count > 20:
        score -= 25  # Very large application
    elif pod_count > 10:
        score -= 15  # Large application
    elif pod_count > 5:
        score -= 10  # Medium application

    # Environment criticality penalty
    if namespace['environment'] == 'prod':
        score -= 25  # Production requires careful migration
    elif namespace['environment'] == 'nonprod':
        score -= 10  # Non-prod has some risk

    # Service complexity penalty
    service_count = namespace.get('service_count', 0)
    if service_count > 5:
        score -= 15  # Complex networking
    elif service_count > 2:
        score -= 5   # Moderate networking

    # Stateful workload penalty
    if namespace.get('statefulset_count', 0) > 0:
        score -= 15  # StatefulSets require data migration planning

    # Data quality penalty
    if not namespace.get('labels', {}).get('app-id'):
        score -= 10  # Missing AppID makes tracking difficult

    # Age bonus (older apps may be more stable)
    creation_time = datetime.fromisoformat(namespace['creation_timestamp'].replace('Z', '+00:00'))
    age_days = (datetime.now(timezone.utc) - creation_time).days
    if age_days > 180:  # 6+ months old
        score += 5  # Likely stable

    return max(0, min(100, score))  # Clamp to 0-100 range

# 4. Historical Trend Analysis
def analyze_trends(current_data, historical_data):
    trends = {
        'new_applications': [],
        'migrated_applications': [],
        'activity_changes': [],
        'resource_growth': []
    }

    # Compare with previous week's data
    previous_apps = {app['namespace']: app for app in historical_data}
    current_apps = {app['namespace']: app for app in current_data}

    # Identify new applications
    trends['new_applications'] = [
        app for ns, app in current_apps.items()
        if ns not in previous_apps
    ]

    # Identify potentially migrated applications (missing from current)
    trends['migrated_applications'] = [
        app for ns, app in previous_apps.items()
        if ns not in current_apps
    ]

    return trends

# 5. Foundation-Level Analytics
def generate_foundation_metrics(namespaces, foundation_name):
    total_apps = len([ns for ns in namespaces if classify_namespace(ns)])
    active_apps = len([ns for ns in namespaces if ns['is_active'] and classify_namespace(ns)])

    readiness_scores = [calculate_readiness_score(ns) for ns in namespaces if classify_namespace(ns)]
    avg_readiness = sum(readiness_scores) / len(readiness_scores) if readiness_scores else 0

    return {
        'foundation': foundation_name,
        'total_applications': total_apps,
        'active_applications': active_apps,
        'inactive_applications': total_apps - active_apps,
        'average_readiness_score': round(avg_readiness, 2),
        'high_readiness_apps': len([s for s in readiness_scores if s >= 80]),
        'medium_readiness_apps': len([s for s in readiness_scores if 40 <= s < 80]),
        'low_readiness_apps': len([s for s in readiness_scores if s < 40])
    }
```

### generate-reports Task

**Purpose**: Transform aggregated application data into business-consumable reports in multiple formats for different stakeholder audiences

**Container**: s3-container-image (Python 3.9+)
**Tools**: Python, pandas, csv, openpyxl

**What it does**:

1. **Loads processed analytics data** from the aggregate-data task output
2. **Generates multiple report formats** targeting different business needs and audiences
3. **Creates CSV files optimized for Excel** with proper column formatting and data types
4. **Produces JSON files for API consumption** and automated processing systems
5. **Applies data visualization preparation** by pre-calculating pivot table data and trend metrics
6. **Implements business logic rules** for recommendations and priority classifications
7. **Validates report data quality** ensuring completeness and accuracy before output
8. **Structures output files** with consistent naming and organization for easy consumption

#### Report Generation Process

```python
# 1. Data Loading and Preparation
def load_aggregated_data():
    with open('aggregated-data/foundation_analytics.json', 'r') as f:
        analytics = json.load(f)

    applications_df = pd.DataFrame(analytics['applications'])
    foundation_metrics = analytics['foundation_metrics']
    trends = analytics['trends']

    return applications_df, foundation_metrics, trends

# 2. Business Logic for Recommendations
def generate_recommendations(app_data):
    recommendations = []

    for _, app in app_data.iterrows():
        rec = {
            'namespace': app['namespace'],
            'readiness_score': app['readiness_score'],
            'priority': 'High' if app['readiness_score'] >= 80 else
                       'Medium' if app['readiness_score'] >= 40 else 'Low',
            'recommendation': '',
            'required_actions': [],
            'risk_level': '',
            'estimated_effort': ''
        }

        # Generate specific recommendations based on score factors
        if app['readiness_score'] >= 80:
            rec['recommendation'] = 'Ready for immediate migration'
            rec['risk_level'] = 'Low'
            rec['estimated_effort'] = '1-2 weeks'
        elif app['readiness_score'] >= 60:
            rec['recommendation'] = 'Minor planning needed before migration'
            rec['risk_level'] = 'Medium'
            rec['estimated_effort'] = '3-4 weeks'
            rec['required_actions'] = ['Review application dependencies', 'Test migration process']
        elif app['readiness_score'] >= 40:
            rec['recommendation'] = 'Significant migration planning required'
            rec['risk_level'] = 'Medium-High'
            rec['estimated_effort'] = '6-8 weeks'
            rec['required_actions'] = ['Detailed application analysis', 'Migration strategy design', 'Stakeholder alignment']
        else:
            rec['recommendation'] = 'Complex migration requiring detailed analysis'
            rec['risk_level'] = 'High'
            rec['estimated_effort'] = '12+ weeks'
            rec['required_actions'] = ['Application architecture review', 'Data migration planning', 'Business impact assessment']

        recommendations.append(rec)

    return pd.DataFrame(recommendations)
```

#### Report Types Generated

1. **Application Report** (`application_report_YYYYMMDD.csv`)
   - **Purpose**: Complete application inventory for detailed analysis
   - **Audience**: Application teams, platform engineers, migration specialists
   - **Contents**:
     - Application ID and namespace details
     - Cluster and foundation location
     - Resource utilization (pods, services, deployments)
     - Activity status and last activity timestamp
     - Migration readiness score with breakdown
     - Environment classification (prod/nonprod)
     - Data quality indicators
     - Historical comparison metrics

2. **Executive Summary** (`executive_summary_YYYYMMDD.csv`)
   - **Purpose**: High-level KPIs and trend analysis for leadership
   - **Audience**: Management, executives, program managers
   - **Contents**:
     - Foundation-level application counts
     - Active vs inactive application breakdown
     - Migration readiness distribution
     - Week-over-week trend indicators
     - Risk assessment summary
     - Resource utilization overview

3. **Migration Priority** (`migration_priority_YYYYMMDD.csv`)
   - **Purpose**: Actionable migration roadmap with prioritized applications
   - **Audience**: Migration project managers, application owners
   - **Contents**:
     - Applications ranked by readiness score
     - Migration complexity assessment
     - Required actions per application
     - Estimated effort and timeline
     - Risk level classification
     - Recommended migration sequence

4. **Cluster Utilization** (`cluster_utilization_YYYYMMDD.csv`)
   - **Purpose**: Infrastructure capacity planning and optimization
   - **Audience**: Infrastructure teams, capacity planners
   - **Contents**:
     - Per-cluster application distribution
     - Resource density metrics
     - Foundation-level comparisons
     - Utilization trends over time
     - Capacity recommendations

### package-reports Task

**Purpose**: Compress and timestamp generated reports for efficient storage and organized archival in S3

**Container**: s3-container-image (Alpine Linux)
**Tools**: tar, gzip, date utilities

**What it does**:

1. **Creates standardized timestamps** using UTC timezone for consistent global scheduling
2. **Generates foundation-specific filenames** following organizational naming conventions
3. **Compresses report directories** using tar.gz format for optimal storage and transfer
4. **Preserves directory structure** maintaining report organization within archives
5. **Validates archive integrity** ensuring successful compression before proceeding
6. **Prepares metadata files** with archive contents and generation details
7. **Optimizes file sizes** while maintaining fast extraction capabilities
8. **Outputs versioned archives** ready for S3 upload with predictable naming patterns

#### Packaging Process

```bash
#!/bin/bash
set -o errexit
set -o pipefail

# 1. Environment and Timing Setup
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)  # UTC timestamp for consistency
FOUNDATION="${ENVIRONMENT}"     # e.g., "dc01-k8s-n-01"
ARCHIVE_NAME="weekly-report-${FOUNDATION}-${TIMESTAMP}.tar.gz"

echo "Packaging reports for foundation: ${FOUNDATION}"
echo "Archive timestamp: ${TIMESTAMP}"
echo "Output archive: ${ARCHIVE_NAME}"

# 2. Pre-packaging Validation
if [[ ! -d "generated-reports/reports" ]]; then
    echo "Error: Generated reports directory not found"
    exit 1
fi

REPORT_COUNT=$(find generated-reports/reports -name "*.csv" -o -name "*.json" | wc -l)
if [[ ${REPORT_COUNT} -eq 0 ]]; then
    echo "Error: No reports found to package"
    exit 1
fi

echo "Found ${REPORT_COUNT} report files to package"

# 3. Create Archive with Optimal Compression
cd generated-reports
tar -czf "../packaged-reports/${ARCHIVE_NAME}" \
    --exclude="*.tmp" \
    --exclude="*.log" \
    reports/

# 4. Verify Archive Integrity
echo "Verifying archive integrity..."
if tar -tzf "../packaged-reports/${ARCHIVE_NAME}" > /dev/null 2>&1; then
    echo "Archive verification successful"
else
    echo "Error: Archive verification failed"
    exit 1
fi

# 5. Generate Archive Metadata
cd ../packaged-reports
ARCHIVE_SIZE=$(du -h "${ARCHIVE_NAME}" | cut -f1)
ARCHIVE_FILES=$(tar -tzf "${ARCHIVE_NAME}" | wc -l)

cat > "${ARCHIVE_NAME}.metadata" <<EOF
{
  "archive_name": "${ARCHIVE_NAME}",
  "foundation": "${FOUNDATION}",
  "generation_timestamp": "${TIMESTAMP}",
  "archive_size": "${ARCHIVE_SIZE}",
  "file_count": ${ARCHIVE_FILES},
  "reports_included": [
    "application_report_${TIMESTAMP}.csv",
    "executive_summary_${TIMESTAMP}.csv",
    "migration_priority_${TIMESTAMP}.csv",
    "cluster_utilization_${TIMESTAMP}.csv",
    "foundation_analytics_${TIMESTAMP}.json"
  ],
  "generation_pipeline": "tkgi-app-tracker-${FOUNDATION}",
  "retention_period": "12_months"
}
EOF

echo "Archive packaging completed successfully"
echo "Final archive: ${ARCHIVE_NAME} (${ARCHIVE_SIZE})"
echo "Metadata file: ${ARCHIVE_NAME}.metadata"
```

### notify Task

**Purpose**: Send stakeholder notifications for both successful pipeline completion and failure scenarios via Teams webhooks

**Container**: s3-container-image (Alpine Linux)
**Tools**: curl, jq, bash

**What it does**:

1. **Formats notification messages** based on pipeline context (success/failure) and foundation details
2. **Constructs Teams webhook payloads** with proper JSON structure and visual formatting
3. **Sends HTTP POST requests** to configured Teams webhook URLs with retry logic
4. **Handles notification failures gracefully** to prevent blocking pipeline execution
5. **Includes relevant context** such as S3 URLs, foundation names, and error details
6. **Supports multiple notification types** including success alerts, failure alerts, and status updates
7. **Logs notification attempts** for troubleshooting and audit purposes
8. **Validates webhook responses** to ensure successful message delivery

#### Notification Process

```bash
#!/bin/bash
set -o errexit
set -o pipefail

# 1. Environment Setup and Input Validation
WEBHOOK_URL="${WEBHOOK_URL:-}"
MESSAGE="${MESSAGE:-Default pipeline notification}"
FOUNDATION="${FOUNDATION:-unknown}"
NOTIFICATION_TYPE="${NOTIFICATION_TYPE:-info}"

if [[ -z "${WEBHOOK_URL}" ]]; then
    echo "Warning: WEBHOOK_URL not provided, skipping notification"
    exit 0
fi

echo "Sending ${NOTIFICATION_TYPE} notification for foundation: ${FOUNDATION}"

# 2. Message Formatting Based on Type
case "${NOTIFICATION_TYPE}" in
    "success")
        TITLE="✅ TKGI App Tracker - Success"
        COLOR="good"  # Green in Teams
        MESSAGE="TKGI Application Tracker reports generated successfully for foundation **${FOUNDATION}**. Reports available in S3."
        ;;
    "failure")
        TITLE="❌ TKGI App Tracker - Failure"
        COLOR="attention"  # Red in Teams
        MESSAGE="Failed to complete TKGI Application Tracker pipeline for foundation **${FOUNDATION}**. Check pipeline logs for details."
        ;;
    "info")
        TITLE="ℹ️ TKGI App Tracker - Information"
        COLOR="#17a2b8"  # Blue in Teams
        ;;
esac

# 3. Teams Webhook Payload Construction
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
PAYLOAD=$(jq -n \
    --arg title "${TITLE}" \
    --arg message "${MESSAGE}" \
    --arg color "${COLOR}" \
    --arg foundation "${FOUNDATION}" \
    --arg timestamp "${TIMESTAMP}" \
    '{
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": $title,
        "themeColor": $color,
        "sections": [{
            "activityTitle": $title,
            "activitySubtitle": ("Foundation: " + $foundation),
            "activityImage": "https://docs.microsoft.com/en-us/azure/devops/_img/index/devopsicon-teams.png",
            "facts": [
                {
                    "name": "Foundation",
                    "value": $foundation
                },
                {
                    "name": "Timestamp",
                    "value": $timestamp
                },
                {
                    "name": "Pipeline",
                    "value": ("tkgi-app-tracker-" + $foundation)
                }
            ],
            "text": $message
        }]
    }')

# 4. HTTP Request with Retry Logic
MAX_RETRIES=3
RETRY_COUNT=0

while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
    echo "Sending notification (attempt $((RETRY_COUNT + 1))/${MAX_RETRIES})"

    HTTP_STATUS=$(curl -s -o /tmp/webhook_response -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}" \
        "${WEBHOOK_URL}")

    if [[ "${HTTP_STATUS}" == "200" ]]; then
        echo "Notification sent successfully"
        exit 0
    else
        echo "Notification failed with HTTP status: ${HTTP_STATUS}"
        RETRY_COUNT=$((RETRY_COUNT + 1))

        if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; then
            echo "Retrying in 5 seconds..."
            sleep 5
        fi
    fi
done

echo "Failed to send notification after ${MAX_RETRIES} attempts"
echo "Response body:"
cat /tmp/webhook_response 2>/dev/null || echo "No response body available"

# Don't fail pipeline if notification fails
exit 0
```

### run-tests Task (test-pipeline job)

**Purpose**: Execute comprehensive unit and integration tests to validate code quality and pipeline logic before deployment

**Container**: s3-container-image (cflinux with BATS)
**Tools**: BATS (Bash Automated Testing System), Python pytest, shellcheck

**What it does**:

1. **Runs BATS unit tests** for all shell scripts and pipeline logic validation
2. **Executes Python tests** for data processing and aggregation functions
3. **Validates mock data scenarios** ensuring proper handling of edge cases and error conditions
4. **Tests API integration points** using mocked TKGI and Kubernetes responses
5. **Verifies data transformation logic** with sample datasets and expected outputs
6. **Checks function return codes** and error handling paths
7. **Validates JSON schema compliance** for data exchange between pipeline tasks
8. **Generates test coverage reports** to ensure comprehensive testing

#### Testing Process

```bash
#!/bin/bash
set -o errexit
set -o pipefail

echo "Starting TKGI App Tracker test suite..."

# 1. Test Environment Setup
export TEST_DATA_DIR="tests/fixtures"
export MOCK_DATA_DIR="tests/mock-data"
export TEST_OUTPUT_DIR="/tmp/test-output"

mkdir -p "${TEST_OUTPUT_DIR}"

# 2. Shell Script Unit Tests (BATS)
echo "Running BATS unit tests..."
BATS_TESTS=(
    "tests/unit/test-foundation-utils.bats"
    "tests/unit/test-data-collection.bats"
    "tests/unit/test-aggregation-logic.bats"
    "tests/unit/test-report-generation.bats"
)

for test_file in "${BATS_TESTS[@]}"; do
    if [[ -f "${test_file}" ]]; then
        echo "Running: ${test_file}"
        bats "${test_file}" --output "${TEST_OUTPUT_DIR}/$(basename ${test_file}).xml" --formatter junit
    else
        echo "Warning: Test file not found: ${test_file}"
    fi
done

# 3. Python Unit Tests
echo "Running Python unit tests..."
if [[ -f "tests/python/test_aggregation.py" ]]; then
    python -m pytest tests/python/ \
        --verbose \
        --junitxml="${TEST_OUTPUT_DIR}/python-tests.xml" \
        --cov=scripts \
        --cov-report=html:"${TEST_OUTPUT_DIR}/coverage"
fi

# 4. Integration Tests with Mock Data
echo "Running integration tests with mock data..."
INTEGRATION_TESTS=(
    "tests/integration/test-end-to-end-pipeline.bats"
    "tests/integration/test-tkgi-api-mocking.bats"
    "tests/integration/test-error-scenarios.bats"
)

for test_file in "${INTEGRATION_TESTS[@]}"; do
    if [[ -f "${test_file}" ]]; then
        echo "Running integration test: ${test_file}"
        MOCK_TKGI_API=true MOCK_KUBECTL=true bats "${test_file}"
    fi
done

# 5. Data Validation Tests
echo "Running data validation tests..."
if [[ -f "scripts/aggregate-data.py" ]]; then
    echo "Testing aggregation with sample data..."
    python scripts/aggregate-data.py \
        --input-dir "${MOCK_DATA_DIR}/sample-clusters" \
        --output-dir "${TEST_OUTPUT_DIR}/test-aggregation" \
        --validate-only
fi

# 6. Report Generation Tests
echo "Testing report generation..."
if [[ -f "scripts/generate-reports.py" ]]; then
    python scripts/generate-reports.py \
        --input-file "${MOCK_DATA_DIR}/sample-aggregated-data.json" \
        --output-dir "${TEST_OUTPUT_DIR}/test-reports" \
        --test-mode
fi

echo "Test suite completed successfully"
echo "Test results available in: ${TEST_OUTPUT_DIR}"
```

### validate-scripts Task (test-pipeline job)

**Purpose**: Perform static analysis and security scanning of all scripts to ensure code quality, security, and adherence to best practices

**Container**: s3-container-image (cflinux with analysis tools)
**Tools**: shellcheck, pylint, yamllint, hadolint, bandit

**What it does**:

1. **Runs shellcheck on all bash scripts** to identify syntax errors, anti-patterns, and portability issues
2. **Executes Python linting** using pylint and flake8 for code quality and style compliance
3. **Validates YAML files** including pipeline configurations and parameter files
4. **Performs security scanning** using bandit to detect potential security vulnerabilities
5. **Checks for hardcoded secrets** and sensitive information exposure
6. **Validates Docker file syntax** and best practices for container definitions
7. **Ensures consistent code formatting** and adherence to organizational standards
8. **Generates quality reports** with actionable recommendations for improvements

#### Validation Process

```bash
#!/bin/bash
set -o errexit
set -o pipefail

echo "Starting script validation and security scanning..."

VALIDATION_ERRORS=0
VALIDATION_OUTPUT="/tmp/validation-results"
mkdir -p "${VALIDATION_OUTPUT}"

# 1. Bash Script Validation (ShellCheck)
echo "Running ShellCheck on bash scripts..."
BASH_SCRIPTS=$(find . -name "*.sh" -type f | grep -v ".git" | grep -v "/tests/")

if [[ -n "${BASH_SCRIPTS}" ]]; then
    for script in ${BASH_SCRIPTS}; do
        echo "Checking: ${script}"
        if ! shellcheck -f gcc "${script}" >> "${VALIDATION_OUTPUT}/shellcheck.log" 2>&1; then
            echo "❌ ShellCheck failed for: ${script}"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        else
            echo "✅ ShellCheck passed for: ${script}"
        fi
    done
else
    echo "No bash scripts found for validation"
fi

# 2. Python Code Validation
echo "Running Python linting..."
PYTHON_SCRIPTS=$(find . -name "*.py" -type f | grep -v ".git" | grep -v "/tests/")

if [[ -n "${PYTHON_SCRIPTS}" ]]; then
    # PyLint validation
    for script in ${PYTHON_SCRIPTS}; do
        echo "Linting: ${script}"
        if ! pylint "${script}" --output-format=parseable >> "${VALIDATION_OUTPUT}/pylint.log" 2>&1; then
            echo "⚠️ PyLint warnings for: ${script}"
        else
            echo "✅ PyLint passed for: ${script}"
        fi
    done

    # Security scanning with Bandit
    echo "Running security scan..."
    if ! bandit -r . -f json -o "${VALIDATION_OUTPUT}/bandit.json" --exclude "./tests/*" 2>/dev/null; then
        echo "❌ Security vulnerabilities detected"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    else
        echo "✅ Security scan passed"
    fi
else
    echo "No Python scripts found for validation"
fi

# 3. YAML Validation
echo "Validating YAML files..."
YAML_FILES=$(find . -name "*.yml" -o -name "*.yaml" | grep -v ".git")

for yaml_file in ${YAML_FILES}; do
    echo "Validating: ${yaml_file}"
    if ! yamllint "${yaml_file}" >> "${VALIDATION_OUTPUT}/yamllint.log" 2>&1; then
        echo "❌ YAML validation failed for: ${yaml_file}"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    else
        echo "✅ YAML validation passed for: ${yaml_file}"
    fi
done

# 4. Secret Detection
echo "Scanning for hardcoded secrets..."
SECRET_PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "token\s*=\s*['\"][^'\"]+['\"]"
    "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -r -i -E "${pattern}" . --exclude-dir=.git --exclude-dir=tests >> "${VALIDATION_OUTPUT}/secrets.log" 2>&1; then
        echo "❌ Potential hardcoded secrets detected"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
done

# 5. File Permission Validation
echo "Checking file permissions..."
EXECUTABLE_SCRIPTS=$(find . -name "*.sh" -type f | grep -v ".git")
for script in ${EXECUTABLE_SCRIPTS}; do
    if [[ ! -x "${script}" ]]; then
        echo "❌ Script not executable: ${script}"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
done

# 6. Generate Summary Report
cat > "${VALIDATION_OUTPUT}/summary.txt" <<EOF
TKGI App Tracker - Validation Summary
=====================================
Timestamp: $(date -u)
Total Validation Errors: ${VALIDATION_ERRORS}

Files Validated:
- Bash Scripts: $(echo "${BASH_SCRIPTS}" | wc -w)
- Python Scripts: $(echo "${PYTHON_SCRIPTS}" | wc -w)
- YAML Files: $(echo "${YAML_FILES}" | wc -w)

Results:
- ShellCheck: $(cat "${VALIDATION_OUTPUT}/shellcheck.log" 2>/dev/null | wc -l) issues
- PyLint: $(cat "${VALIDATION_OUTPUT}/pylint.log" 2>/dev/null | wc -l) issues
- YAML Lint: $(cat "${VALIDATION_OUTPUT}/yamllint.log" 2>/dev/null | wc -l) issues
- Security Scan: $(if [[ -f "${VALIDATION_OUTPUT}/bandit.json" ]]; then echo "Completed"; else echo "Failed"; fi)

Validation Status: $(if [[ ${VALIDATION_ERRORS} -eq 0 ]]; then echo "PASSED"; else echo "FAILED"; fi)
EOF

echo "Validation completed with ${VALIDATION_ERRORS} errors"
cat "${VALIDATION_OUTPUT}/summary.txt"

# Exit with error if validation issues found
if [[ ${VALIDATION_ERRORS} -gt 0 ]]; then
    echo "❌ Validation failed - see logs in ${VALIDATION_OUTPUT}/"
    exit 1
else
    echo "✅ All validations passed successfully"
    exit 0
fi
```

## Resource Configuration

### S3 Storage Structure

```sh
s3://tkgi-app-tracker-reports/
├── reports/
│   ├── dc01-k8s-n-01/
│   │   ├── weekly-report-dc01-k8s-n-01-20240115_063000.tar.gz
│   │   ├── weekly-report-dc01-k8s-n-01-20240122_063000.tar.gz
│   │   └── ...
│   ├── dc02-k8s-n-01/
│   │   ├── weekly-report-dc02-k8s-n-01-20240115_063000.tar.gz
│   │   └── ...
│   └── dc03-k8s-p-01/
│       ├── weekly-report-dc03-k8s-p-01-20240115_063000.tar.gz
│       └── ...
```

### Git Resources

- **tkgi-app-tracker-repo**: Source code repository
- **config-repo**: Configuration repository for enrichment and drift detection (environment-dependent)
  - **Purpose**: Provides reference configuration data to compare against actual deployed state
  - **Usage**: Used to enrich collected data with intended/configured metadata and identify configuration drift
  - **Not used as source of truth**: TKGI API and kubectl remain the authoritative sources for actual cluster state

### Container Images

- **s3-container-image**: Organizational standard cflinux container with:
  - om CLI v7.10.0+
  - tkgi CLI
  - kubectl
  - Python 3.9+
  - Standard Unix tools (jq, curl, tar, gzip)

## Error Handling & Notifications

### Failure Scenarios

1. **Authentication Failures**
   - om CLI authentication to Ops Manager
   - TKGI API authentication
   - kubectl cluster access

2. **Data Collection Failures**
   - Network connectivity issues
   - Cluster unavailability
   - API rate limiting

3. **Processing Failures**
   - Data format inconsistencies
   - Resource exhaustion
   - Storage system errors

### Notification Strategy

#### Success Notifications

```json
{
  "text": "TKGI Application Tracker reports generated successfully for foundation dc01-k8s-n-01. Reports available in S3."
}
```

#### Failure Notifications

```json
{
  "text": "Failed to collect TKGI cluster data from foundation dc01-k8s-n-01. Check pipeline logs for details."
}
```

## Performance Characteristics

### Typical Execution Times

- **collect-data**: 5-10 minutes (scales with cluster/namespace count)
- **aggregate-data**: 2-5 minutes (scales with total data volume)
- **generate-reports**: 1-3 minutes (scales with application count)
- **package-reports**: <1 minute
- **upload-to-s3**: <1 minute
- **notifications**: <1 minute

**Total Pipeline Duration**: 10-20 minutes per foundation

### Resource Requirements

- **CPU**: 2-4 cores recommended
- **Memory**: 4-8 GB recommended
- **Storage**: 1-2 GB temporary workspace
- **Network**: Stable connectivity to TKGI APIs and S3

### Scalability Considerations

- Pipeline scales linearly with cluster count
- Each foundation runs independently
- Parallel execution across datacenters
- S3 storage auto-scales

## Deployment Architecture

### Foundation-Specific Pipeline Deployment

Each foundation gets **one pipeline instance** with **two jobs** (collect-and-report, test-pipeline):

```sh
Datacenter: DC01 (Lab Environment)
├── Foundation: dc01-k8s-n-01
│   ├── Pipeline: tkgi-app-tracker-dc01-k8s-n-01 (single pipeline)
│   │   ├── Job: collect-and-report (weekly timer + manual trigger)
│   │   └── Job: test-pipeline (git trigger)
│   ├── Team: dc01-k8s-n-01
│   └── Parameters: ~/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml
├── Foundation: dc01-k8s-n-02
│   ├── Pipeline: tkgi-app-tracker-dc01-k8s-n-02 (single pipeline)
│   │   ├── Job: collect-and-report (weekly timer + manual trigger)
│   │   └── Job: test-pipeline (git trigger)
│   ├── Team: dc01-k8s-n-02
│   └── Parameters: ~/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml (shared)
└── ...

Datacenter: DC02 (Non-Prod Environment)
├── Foundation: dc02-k8s-n-01
│   ├── Pipeline: tkgi-app-tracker-dc02-k8s-n-01 (single pipeline)
│   │   ├── Job: collect-and-report (weekly timer + manual trigger)
│   │   └── Job: test-pipeline (git trigger)
│   ├── Team: dc02-k8s-n-01
│   └── Parameters: ~/git/params/dc02/dc02-k8s-tkgi-app-tracker.yml
└── ...
```

### Security Model

- **Authentication**: OAuth2 client credentials for Ops Manager
- **Authorization**: TKGI admin service account
- **Network**: Private network access to TKGI APIs
- **Storage**: IAM-based S3 access controls
- **Secrets**: Vault/CredHub integration for sensitive parameters

## Monitoring & Observability

### Pipeline Metrics

- Execution duration per task
- Success/failure rates
- Data volume processed
- Report generation statistics

### Business Metrics

- Total applications tracked
- Migration readiness distribution
- Foundation utilization patterns
- Historical trend analysis

### Alerting

- Pipeline execution failures
- Authentication issues
- Data quality degradation
- Storage system problems

## Maintenance & Operations

### Regular Maintenance

- Weekly pipeline execution monitoring
- Monthly parameter file reviews
- Quarterly capacity planning
- Semi-annual security reviews

### Troubleshooting

- **Pipeline build logs**:
  - `fly builds -j {pipeline-name}/{job-name}` - List recent builds
  - `fly watch -j {pipeline-name}/{job-name} -b {build-number}` - Stream build output
  - `fly hijack -b {build-number}` - Access running/failed build container
- **Manual task execution**: Use `fly execute` for debugging individual tasks
- **Parameter validation**: `fly validate-pipeline` for YAML syntax checking
- **Test data generation utilities**: Scripts in `tests/` directory

### Upgrade Procedures

- Blue/green deployment for pipeline updates
- Backward compatibility verification
- Parameter migration scripts
- Rollback procedures
