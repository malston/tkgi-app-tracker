# TKGI Application Tracker - Deployment Guide

This guide covers deploying the TKGI Application Tracker across the three separate Concourse environments based on separation of duties policies.

## Environment Overview

The system is deployed across three separate Concourse instances:

| Environment | Foundations | Concourse Target | Description |
|-------------|-------------|------------------|-------------|
| **Lab** | DC01 | `lab` | Development and testing environment |
| **Non-Prod** | DC02 | `nonprod` | Non-production applications |
| **Production** | DC03, DC04 | `prod` | Production applications |

## Prerequisites

### Access Requirements

1. **Lab Environment Access**
   - Access to DC01 foundation Ops Manager
   - Lab Concourse access with pipeline deployment permissions
   - DC01 TKGI API access

2. **Non-Prod Environment Access**
   - Access to DC02 foundation Ops Manager
   - Non-Prod Concourse access with pipeline deployment permissions
   - DC02 TKGI API access

3. **Production Environment Access**
   - Access to DC03 and DC04 foundation Ops Managers
   - Production Concourse access with pipeline deployment permissions
   - DC03 and DC04 TKGI API access

### Tool Requirements

- `fly` CLI for Concourse
- `om` CLI for Ops Manager integration
- `tkgi` CLI for TKGI API access
- Access to parameter management system (Vault/CredHub)

## Parameter Configuration

Parameters are organized by datacenter and follow the naming convention:
`~/git/params/{datacenter}/{datacenter}-k8s-tkgi-app-tracker.yml`

### 1. Lab Environment Parameters (DC01)

Create parameter file: `~/git/params/dc01/dc01-k8s-tkgi-app-tracker.yml`

```yaml
# Git Configuration
git-uri: git@github.com:malston/tkgi-app-tracker.git
branch: main
git-private-key: ((git-private-key))

# Params Repository
params-uri: git@github.com:malston/params.git
params-branch: main
params-private-key: ((params-private-key))

# S3 Configuration for Lab Reports
s3-bucket-lab: tkgi-app-tracker-reports-lab
s3-region: us-east-1
s3-access-key: ((s3-access-key))
s3-secret-key: ((s3-secret-key))

# Notification Configuration
teams-webhook-url: ((teams-webhook-url))

# DC01 Foundation Configuration
dc01-om-target: ((dc01-om-target))
dc01-om-client-id: ((dc01-om-client-id))
dc01-om-client-secret: ((dc01-om-client-secret))
dc01-pks-api-endpoint: ((dc01-pks-api-endpoint))
```

### 2. Non-Prod Environment Parameters (DC02)

Create parameter file: `~/git/params/dc02/dc02-k8s-tkgi-app-tracker.yml`

```yaml
# Git Configuration
git-uri: git@github.com:malston/tkgi-app-tracker.git
branch: main
git-private-key: ((git-private-key))

# Params Repository
params-uri: git@github.com:malston/params.git
params-branch: main
params-private-key: ((params-private-key))

# S3 Configuration for Non-Prod Reports
s3-bucket-nonprod: tkgi-app-tracker-reports-nonprod
s3-region: us-east-1
s3-access-key: ((s3-access-key))
s3-secret-key: ((s3-secret-key))

# Notification Configuration
teams-webhook-url: ((teams-webhook-url))

# DC02 Foundation Configuration
dc02-om-target: ((dc02-om-target))
dc02-om-client-id: ((dc02-om-client-id))
dc02-om-client-secret: ((dc02-om-client-secret))
dc02-pks-api-endpoint: ((dc02-pks-api-endpoint))
```

### 3. Production Environment Parameters (DC03/DC04)

Create parameter files:

- `~/git/params/dc03/dc03-k8s-tkgi-app-tracker.yml`
- `~/git/params/dc04/dc04-k8s-tkgi-app-tracker.yml`

```yaml
# Git Configuration
git-uri: git@github.com:malston/tkgi-app-tracker.git
branch: main
git-private-key: ((git-private-key))

# Params Repository
params-uri: git@github.com:malston/params.git
params-branch: main
params-private-key: ((params-private-key))

# S3 Configuration for Production Reports
s3-bucket-prod: tkgi-app-tracker-reports-prod
s3-region: us-east-1
s3-access-key: ((s3-access-key))
s3-secret-key: ((s3-secret-key))

# Notification Configuration
teams-webhook-url: ((teams-webhook-url))

# DC03 Foundation Configuration
dc03-om-target: ((dc03-om-target))
dc03-om-client-id: ((dc03-om-client-id))
dc03-om-client-secret: ((dc03-om-client-secret))
dc03-pks-api-endpoint: ((dc03-pks-api-endpoint))

# DC04 Foundation Configuration
dc04-om-target: ((dc04-om-target))
dc04-om-client-id: ((dc04-om-client-id))
dc04-om-client-secret: ((dc04-om-client-secret))
dc04-pks-api-endpoint: ((dc04-pks-api-endpoint))
```

## Deployment Steps

### 1. Deploy Lab Environment Pipeline

```bash
# Login to lab Concourse
fly -t lab login -c https://concourse.lab.example.com

# Deploy DC01 pipeline
./ci/fly.sh set -t lab -f dc01-k8s-n-01

# Unpause pipeline
fly -t lab unpause-pipeline -p tkgi-app-tracker-lab
```

### 2. Deploy Non-Prod Environment Pipeline

```bash
# Login to non-prod Concourse
fly -t nonprod login -c https://concourse.nonprod.example.com

# Deploy DC02 pipeline
./ci/fly.sh set -t nonprod -f dc02-k8s-n-01

# Unpause pipeline
fly -t nonprod unpause-pipeline -p tkgi-app-tracker-nonprod
```

### 3. Deploy Production Environment Pipeline

```bash
# Login to production Concourse
fly -t prod login -c https://concourse.prod.example.com

# Deploy DC03 pipeline
./ci/fly.sh set -t prod -f dc03-k8s-p-01

# Deploy DC04 pipeline
./ci/fly.sh set -t prod -f dc04-k8s-p-01

# Unpause pipeline
fly -t prod unpause-pipeline -p tkgi-app-tracker-prod
```

## Verification

### 1. Verify Pipeline Deployment

```bash
# Check lab pipelines
fly -t lab pipelines

# Check non-prod pipelines
fly -t nonprod pipelines

# Check prod pipelines
fly -t prod pipelines
```

### 2. Test Manual Execution

```bash
# Test lab environment
fly -t lab trigger-job -j tkgi-app-tracker-lab/collect-and-report

# Test non-prod environment
fly -t nonprod trigger-job -j tkgi-app-tracker-nonprod/collect-and-report

# Test prod environment
fly -t prod trigger-job -j tkgi-app-tracker-prod/collect-and-report
```

### 3. Verify Report Generation

Check S3 buckets for generated reports:

- `tkgi-app-tracker-reports-lab/reports/lab/`
- `tkgi-app-tracker-reports-nonprod/reports/nonprod/`
- `tkgi-app-tracker-reports-prod/reports/prod/`

## Operational Procedures

### Monitoring

1. **Weekly Schedule**: Pipelines run automatically every Monday:
   - Lab: 6:00 AM - 7:00 AM EST
   - Non-Prod: 6:15 AM - 7:15 AM EST
   - Production: 6:30 AM - 7:30 AM EST

2. **Notifications**: Teams notifications sent for:
   - Successful report generation
   - Pipeline failures
   - Data collection errors

### Troubleshooting

#### Pipeline Failures

1. **Authentication Issues**

   ```bash
   # Check TKGI API connectivity
   tkgi login -a https://api.pks.foundation.example.com -u admin -p password
   
   # Verify Ops Manager access
   om -t opsman.foundation.example.com -c client-id -s client-secret curl -p /api/v0/info
   ```

2. **Data Collection Issues**

   ```bash
   # Test single cluster collection
   ./scripts/collect-tkgi-cluster-data.sh -f foundation -c cluster-name
   
   # Check cluster connectivity
   kubectl --context=cluster-name get namespaces
   ```

3. **Report Generation Issues**

   ```bash
   # Validate data aggregation
   python3 scripts/aggregate-data.py -d data -r reports

   # Test report generation
   python3 scripts/generate-reports.py -r reports
   ```

### Maintenance

#### Updating Credentials

1. **Ops Manager Credentials**
   - Update parameter files with new client credentials
   - Redeploy affected pipelines

2. **TKGI API Changes**
   - Update PKS API endpoints if changed
   - Test connectivity before pipeline deployment

#### Pipeline Updates

1. **Code Changes**

   ```bash
   # Update and redeploy pipeline
   ./ci/fly.sh set -f foundation
   ```

2. **Parameter Changes**

   ```bash
   # Update parameter file and redeploy
   vim ~/git/params/tkgi-app-tracker/environment/params.yml
   ./ci/fly.sh set -f foundation
   ```

### Security Considerations

1. **Access Control**
   - Pipeline deployment requires appropriate Concourse team permissions
   - TKGI access follows existing foundation access controls
   - Parameter management through secure credential storage

2. **Data Handling**
   - All data collection uses read-only operations
   - No sensitive data stored in reports
   - S3 buckets configured with appropriate access policies

3. **Network Security**
   - All connections use TLS encryption
   - No inbound network access required
   - Follows existing network security policies

## Support

For issues or questions:

- Lab Environment: Contact lab operations team
- Non-Prod Environment: Contact non-prod operations team
- Production Environment: Contact production operations team
- Code Issues: Create repository issue or contact Platform Engineering team
