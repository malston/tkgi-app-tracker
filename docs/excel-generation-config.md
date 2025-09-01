# Excel Generation Configuration

## Overview

The generate-reports task now supports optional Excel workbook generation alongside the standard CSV and JSON reports. This feature is controlled by the `GENERATE_EXCEL` parameter.

## Configuration

### Task Parameter

The `GENERATE_EXCEL` parameter in `ci/tasks/generate-reports/task.yml`:

```yaml
params:
  GENERATE_EXCEL: "true"  # Set to "false" to skip Excel generation
```

### Default Behavior

- **Default Value**: `true` (Excel generation is enabled by default)
- **Accepted Values**: `"true"` or `"false"` (as strings)

## Pipeline Usage

### Using Default (Excel Enabled)

```yaml
- task: generate-reports
  file: tkgi-app-tracker-repo/ci/tasks/generate-reports/task.yml
  input_mapping:
    aggregated-data: aggregated-data
```

### Disabling Excel Generation

```yaml
- task: generate-reports
  file: tkgi-app-tracker-repo/ci/tasks/generate-reports/task.yml
  params:
    GENERATE_EXCEL: "false"
  input_mapping:
    aggregated-data: aggregated-data
```

### Conditional Excel Generation

You can make Excel generation conditional based on pipeline parameters:

```yaml
- task: generate-reports
  file: tkgi-app-tracker-repo/ci/tasks/generate-reports/task.yml
  params:
    GENERATE_EXCEL: ((excel_generation_enabled))
  input_mapping:
    aggregated-data: aggregated-data
```

## Generated Files

### With Excel Enabled (Default)

When `GENERATE_EXCEL="true"`, the task generates:

1. **CSV Reports**:
   - `application_report_*.csv` - Detailed application data
   - `cluster_report_*.csv` - Cluster statistics
   - `executive_summary_*.csv` - High-level summary
   - `migration_priority_*.csv` - Migration recommendations

2. **JSON Report**:
   - `complete_report_*.json` - Combined data for automation

3. **Excel Workbook**:
   - `TKGI_App_Tracker_Analysis_*.xlsx` - Multi-sheet workbook with:
     - Application data with formatting
     - Executive dashboard
     - Charts and visualizations
     - Pivot table instructions
     - Trend analysis templates

### With Excel Disabled

When `GENERATE_EXCEL="false"`, the task generates only:

1. **CSV Reports** (same as above)
2. **JSON Report** (same as above)

## Requirements

### Dependencies for Excel Generation

The Excel generation feature requires:

1. **Python Package**: `openpyxl`
   - Installation: `pip3 install openpyxl`
   - Required for Excel file creation and formatting

2. **Script Files**:
   - `scripts/generate-reports.py` - Main report generator
   - `scripts/generate-excel-template.py` - Excel workbook creator

3. **Sufficient Memory**: Excel generation uses more memory than CSV/JSON
   - Recommended: At least 512MB available RAM

## Performance Considerations

### Generation Time

- **CSV/JSON Only**: ~5-10 seconds
- **With Excel**: ~15-30 seconds (depends on data volume)

### File Sizes

- **CSV Reports**: ~100KB - 1MB each
- **JSON Report**: ~500KB - 5MB
- **Excel Workbook**: ~1MB - 10MB

### Resource Usage

Excel generation increases:

- CPU usage by ~20%
- Memory usage by ~100-200MB
- Disk I/O for writing formatted Excel file

## Troubleshooting

### Excel Generation Fails

**Symptom**: "Excel generation skipped - openpyxl not available"

**Solution**: Install openpyxl in the Docker image:

```dockerfile
RUN pip3 install openpyxl
```

### Excel File Not Created

**Symptom**: No .xlsx file in output despite `GENERATE_EXCEL="true"`

**Possible Causes**:

1. Missing `generate-excel-template.py` script
2. Insufficient permissions in output directory
3. Memory constraints

**Debug Steps**:

```bash
# Check if script exists
ls -la scripts/generate-excel-template.py

# Check permissions
ls -la generated-reports/reports/

# Run with verbose output
python3 generate-reports.py -r reports --excel --verbose
```

### Excel File Corrupted

**Symptom**: Excel shows "file is corrupted" error

**Possible Causes**:

1. Incomplete write due to disk space
2. Special characters in data
3. Version compatibility issues

**Solution**:

- Check disk space: `df -h`
- Validate JSON data: `jq empty reports/*.json`
- Update openpyxl: `pip3 install --upgrade openpyxl`

## Testing

### Manual Test

Run the test script to verify Excel generation:

```bash
./tests/test-excel-generation.sh
```

This tests:

1. Generation with `GENERATE_EXCEL="true"`
2. Generation with `GENERATE_EXCEL="false"`
3. Default value behavior

### Pipeline Test

Test in pipeline with parameter override:

```bash
fly -t tkgi-app-tracker execute \
  -c ci/tasks/generate-reports/task.yml \
  -i tkgi-app-tracker-repo=. \
  -i aggregated-data=./sample-data \
  -o generated-reports=./output \
  -v GENERATE_EXCEL="false"
```

## Best Practices

1. **Production Pipelines**: Keep Excel enabled for comprehensive reporting
2. **Development/Testing**: Disable Excel to speed up iterations
3. **Resource Constraints**: Disable if running in limited environments
4. **Archival**: Enable for monthly/quarterly reports that need analysis

## Migration from Previous Version

If upgrading from a version without this feature:

1. **No Pipeline Changes Required**: Default behavior generates Excel
2. **To Maintain Old Behavior**: Set `GENERATE_EXCEL: "false"`
3. **Backwards Compatible**: CSV/JSON generation unchanged

## Related Documentation

- [Excel Report Guide](./excel-report-guide.md) - Using the generated Excel workbook
- [Pipeline Architecture](./pipeline-architecture.md) - Overall pipeline design
- [Generate Reports Task](../ci/tasks/generate-reports/README.md) - Task documentation
