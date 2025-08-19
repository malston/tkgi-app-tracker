#!/usr/bin/env python3

import json
import csv
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
import argparse

class ReportGenerator:
    """Generate CSV and JSON reports for TKGI application tracking"""

    def __init__(self, reports_dir="reports"):
        self.reports_dir = Path(reports_dir)
        self.reports_dir.mkdir(exist_ok=True)

    def load_aggregated_data(self):
        """Load the latest aggregated application and cluster data"""
        # Find latest application data
        app_files = list(self.reports_dir.glob("applications_*.json"))
        if not app_files:
            raise FileNotFoundError("No application data files found")

        latest_app_file = max(app_files, key=lambda f: f.stat().st_mtime)
        print(f"Loading application data from: {latest_app_file}")

        with open(latest_app_file, 'r') as f:
            app_data = json.load(f)

        # Find latest cluster data
        cluster_files = list(self.reports_dir.glob("clusters_*.json"))
        if cluster_files:
            latest_cluster_file = max(cluster_files, key=lambda f: f.stat().st_mtime)
            with open(latest_cluster_file, 'r') as f:
                cluster_data = json.load(f)
        else:
            cluster_data = {}

        # Find latest summary
        summary_files = list(self.reports_dir.glob("summary_*.json"))
        if summary_files:
            latest_summary_file = max(summary_files, key=lambda f: f.stat().st_mtime)
            with open(latest_summary_file, 'r') as f:
                summary_data = json.load(f)
        else:
            summary_data = {}

        return app_data, cluster_data, summary_data

    def generate_application_csv(self, app_data):
        """Generate detailed application CSV report for Excel analysis"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_file = self.reports_dir / f"application_report_{timestamp}.csv"

        # Define CSV columns
        columns = [
            'Application ID',
            'Status',
            'Environment',
            'Foundations',
            'Clusters',
            'Namespaces',
            'Total Pods',
            'Running Pods',
            'Deployments',
            'Services',
            'Last Activity',
            'Days Since Activity',
            'Migration Readiness Score',
            'Data Quality',
            'Recommendation'
        ]

        with open(csv_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columns)
            writer.writeheader()

            for app_id, app in sorted(app_data.items()):
                # Determine recommendation
                recommendation = self._get_recommendation(app)

                # Format environment
                environments = app.get('environments', [])
                env_str = 'Mixed' if len(environments) > 1 else (environments[0] if environments else 'Unknown')

                row = {
                    'Application ID': app_id,
                    'Status': 'Active' if app.get('is_active', False) else 'Inactive',
                    'Environment': env_str.title(),
                    'Foundations': ', '.join(app.get('foundations', [])),
                    'Clusters': ', '.join(app.get('clusters', [])),
                    'Namespaces': ', '.join(app.get('namespaces', [])),
                    'Total Pods': app.get('total_pods', 0),
                    'Running Pods': app.get('running_pods', 0),
                    'Deployments': app.get('total_deployments', 0),
                    'Services': app.get('total_services', 0),
                    'Last Activity': app.get('last_activity', 'Unknown'),
                    'Days Since Activity': app.get('days_since_activity', ''),
                    'Migration Readiness Score': app.get('migration_readiness', 0),
                    'Data Quality': app.get('data_quality', 'unknown').title(),
                    'Recommendation': recommendation
                }
                writer.writerow(row)

        print(f"Application CSV report saved to: {csv_file}")
        return csv_file

    def generate_cluster_csv(self, cluster_data):
        """Generate cluster utilization CSV report"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_file = self.reports_dir / f"cluster_report_{timestamp}.csv"

        columns = [
            'Cluster',
            'Foundation',
            'Environment',
            'Total Namespaces',
            'Application Namespaces',
            'System Namespaces',
            'Total Applications',
            'Total Pods',
            'Running Pods',
            'Utilization'
        ]

        with open(csv_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columns)
            writer.writeheader()

            for cluster_name, cluster in sorted(cluster_data.items()):
                # Calculate utilization (simplified metric)
                utilization = 'Low'
                if cluster.get('total_pods', 0) > 100:
                    utilization = 'High'
                elif cluster.get('total_pods', 0) > 50:
                    utilization = 'Medium'

                row = {
                    'Cluster': cluster_name,
                    'Foundation': cluster.get('foundation', 'Unknown'),
                    'Environment': cluster.get('environment', 'Unknown').title(),
                    'Total Namespaces': cluster.get('total_namespaces', 0),
                    'Application Namespaces': cluster.get('app_namespaces', 0),
                    'System Namespaces': cluster.get('system_namespaces', 0),
                    'Total Applications': cluster.get('application_count', 0),
                    'Total Pods': cluster.get('total_pods', 0),
                    'Running Pods': cluster.get('running_pods', 0),
                    'Utilization': utilization
                }
                writer.writerow(row)

        print(f"Cluster CSV report saved to: {csv_file}")
        return csv_file

    def generate_executive_csv(self, summary_data, app_data):
        """Generate executive summary CSV for management"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_file = self.reports_dir / f"executive_summary_{timestamp}.csv"

        # Create summary rows
        rows = []

        # Overall metrics
        rows.append(['Metric', 'Value'])
        rows.append(['Report Date', datetime.now().strftime("%Y-%m-%d %H:%M")])
        rows.append(['Total Applications', summary_data.get('totals', {}).get('applications', 0)])
        rows.append(['Active Applications', summary_data.get('totals', {}).get('active_applications', 0)])
        rows.append(['Inactive Applications', summary_data.get('totals', {}).get('inactive_applications', 0)])
        rows.append(['Production Applications', summary_data.get('totals', {}).get('production_applications', 0)])
        rows.append(['Non-Production Applications', summary_data.get('totals', {}).get('nonproduction_applications', 0)])
        rows.append([''])

        # Migration readiness
        rows.append(['Migration Readiness', 'Count'])
        rows.append(['Ready for Migration (Score >= 70)', summary_data.get('migration', {}).get('ready_for_migration', 0)])
        rows.append(['Needs Planning (Active Apps)', summary_data.get('migration', {}).get('needs_planning', 0)])
        rows.append(['Needs Metadata Analysis', summary_data.get('migration', {}).get('needs_metadata_analysis', 0)])
        rows.append([''])

        # By foundation
        rows.append(['Foundation Breakdown', ''])
        rows.append(['Foundation', 'Total Apps', 'Active', 'Inactive'])
        for foundation, data in summary_data.get('by_foundation', {}).items():
            rows.append([
                foundation.upper(),
                data.get('applications', 0),
                data.get('active', 0),
                data.get('inactive', 0)
            ])

        # Write CSV
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            for row in rows:
                writer.writerow(row)

        print(f"Executive summary CSV saved to: {csv_file}")
        return csv_file

    def generate_migration_priority_csv(self, app_data):
        """Generate migration priority list CSV"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_file = self.reports_dir / f"migration_priority_{timestamp}.csv"

        # Sort apps by migration readiness score
        sorted_apps = sorted(
            app_data.items(),
            key=lambda x: x[1].get('migration_readiness', 0),
            reverse=True
        )

        columns = [
            'Priority',
            'Application ID',
            'Migration Score',
            'Status',
            'Environment',
            'Complexity',
            'Action Required'
        ]

        with open(csv_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columns)
            writer.writeheader()

            for priority, (app_id, app) in enumerate(sorted_apps, 1):
                # Determine complexity
                complexity = 'Low'
                if app.get('total_pods', 0) > 10 or app.get('total_services', 0) > 5:
                    complexity = 'High'
                elif app.get('total_pods', 0) > 5 or app.get('total_services', 0) > 2:
                    complexity = 'Medium'

                # Determine action
                score = app.get('migration_readiness', 0)
                if score >= 80:
                    action = 'Ready - Schedule Migration'
                elif score >= 60:
                    action = 'Review - Minor Planning Needed'
                elif score >= 40:
                    action = 'Analyze - Significant Planning Required'
                else:
                    action = 'Complex - Detailed Analysis Required'

                environments = app.get('environments', [])
                env_str = 'Mixed' if len(environments) > 1 else (environments[0] if environments else 'Unknown')

                row = {
                    'Priority': priority,
                    'Application ID': app_id,
                    'Migration Score': score,
                    'Status': 'Active' if app.get('is_active', False) else 'Inactive',
                    'Environment': env_str.title(),
                    'Complexity': complexity,
                    'Action Required': action
                }
                writer.writerow(row)

        print(f"Migration priority CSV saved to: {csv_file}")
        return csv_file

    def _get_recommendation(self, app):
        """Generate recommendation based on app characteristics"""
        score = app.get('migration_readiness', 0)
        is_active = app.get('is_active', False)
        days_inactive = app.get('days_since_activity')

        if score >= 80:
            if not is_active:
                return 'Immediate migration candidate - inactive app'
            else:
                return 'Good migration candidate - plan coordination'
        elif score >= 60:
            if days_inactive and days_inactive > 60:
                return 'Consider decommissioning if no longer needed'
            else:
                return 'Moderate complexity - needs planning'
        elif score >= 40:
            return 'Complex migration - detailed analysis required'
        else:
            if is_active and 'production' in app.get('environments', []):
                return 'Critical app - careful migration planning needed'
            else:
                return 'High complexity - consider phased approach'

    def generate_all_reports(self, include_excel=False):
        """Generate all report formats"""
        try:
            # Load data
            print("Loading aggregated data...")
            app_data, cluster_data, summary_data = self.load_aggregated_data()

            # Generate reports
            print("\nGenerating reports...")
            reports = {
                'application': self.generate_application_csv(app_data),
                'cluster': self.generate_cluster_csv(cluster_data),
                'executive': self.generate_executive_csv(summary_data, app_data),
                'migration': self.generate_migration_priority_csv(app_data)
            }

            # Also save combined JSON report
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            json_file = self.reports_dir / f"complete_report_{timestamp}.json"

            combined_data = {
                'timestamp': timestamp,
                'summary': summary_data,
                'applications': app_data,
                'clusters': cluster_data
            }

            with open(json_file, 'w') as f:
                json.dump(combined_data, f, indent=2, default=str)

            print(f"\nComplete JSON report saved to: {json_file}")

            # Generate Excel workbook if requested
            if include_excel:
                try:
                    print("\nGenerating Excel workbook...")
                    excel_file = self.generate_excel_workbook()
                    if excel_file:
                        reports['excel'] = excel_file
                except ImportError:
                    print("Excel generation skipped - openpyxl not available")
                    print("Install with: pip3 install openpyxl")
                except Exception as e:
                    print(f"Excel generation failed: {e}")

            return reports

        except Exception as e:
            print(f"Error generating reports: {e}", file=sys.stderr)
            raise

    def generate_excel_workbook(self):
        """Generate Excel workbook using the external script"""
        import subprocess

        script_dir = Path(__file__).parent
        excel_script = script_dir / "generate-excel-template.py"

        if not excel_script.exists():
            print("Excel generator script not found")
            return None

        # Run Excel generation script
        cmd = [
            "python3", str(excel_script),
            "--output-dir", str(self.reports_dir)
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            # Find generated Excel file
            excel_files = list(self.reports_dir.glob("TKGI_App_Tracker_Analysis_*.xlsx"))
            if excel_files:
                latest_excel = max(excel_files, key=lambda f: f.stat().st_mtime)
                return latest_excel
        else:
            print(f"Excel generation error: {result.stderr}")

        return None

def main():
    parser = argparse.ArgumentParser(description='Generate TKGI application tracking reports')
    parser.add_argument('-r', '--reports-dir', default='reports', help='Directory containing aggregated data and for output reports')
    parser.add_argument('-e', '--excel', action='store_true', help='Also generate Excel workbook with pivot tables and charts')

    args = parser.parse_args()

    generator = ReportGenerator(args.reports_dir)

    try:
        reports = generator.generate_all_reports(include_excel=args.excel)

        print("\n" + "="*60)
        print("REPORT GENERATION COMPLETE")
        print("="*60)
        print("Generated reports:")
        for report_type, path in reports.items():
            if report_type == 'excel':
                print(f"  {report_type.title()} Workbook: {path.name}")
            else:
                print(f"  {report_type.title()} CSV: {path.name}")
        print("="*60)

        if args.excel and 'excel' in reports:
            print("\nExcel Features:")
            print("  ✓ Application data with professional formatting")
            print("  ✓ Executive dashboard with key metrics")
            print("  ✓ Charts and visualizations")
            print("  ✓ Pivot table instructions")
            print("  ✓ Trend analysis template")
            print("\nOpen the Excel file and follow the 'Pivot Table Instructions'")
            print("sheet to create powerful analysis views.")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
