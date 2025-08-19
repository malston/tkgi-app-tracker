# Docker-Based Local Testing Guide

This guide explains how to test TKGI Application Tracker pipeline tasks locally using Docker containers that mirror the Concourse execution environment.

## Overview

The Docker-based testing approach addresses the limitations of local wrapper scripts by:

- **Replicating Production Environment**: Uses container images similar to Concourse's `s3-container-image`
- **Consistent Dependencies**: Ensures the same tools and versions as production
- **Isolated Execution**: Each task runs in a clean container environment
- **Authentic Testing**: Mimics the exact input/output structure of Concourse tasks

## Prerequisites

- Docker Engine (20.10+)
- Docker Compose (2.0+)
- Sufficient disk space for container images (~2GB)

## Quick Start

### 1. Build Test Container Image

```bash
# Build the test container image
make docker-build
```

### 2. Run Individual Tasks

```bash
# Test data collection
make docker-test TASK=collect-data

# Test with specific foundation
make docker-test TASK=aggregate-data FOUNDATION=dc02-k8s-n-01

# Test with verbose output
make docker-test TASK=generate-reports VERBOSE=true
```

### 3. Run Complete Pipeline

```bash
# Run full pipeline sequence
make docker-test TASK=full-pipeline
```

### 4. Interactive Development

```bash
# Start interactive development environment
make docker-dev
```

## Available Tasks

| Task | Description | Purpose |
|------|-------------|---------|
| `collect-data` | Test TKGI cluster data collection | Validates authentication and data extraction |
| `aggregate-data` | Test multi-cluster data aggregation | Verifies data combining and processing logic |
| `generate-reports` | Test CSV and JSON report generation | Confirms report formatting and calculations |
| `package-reports` | Test report packaging for distribution | Validates archive creation and structure |
| `run-tests` | Execute unit and integration tests | Runs BATS tests in container environment |
| `dev` | Interactive development shell | Provides bash environment for debugging |
| `full-pipeline` | Complete pipeline sequence | Tests end-to-end workflow |

## Docker Test Script Usage

The `./scripts/docker-test.sh` script provides direct control over Docker-based testing:

```bash
# Basic usage
./scripts/docker-test.sh <task> [options]

# Examples
./scripts/docker-test.sh collect-data -f dc01-k8s-n-01
./scripts/docker-test.sh aggregate-data --verbose
./scripts/docker-test.sh dev --interactive
./scripts/docker-test.sh full-pipeline --no-cleanup
```

### Options

- `-f, --foundation FOUNDATION`: Specify foundation for testing (default: dc01-k8s-n-01)
- `-v, --verbose`: Enable verbose output
- `--no-cleanup`: Keep containers after execution (for debugging)
- `-i, --interactive`: Run interactively (for dev task)

## Container Environment

### Base Image

- **Ubuntu 22.04**: Stable LTS base similar to production
- **Python 3.10+**: With pip and development tools
- **Common CLI Tools**: jq, curl, git, shellcheck, bats

### Installed Tools

- **kubectl**: Kubernetes command-line tool
- **om**: Ops Manager CLI for authentication
- **tkgi**: Mock TKGI CLI (placeholder for production version)
- **bats**: Bash testing framework

### Directory Structure

```
/workspace/
├── tkgi-app-tracker-repo/     # Source code (read-only mount)
├── params/                    # Test parameters and configuration  
├── collected-data/            # Data collection output
├── aggregated-data/           # Aggregation output
├── generated-reports/         # Report generation output
├── packaged-reports/          # Packaging output
└── test-results/              # Test execution results
```

## Configuration

### Test Data

Test parameters are automatically created in `./test-data/foundation-params.yml`:

```yaml
# Test parameters for foundation
foundation: dc01-k8s-n-01
datacenter: dc01
environment: lab

# Test TKGI configuration  
om_target: opsman.acme.com
om_client_id: test-client-id
om_client_secret: test-client-secret
tkgi_api_endpoint: api.pks.acme.com
```

### Environment Variables

Override test configuration with environment variables:

```bash
# Set test credentials
export OM_TARGET="opsman.test.local"
export OM_CLIENT_ID="test-client"
export OM_CLIENT_SECRET="test-secret"
export TKGI_API_ENDPOINT="api.pks.test.local"

# Run task with custom environment
./scripts/docker-test.sh collect-data
```

## Docker Compose Configuration

The `docker-compose.test.yml` file defines services for each task:

- **Extends base service**: Consistent Ubuntu environment
- **Task-specific volumes**: Proper input/output mapping
- **Environment variables**: Foundation and credential configuration
- **Profile-based execution**: Run only required containers

### Service Profiles

Each task uses a profile to control container execution:

```bash
# Run specific profile
docker-compose -f docker-compose.test.yml --profile collect-data up

# Multiple profiles  
docker-compose -f docker-compose.test.yml --profile collect-data --profile aggregate-data up
```

## Debugging and Development

### Interactive Development Environment

```bash
# Start development container
make docker-dev

# Inside container - standard workspace layout
cd /workspace/tkgi-app-tracker-repo
ls -la ci/tasks/
```

### Debugging Failed Tasks

```bash
# Run with no cleanup to examine output
./scripts/docker-test.sh collect-data --no-cleanup

# Check output directory
ls -la test-output/

# Examine container logs
docker-compose -f docker-compose.test.yml logs collect-data
```

### Manual Container Execution

```bash
# Run container manually
docker run -it --rm \
  -v $(pwd):/workspace/tkgi-app-tracker-repo:ro \
  -v $(pwd)/test-output:/workspace/output \
  -e FOUNDATION=dc01-k8s-n-01 \
  tkgi-app-tracker-test:latest \
  /bin/bash
```

## Testing Best Practices

### 1. Container-First Development

- Test all changes in Docker containers
- Don't rely on local environment for task development
- Use interactive development for debugging

### 2. Environment Parity

- Keep test container image updated with production tools
- Match environment variables and file structures
- Use realistic test data

### 3. Incremental Testing

- Test individual tasks before full pipeline
- Use verbose output for troubleshooting
- Validate outputs at each step

### 4. Clean Testing

- Always start with clean containers
- Use `--no-cleanup` only for debugging
- Clean up regularly with `make docker-clean`

## Limitations

### Authentication

- Uses mock credentials for testing
- Real TKGI/Ops Manager APIs not accessible in test environment
- kubectl commands will fail without valid cluster access

### Network Access

- Container has limited network access
- External API calls may fail or timeout
- Use mock data for comprehensive testing

### Performance

- Container startup adds overhead
- Docker volumes can be slower than native filesystem
- Not suitable for performance testing

## Benefits of Docker-Based Testing

- **Consistent Environment**: Same tools and versions as production
- **Better Isolation**: No local environment contamination  
- **Authentic Testing**: True Concourse task structure
- **Reproducible Results**: Same environment across machines
- **Production Parity**: Mirrors actual Concourse execution environment

## Troubleshooting

### Docker Issues

```bash
# Check Docker is running
docker version

# Clean up old containers
make docker-clean

# Rebuild image
make docker-build
```

### Volume Mount Issues

```bash
# Check file permissions
ls -la test-output/

# Ensure directories exist
mkdir -p test-data test-output
```

### Task Failures

```bash
# Run with verbose output
./scripts/docker-test.sh collect-data -v

# Keep containers for inspection
./scripts/docker-test.sh collect-data --no-cleanup

# Check container logs
docker-compose -f docker-compose.test.yml logs
```

## Integration with CI/CD

The Docker-based approach integrates with continuous integration:

```bash
# In CI pipeline
make docker-build
make docker-test TASK=run-tests
make docker-test TASK=full-pipeline
```

This ensures the same testing environment in CI as local development, improving reliability and reducing environment-specific issues.
