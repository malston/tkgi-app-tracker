# TKGI Application Tracker - Excel Report Guide

This document provides a comprehensive overview of each sheet in the TKGI Application Tracker Excel workbook, explaining their purpose, content, and how to use them effectively for application analysis and migration planning.

## 📊 Report Overview

The TKGI Application Tracker Excel workbook contains **5 sheets** designed to provide comprehensive insights into your Kubernetes application portfolio:

1. **Applications** - Raw application data
2. **Executive Dashboard** - High-level metrics and KPIs
3. **Charts & Analysis** - Visual analysis with charts and formulas
4. **Pivot Table Instructions** - Step-by-step guidance for creating pivot tables
5. **Trend Analysis** - Historical trends and migration tracking

---

## 📋 Sheet 1: Applications

**Purpose**: Contains the complete dataset of all applications discovered across TKGI clusters.

### Data Structure

This sheet contains one row per application with the following columns:

| Column | Description | Example Values |
|--------|-------------|----------------|
| **Application ID** | Unique identifier for the application | `app-web-frontend-001` |
| **Status** | Current operational status | `Active`, `Inactive` |
| **Environment** | Environment classification | `production`, `nonprod`, `lab` |
| **Foundations** | TKGI foundation(s) hosting the app | `dc01-k8s-n-01` |
| **Clusters** | Specific cluster names | `cluster-web-prod-01` |
| **Namespaces** | Kubernetes namespaces | `web-frontend`, `api-backend` |
| **Total Pods** | Total number of pods | `5` |
| **Running Pods** | Currently running pods | `4` |
| **Deployments** | Number of deployments | `2` |
| **Services** | Number of services | `3` |
| **Last Activity** | Most recent pod activity timestamp | `2025-08-15T10:30:00Z` |
| **Days Since Activity** | Days since last activity | `4` |
| **Migration Readiness Score** | Readiness score (0-100) | `85` |
| **Data Quality** | Completeness of metadata | `High`, `Medium`, `Low` |
| **Recommendation** | Migration guidance | `Ready for Migration`, `Needs Analysis` |

### Key Features

- **Professional formatting** with alternating row colors
- **Data validation** indicators for quality assessment
- **Sortable and filterable** data for custom analysis
- **Source data** for all pivot tables and charts

### Usage Tips

- Use **AutoFilter** to quickly find specific applications
- Sort by **Migration Readiness Score** to identify migration candidates
- Filter by **Environment** to focus on specific deployment tiers
- Look for **Inactive** applications with high **Days Since Activity** for decommissioning candidates

---

## 📈 Sheet 2: Executive Dashboard

**Purpose**: Provides high-level KPIs and summary metrics for executive reporting and decision-making.

### Key Metrics Section

Displays critical metrics in an easy-to-read grid format:

- **Total Applications**: Complete application count across all environments
- **Active Applications**: Currently operational applications
- **Inactive Applications**: Applications with no recent activity
- **Production Applications**: Apps running in production environments
- **Non-Production Applications**: Apps in staging, dev, or test environments
- **Ready for Migration**: Apps with migration readiness score ≥ 70
- **Needs Planning**: Active applications requiring migration planning
- **Needs Metadata Analysis**: Apps with incomplete or low-quality metadata

### Foundation Breakdown Table

Shows application distribution across TKGI foundations:

| Foundation | Total Apps | Active | Inactive | Active % |
|------------|------------|--------|----------|----------|
| DC01-K8S-L-01 | 28 | 17 | 11 | 61% |
| DC02-K8S-N-01 | 22 | 15 | 7 | 68% |

### Features

- **Automated calculations** using Excel formulas
- **Color-coded metrics** for visual impact
- **Print-ready format** for executive presentations
- **Date stamp** showing report generation time

### Usage Tips

- Use this sheet for **monthly executive reports**
- Track **migration progress** over time by comparing reports
- Identify **underutilized foundations** with high inactive app counts
- Focus on **high-value** production applications for priority migration planning

---

## 📊 Sheet 3: Charts & Analysis

**Purpose**: Provides visual analysis with interactive charts and summary data tables.

### Chart Data Tables

Auto-generated summary tables that feed the charts:

1. **Status Summary**
   - Active vs Inactive application counts
   - Uses formulas: `=COUNTIF(Applications!B:B,"Active")`

2. **Environment Distribution**
   - Applications by environment (Production, Non-Production, Lab)
   - Uses formulas: `=COUNTIF(Applications!C:C,"production")`

3. **Migration Readiness Ranges**
   - Groups applications by readiness score ranges
   - Uses formulas: `=COUNTIFS(Applications!I:I,">=80",Applications!I:I,"<=100")`

### Interactive Charts

#### 1. Application Status Distribution (Pie Chart)

- **Location**: Top-left section
- **Shows**: Proportion of Active vs Inactive applications
- **Use**: Quick health check of application portfolio

#### 2. Applications by Environment (Pie Chart)

- **Location**: Top-right section
- **Shows**: Distribution across Production, Non-Production, and Lab environments
- **Use**: Understand environment-specific migration scope

#### 3. Migration Readiness Distribution (Bar Chart)

- **Location**: Bottom section
- **Shows**: Applications grouped by readiness score ranges:
  - **Ready (80-100)**: Applications ready for immediate migration
  - **Planning (60-79)**: Applications needing migration planning
  - **Complex (40-59)**: Applications requiring detailed analysis
  - **High Risk (0-39)**: Applications needing significant work

### Features

- **Dynamic charts** that update when data changes
- **Formula-driven** data summaries for accuracy
- **Professional styling** suitable for presentations
- **Cross-references** to Applications sheet data

### Usage Tips

- Use charts in **migration planning presentations**
- Monitor **readiness distribution** to track preparation progress
- Identify **environment imbalances** that may affect migration timing
- Export charts to PowerPoint for stakeholder communications

---

## 📋 Sheet 4: Pivot Table Instructions

**Purpose**: Provides step-by-step guidance for creating powerful pivot table analyses.

### Quick Start Pivot Tables

#### 1. Application Summary by Environment

**Goal**: Understand application distribution across environments

- **Rows**: Environment
- **Columns**: Status
- **Values**: Application ID (Count)
- **Result**: Cross-tab showing active/inactive apps per environment

#### 2. Migration Readiness Analysis

**Goal**: Analyze migration readiness by environment

- **Rows**: Migration Readiness Score (grouped: 0-39, 40-59, 60-79, 80-100)
- **Columns**: Environment
- **Values**: Application ID (Count)
- **Result**: Readiness distribution by environment

#### 3. Foundation Utilization

**Goal**: Assess resource utilization across foundations

- **Rows**: Foundations
- **Values**: Total Pods (Sum), Running Pods (Sum)
- **Calculated Field**: Pod Utilization = Running Pods / Total Pods
- **Result**: Foundation capacity and utilization metrics

#### 4. Inactive Application Analysis

**Goal**: Identify decommissioning candidates

- **Filter**: Status = 'Inactive'
- **Rows**: Days Since Activity (grouped: 0-30, 31-60, 61-90, 90+)
- **Columns**: Environment
- **Result**: Age analysis of inactive applications

### Recommended Charts

- **Pie Chart**: Application Status Distribution
- **Bar Chart**: Applications by Foundation
- **Line Chart**: Migration Readiness Trends (with historical data)
- **Scatter Plot**: Pod Count vs Migration Readiness Score

### Data Refresh Instructions

1. Copy new CSV data to respective sheets
2. Right-click any pivot table > Refresh
3. Charts will automatically update

### Features

- **Copy-paste instructions** for easy implementation
- **Best practices** for pivot table design
- **Chart recommendations** for different analysis needs
- **Refresh procedures** for ongoing reporting

### Usage Tips

- Start with **Quick Start** examples before creating custom pivot tables
- Use **grouping features** to create meaningful ranges for numerical data
- **Save pivot table layouts** as templates for recurring reports
- **Combine multiple pivot tables** on the same sheet for dashboard-style reports

---

## 📈 Sheet 5: Trend Analysis

**Purpose**: Tracks migration progress and application trends over time using historical data.

### Data Structure

Contains weekly snapshot data with the following columns:

| Column | Description | Purpose |
|--------|-------------|---------|
| **Week Ending** | Date of the weekly snapshot | Time series tracking |
| **Total Applications** | Total app count for that week | Portfolio growth/shrinkage |
| **Active Applications** | Active app count | Operational health |
| **Inactive Applications** | Calculated: Total - Active | Decommissioning progress |
| **Ready for Migration** | Apps with readiness score ≥ 70 | Migration preparation |
| **Migrations Completed** | Cumulative migration count | Progress tracking |
| **Migration Rate** | Weekly migration velocity | Performance metric |

### Data Sources

1. **Historical JSON files** (if available) - Real historical data
2. **Template data** (fallback) - 12 weeks of sample trend data

### Features

- **Automated formulas** for calculated fields
- **Line chart** showing migration trends over time
- **Percentage formatting** for migration rates
- **12-week rolling window** for recent trend analysis

### Key Formulas

- **Inactive Applications**: `=B{row}-C{row}`
- **Migration Rate**: `=IF(C{row-1}=0,0,F{row}/C{row-1})`

### Usage Tips

- **Update weekly** with new data exports
- Use **trend lines** to project future migration completion
- Monitor **migration rate** to identify velocity changes
- Compare **readiness** vs **actual migrations** to identify bottlenecks

---

## 🎯 Best Practices

### For Analysis

1. **Start with Executive Dashboard** for high-level overview
2. **Use Applications sheet** for detailed drill-downs
3. **Create pivot tables** for custom analysis needs
4. **Reference Charts & Analysis** for visual presentations

### For Migration Planning

1. **Sort by Migration Readiness Score** to prioritize applications
2. **Filter by Environment** to plan environment-specific migrations
3. **Use Trend Analysis** to track progress and set realistic timelines
4. **Focus on Production applications** for initial migration waves

### For Reporting

1. **Executive Dashboard** for C-level stakeholders
2. **Charts & Analysis** for technical presentations
3. **Pivot tables** for detailed operational reports
4. **Trend Analysis** for progress tracking and forecasting

### Data Refresh Workflow

1. Generate new weekly reports using the pipeline
2. Copy fresh data to Applications sheet
3. Refresh all pivot tables (Data > Refresh All)
4. Update Trend Analysis with new weekly snapshot
5. Verify Executive Dashboard metrics are current

---

## 🔧 Technical Notes

### Formula References

- All charts use `Applications!` sheet references for data
- Executive Dashboard uses `COUNTIF` and `COUNTIFS` formulas
- Trend Analysis uses relative cell references for calculations

### File Format

- `.xlsx` format for full Excel compatibility
- Supports Excel 2016 and later versions
- Compatible with Excel Online and Google Sheets (with limitations)

### Performance Considerations

- Optimized for datasets up to 10,000 applications
- Pivot tables refresh automatically with data changes
- Charts are linked to summary tables for faster updates

---

## 📞 Support

For questions about using this Excel workbook:

1. Review the **Pivot Table Instructions** sheet for guidance
2. Check the **TKGI Application Tracker documentation**
3. Contact your platform engineering team for technical support

**Report Generated**: {current_date}
**Version**: TKGI Application Tracker v1.0
