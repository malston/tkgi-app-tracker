# TKGI Application Tracker - Testing Guide

This document provides comprehensive guidance for testing the TKGI Application Tracker, including unit tests, integration tests, and end-to-end pipeline validation without requiring actual TKGI or Ops Manager connectivity.

## 🧪 Testing Philosophy

The test suite is designed with the following principles:

- **No External Dependencies**: All tests run with mocked TKGI/OM CLI responses
- **Comprehensive Coverage**: Unit, integration, and shell script tests
- **CI/CD Friendly**: Machine-readable output and fail-fast options
- **Local Development**: Easy to run locally with detailed feedback
- **Regression Prevention**: Ensures code changes don't break existing functionality

## 📋 Test Suite Overview

### Test Types

| Test Type | Purpose | Tools | Duration |
|-----------|---------|-------|----------|
| **Unit Tests** | Test individual functions and classes | Python unittest | ~30 seconds |
| **Integration Tests** | Test end-to-end pipeline flow | Bash + mocks | ~2 minutes |
| **Shell Tests** | Test bash utility functions | BATS | ~15 seconds |

### Test Structure

```
tests/
├── test-framework.sh              # Test framework with mocks and assertions
├── run-all-tests.sh              # Comprehensive test runner
├── test_aggregate_data.py        # Python unit tests for aggregation
├── test_generate_reports.py      # Python unit tests for reporting
├── test_pipeline_integration.sh  # End-to-end integration tests
├── test_foundation_utils.bats    # Shell tests for foundation utilities
├── test_helpers.bats             # Shell tests for helper functions
├── fixtures/                     # Mock data and test fixtures
│   ├── mock-namespace.json
│   ├── mock-pods.json
│   ├── mock-deployments.json
│   └── mock-services.json
└── output/                       # Test results and logs (gitignored)
```

## 🚀 Quick Start

### Run All Tests
```bash
# Complete test suite
make test

# With verbose output
make test VERBOSE=true
```

### Run Specific Test Types
```bash
# Python unit tests only
make test-unit

# Integration tests only
make test-integration

# Shell script tests only
make test-shell

# With coverage reporting
make test-coverage

# CI mode (fail fast, machine readable)
make test-ci
```

### Direct Test Runner Usage
```bash
# Run all tests with custom options
./tests/run-all-tests.sh --verbose --coverage

# Run specific test types
./tests/run-all-tests.sh --unit-only
./tests/run-all-tests.sh --integration-only --fail-fast

# CI mode
./tests/run-all-tests.sh --ci
```

## 🔬 Unit Tests

### Python Unit Tests

#### test_aggregate_data.py
Tests the data aggregation logic:

- **DataAggregator class**: Loading cluster data, application classification, migration readiness calculation
- **FoundationDataProcessor class**: Foundation parsing, grouping, and summary calculations  
- **Data validation**: Structure validation and error handling

```bash
# Run aggregation tests only
python3 tests/test_aggregate_data.py

# With coverage
python3 -m coverage run tests/test_aggregate_data.py
```

#### test_generate_reports.py  
Tests the report generation logic:

- **ReportGenerator class**: CSV and JSON report creation, filename generation
- **CSVReportWriter class**: CSV formatting and structure validation
- **JSONReportWriter class**: JSON serialization and structure
- **Report validation**: Data integrity and format validation

```bash
# Run report generation tests only
python3 tests/test_generate_reports.py
```

### Key Test Scenarios

- ✅ **Happy Path**: Normal data processing and report generation
- ✅ **Edge Cases**: Empty data, invalid JSON, missing fields
- ✅ **Error Handling**: Graceful failure with malformed input
- ✅ **Data Validation**: Schema compliance and type checking
- ✅ **Performance**: Large dataset handling (simulated)

## 🧩 Integration Tests

### Pipeline Integration Tests (test_pipeline_integration.sh)

Tests the complete pipeline flow with mocked dependencies:

#### Test Scenarios

1. **Data Collection**: Mocked kubectl/TKGI responses
2. **Data Aggregation**: Processing collected JSON data  
3. **Report Generation**: Creating CSV/JSON reports from aggregated data
4. **Excel Generation**: Creating Excel workbooks (if openpyxl available)
5. **End-to-End Flow**: Complete pipeline execution
6. **Error Handling**: Invalid data and missing dependencies
7. **Data Validation**: JSON structure and CSV format validation

#### Mock Environment

The integration tests create a complete mock environment:

- **Mock kubectl**: Returns realistic namespace, pod, deployment data
- **Mock om CLI**: Provides Ops Manager authentication responses  
- **Mock tkgi CLI**: Simulates TKGI login and cluster operations
- **Test Data**: Realistic JSON fixtures for all Kubernetes resources

```bash
# Run integration tests
./tests/test_pipeline_integration.sh

# With framework debugging
VERBOSE=true ./tests/test_pipeline_integration.sh
```

## 🐚 Shell Script Tests (BATS)

### Foundation Utilities Tests (test_foundation_utils.bats)

Tests foundation parsing and utility functions:

- Foundation name parsing (datacenter, environment, instance)
- Environment determination logic  
- Pipeline name generation
- Foundation validation
- Grouping and filtering functions

### Helper Functions Tests (test_helpers.bats)

Tests common helper functions:

- Logging and output functions
- Environment variable validation
- TKGI authentication flow (mocked)
- JSON parsing utilities
- Date/time calculations
- Namespace classification

```bash
# Run BATS tests (requires BATS installation)
bats tests/test_foundation_utils.bats
bats tests/test_helpers.bats

# Run all BATS tests
make test-shell
```

## 🎯 Mock System

### Mock CLI Tools

The test framework creates mock executable commands that simulate:

#### Mock kubectl
```bash
kubectl get namespaces     # Returns test namespace list
kubectl get pods          # Returns test pod data
kubectl get deployments   # Returns test deployment data  
kubectl get services      # Returns test service data
```

#### Mock om (Ops Manager CLI)
```bash
om configure-authentication  # Simulates OM auth setup
om credentials              # Returns test credentials
```

#### Mock tkgi CLI  
```bash
tkgi login                 # Simulates successful login
tkgi get-credentials       # Creates mock kubeconfig
tkgi clusters             # Returns test cluster list
```

### Test Data Fixtures

Realistic mock data located in `tests/fixtures/`:

- **mock-namespace.json**: Sample namespace with labels and annotations
- **mock-pods.json**: Pod list with various states and metadata
- **mock-deployments.json**: Deployment configurations and status
- **mock-services.json**: Service definitions and port configurations

### Environment Variables

Test environment uses safe mock values:

```bash
OM_TARGET=mock-opsman.test.local
OM_CLIENT_ID=test-client
OM_CLIENT_SECRET=test-secret  
TKGI_API_ENDPOINT=mock-pks.test.local
FOUNDATION=test-foundation
```

## 📊 Coverage Reporting

### Generate Coverage Reports

```bash
# Run tests with coverage
make test-coverage

# Manual coverage run
python3 -m coverage run --parallel-mode tests/test_aggregate_data.py
python3 -m coverage run --parallel-mode tests/test_generate_reports.py
python3 -m coverage combine
python3 -m coverage report
python3 -m coverage html
```

### Coverage Targets

- **Python Scripts**: Aim for >80% coverage
- **Critical Functions**: 100% coverage for core logic
- **Error Paths**: All error handling paths tested

## 🤖 CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install coverage
          
      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
          
      - name: Run test suite
        run: make test-ci
        
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        if: always()
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Setup') {
            steps {
                sh 'python3 -m pip install coverage'
            }
        }
        
        stage('Test') {
            steps {
                sh 'make test-ci'
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'tests/output/coverage-html',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
    }
}
```

## 🔧 Test Development

### Adding New Unit Tests

1. **Create test file**: `tests/test_new_module.py`
2. **Import module**: Add scripts to Python path
3. **Use unittest framework**: Inherit from `unittest.TestCase`
4. **Mock dependencies**: Use unittest.mock for external calls
5. **Add to test runner**: Update `run-all-tests.sh`

Example:
```python
#!/usr/bin/env python3

import unittest
import sys
import os

# Add scripts to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from your_module import YourClass

class TestYourClass(unittest.TestCase):
    def test_your_function(self):
        result = YourClass().your_function("test_input")
        self.assertEqual(result, "expected_output")

if __name__ == '__main__':
    unittest.main()
```

### Adding Integration Tests

1. **Add test function**: In `test_pipeline_integration.sh`
2. **Use test framework**: Source `test-framework.sh` 
3. **Create mock data**: Add fixtures as needed
4. **Use assertions**: `assert_equals`, `assert_file_exists`, etc.
5. **Register test**: Add to main() function

Example:
```bash
test_new_functionality() {
    echo "Testing new functionality..."
    
    local workspace="$TKGI_APP_TRACKER_TEST_WORKSPACE"
    
    # Setup test data
    create_test_input
    
    # Run functionality
    run_your_script
    
    # Validate results
    assert_file_exists "${workspace}/output.json" \
        "Should create output file"
        
    assert_json_valid "${workspace}/output.json" \
        "Output should be valid JSON"
}
```

### Adding Shell Tests (BATS)

1. **Create .bats file**: `tests/test_new_utils.bats`
2. **Source utilities**: Load the shell functions to test
3. **Write test cases**: Use BATS syntax
4. **Test edge cases**: Include error conditions

Example:
```bash
#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../scripts/new_utils.sh"
}

@test "new_function should return expected value" {
    result=$(new_function "input")
    [ "$result" = "expected" ]
}

@test "new_function should handle empty input" {
    run new_function ""
    [ "$status" -eq 1 ]
}
```

## 🐛 Debugging Tests

### Verbose Output
```bash
# Detailed test execution
make test VERBOSE=true

# Keep test output for inspection  
./tests/run-all-tests.sh --verbose --fail-fast
```

### Test Output Location
```bash
# Test logs and artifacts
ls tests/output/

# Coverage reports
open tests/output/coverage-html/index.html

# Individual test logs
cat tests/output/test_aggregate_data.log
```

### Common Issues

#### Python Import Errors
```bash
# Ensure scripts are in Python path
export PYTHONPATH="/path/to/tkgi-app-tracker/scripts:$PYTHONPATH"

# Check imports manually
python3 -c "from aggregate_data import DataAggregator"
```

#### Mock CLI Not Found
```bash
# Check PATH includes mock directory
echo $PATH

# Verify mocks are executable
ls -la tests/output/mocks/
```

#### BATS Tests Failing
```bash
# Install BATS if missing
sudo apt-get install bats  # Ubuntu/Debian
brew install bats         # macOS

# Run BATS tests directly
bats tests/test_foundation_utils.bats -v
```

## 📈 Test Metrics

### Success Criteria

- **All tests pass**: 100% pass rate required
- **Coverage threshold**: >80% for Python code
- **Performance**: Tests complete in <5 minutes
- **No external dependencies**: Tests run offline

### Monitoring

Track test metrics over time:

- Pass/fail rates by test type
- Test execution duration
- Code coverage percentage  
- Number of test cases

## 🎯 Best Practices

### Test Design

1. **Independent tests**: Each test should be self-contained
2. **Descriptive names**: Test names should explain what they verify
3. **Arrange-Act-Assert**: Clear test structure
4. **Mock external dependencies**: No real API calls
5. **Test edge cases**: Include error conditions and boundary values

### Test Maintenance  

1. **Keep tests updated**: Update mocks when APIs change
2. **Regular execution**: Run tests frequently during development
3. **Review coverage**: Ensure new code is tested
4. **Clean up**: Remove obsolete tests and fixtures

### Performance

1. **Fast execution**: Individual tests should run quickly
2. **Parallel execution**: Run tests concurrently where possible
3. **Resource cleanup**: Clean up temporary files and processes
4. **Efficient mocks**: Use lightweight mock responses

This comprehensive test suite provides confidence in code changes and ensures the TKGI Application Tracker functions correctly without requiring actual TKGI or Ops Manager infrastructure.