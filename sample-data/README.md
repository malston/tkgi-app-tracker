# TKGI Application Tracker - Sample Data

This directory contains sample data generators and testing utilities for the TKGI Application Tracker Excel reporting functionality.

## Quick Start

Generate sample data and test Excel reports:

```bash
# Generate sample data and create Excel workbook
./test-excel-reports.sh

# Generate reproducible sample data with seed
./test-excel-reports.sh --seed 12345

# Clean existing data and regenerate
./test-excel-reports.sh --clean

# Verbose output
./test-excel-reports.sh -v

# Generate sample data only (without Excel reports)
./generate-sample-data.py

# Generate with custom seed
./generate-sample-data.py --seed 42
```

## Files

### Scripts

- **`generate-sample-data.py`** - Python script that creates realistic sample data
- **`test-excel-reports.sh`** - Bash script that generates data and creates Excel reports
- **`README.md`** - This documentation file

### Generated Data (Created by scripts)

- **`reports/`** - Directory containing generated sample data and reports
  - `applications_TIMESTAMP.json` - Sample application data
  - `clusters_TIMESTAMP.json` - Sample cluster statistics
  - `summary_TIMESTAMP.json` - Executive summary data
  - `historical_TIMESTAMP.json` - Historical trend data
  - `application_report_TIMESTAMP.csv` - Detailed application CSV report
  - `executive_summary_TIMESTAMP.csv` - Executive summary CSV
  - `migration_priority_TIMESTAMP.csv` - Migration priority list
  - `TKGI_App_Tracker_Analysis_TIMESTAMP.xlsx` - Excel workbook with pivot tables

## Sample Data Characteristics

### Applications (150 total)
- **Foundations**: 8 foundations across 4 datacenters (DC01, DC02, DC03, DC04)
- **Environments**: Lab, Non-Production, Production
- **Activity Status**: ~70% active, 30% inactive applications
- **Migration Readiness**: Realistic distribution across score ranges
- **Multi-Foundation Apps**: 15 applications deployed across multiple foundations

### Realistic Patterns
- **Application Naming**: Based on realistic business divisions (finance, hr, marketing, etc.)
- **Resource Distribution**: Production apps are larger than non-production
- **Data Quality**: 85% complete, 10% partial, 5% incomplete metadata
- **Historical Trends**: 12 weeks of simulated migration progress

### Migration Readiness Distribution
- **Ready (80-100)**: ~25% of applications
- **Planning (60-79)**: ~30% of applications  
- **Complex (40-59)**: ~30% of applications
- **High Risk (0-39)**: ~15% of applications

## Testing Excel Reports

After running the test script, you can:

1. **Open the Excel workbook** (`TKGI_App_Tracker_Analysis_*.xlsx`)
2. **Follow the 'Pivot Table Instructions' sheet** for guided analysis
3. **Test the Executive Dashboard** for management-level metrics
4. **Explore Charts & Analysis** sheet for visualizations
5. **Review Trend Analysis** for historical patterns

### Excel Features to Test

#### Pivot Tables
- Application summary by environment
- Migration readiness analysis
- Foundation utilization breakdown
- Inactive application analysis

#### Charts and Visualizations
- Application status distribution (pie charts)
- Migration readiness scores (bar charts)
- Foundation comparison charts
- Trend analysis (line charts)

#### Executive Dashboard
- Key performance indicators
- Foundation-level summaries
- Migration statistics
- Visual metric cards

## Customization

### Generate Different Data Scenarios

```bash
# Small dataset for quick testing
python3 generate-sample-data.py --output-dir small-test
# Edit the script to change application count

# Reproducible data for consistent testing
python3 generate-sample-data.py --seed 42

# Custom output location
python3 generate-sample-data.py --output-dir custom-location
```

### Modify Sample Data Parameters

Edit `generate-sample-data.py` to customize:

- **Application count**: Change the range in `generate_applications_data()`
- **Foundation list**: Modify the `self.foundations` dictionary
- **Application types**: Update `self.app_types` and `self.divisions`
- **Migration readiness algorithm**: Adjust scoring in `calculate_migration_readiness()`

## Integration with Main Scripts

The sample data is compatible with the main TKGI Application Tracker scripts:

```bash
# Generate CSV reports from sample data
cd ../scripts
python3 generate-reports.py --reports-dir ../sample-data/reports

# Generate Excel workbook from sample data  
python3 generate-excel-template.py --output-dir ../sample-data/reports

# Test local pipeline execution with sample data (using Docker-based testing)
make docker-test TASK=generate-reports
```

## Validation and Quality Assurance

The sample data includes:

✅ **Realistic Application Patterns**: Based on common enterprise application types  
✅ **Proper Migration Scoring**: Uses the same algorithm as the production system  
✅ **Multi-Environment Coverage**: Lab, nonprod, and production scenarios  
✅ **Edge Cases**: Inactive apps, multi-foundation deployments, data quality issues  
✅ **Historical Context**: 12 weeks of trend data for timeline analysis  
✅ **Statistical Distribution**: Balanced across all score ranges and environments  

## Troubleshooting

### Common Issues

**Excel generation fails:**
```bash
# Install required dependency
pip3 install openpyxl
```

**Permission errors:**
```bash
# Ensure scripts are executable
chmod +x *.sh *.py
```

**Missing dependencies:**
```bash
# Check Python availability
python3 --version
which python3
```

**Data validation errors:**
```bash
# Check generated JSON files
ls -la reports/*.json
jq . reports/applications_*.json | head -20
```

This sample data system provides comprehensive testing capabilities for all Excel reporting features while maintaining realistic business scenarios and edge cases.