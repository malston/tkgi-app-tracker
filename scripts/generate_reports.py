#!/usr/bin/env python3

"""
Report Generator for TKGI Application Tracker
Generates CSV and JSON reports from aggregated data
"""

import json
import csv
import os
from datetime import datetime
from pathlib import Path


class ReportGenerator:
    """Generate various report formats"""
    
    def __init__(self, output_dir="reports"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def generate_application_report(self, applications, format='csv'):
        """Generate application report in specified format"""
        if format == 'csv':
            return self._generate_application_csv(applications)
        elif format == 'json':
            return self._generate_application_json(applications)
        else:
            raise ValueError(f"Unsupported format: {format}")
    
    def generate_cluster_report(self, clusters, format='csv'):
        """Generate cluster report"""
        if format == 'csv':
            return self._generate_cluster_csv(clusters)
        elif format == 'json':
            return self._generate_cluster_json(clusters)
        else:
            raise ValueError(f"Unsupported format: {format}")
    
    def generate_executive_summary(self, summary, format='csv'):
        """Generate executive summary"""
        if format == 'csv':
            return self._generate_summary_csv(summary)
        elif format == 'json':
            return self._generate_summary_json(summary)
        else:
            raise ValueError(f"Unsupported format: {format}")
    
    def generate_migration_priority_report(self, applications, format='csv'):
        """Generate migration priority report"""
        # Sort by migration readiness score
        sorted_apps = sorted(applications, 
                           key=lambda x: x.get('migration_readiness_score', 0), 
                           reverse=True)
        
        if format == 'csv':
            return self._generate_migration_csv(sorted_apps)
        elif format == 'json':
            return self._generate_migration_json(sorted_apps)
        else:
            raise ValueError(f"Unsupported format: {format}")
    
    def _generate_application_csv(self, applications):
        """Generate CSV report for applications"""
        csv_file = self.output_dir / f"application_report_{self.timestamp}.csv"
        
        headers = [
            'Application ID', 'Status', 'Environment', 'Foundations',
            'Clusters', 'Namespaces', 'Total Pods', 'Running Pods',
            'Deployments', 'Services', 'Last Activity', 'Days Since Activity',
            'Migration Readiness Score', 'Data Quality', 'Recommendation'
        ]
        
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            
            for app in applications:
                row = [
                    app.get('app_id', ''),
                    app.get('status', ''),
                    app.get('environment', ''),
                    ','.join(app.get('foundations', [])),
                    ','.join(app.get('clusters', [])),
                    ','.join(app.get('namespaces', [])),
                    app.get('pod_count', 0),
                    app.get('running_pods', 0),
                    app.get('deployment_count', 0),
                    app.get('service_count', 0),
                    app.get('last_activity', ''),
                    app.get('days_since_activity', ''),
                    app.get('migration_readiness_score', 0),
                    app.get('data_quality', 'Medium'),
                    app.get('recommendation', 'Needs Analysis')
                ]
                writer.writerow(row)
        
        return str(csv_file)
    
    def _generate_application_json(self, applications):
        """Generate JSON report for applications"""
        json_file = self.output_dir / f"application_report_{self.timestamp}.json"
        
        data = {
            'report_date': datetime.utcnow().isoformat() + 'Z',
            'total_count': len(applications),
            'applications': applications
        }
        
        with open(json_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return str(json_file)
    
    def _generate_cluster_csv(self, clusters):
        """Generate CSV report for clusters"""
        csv_file = self.output_dir / f"cluster_report_{self.timestamp}.csv"
        
        headers = [
            'Cluster', 'Foundation', 'Environment', 'Total Namespaces',
            'Application Namespaces', 'System Namespaces', 'Total Pods',
            'Running Pods', 'Total Applications'
        ]
        
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            
            for cluster in clusters:
                row = [
                    cluster.get('cluster', ''),
                    cluster.get('foundation', ''),
                    cluster.get('environment', ''),
                    cluster.get('total_namespaces', 0),
                    cluster.get('application_namespaces', 0),
                    cluster.get('system_namespaces', 0),
                    cluster.get('total_pods', 0),
                    cluster.get('running_pods', 0),
                    cluster.get('total_applications', 0)
                ]
                writer.writerow(row)
        
        return str(csv_file)
    
    def _generate_cluster_json(self, clusters):
        """Generate JSON report for clusters"""
        json_file = self.output_dir / f"cluster_report_{self.timestamp}.json"
        
        data = {
            'report_date': datetime.utcnow().isoformat() + 'Z',
            'total_clusters': len(clusters),
            'clusters': clusters
        }
        
        with open(json_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return str(json_file)
    
    def _generate_summary_csv(self, summary):
        """Generate CSV executive summary"""
        csv_file = self.output_dir / f"executive_summary_{self.timestamp}.csv"
        
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['Metric', 'Value'])
            
            for key, value in summary.items():
                # Convert key to readable format
                metric = key.replace('_', ' ').title()
                writer.writerow([metric, value])
        
        return str(csv_file)
    
    def _generate_summary_json(self, summary):
        """Generate JSON executive summary"""
        json_file = self.output_dir / f"executive_summary_{self.timestamp}.json"
        
        with open(json_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        return str(json_file)
    
    def _generate_migration_csv(self, applications):
        """Generate migration priority CSV"""
        csv_file = self.output_dir / f"migration_priority_{self.timestamp}.csv"
        
        headers = [
            'Priority', 'Application ID', 'Migration Readiness Score',
            'Status', 'Environment', 'Pod Count', 'Recommendation'
        ]
        
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            
            for idx, app in enumerate(applications, 1):
                row = [
                    idx,
                    app.get('app_id', ''),
                    app.get('migration_readiness_score', 0),
                    app.get('status', ''),
                    app.get('environment', ''),
                    app.get('pod_count', 0),
                    self._get_recommendation(app.get('migration_readiness_score', 0))
                ]
                writer.writerow(row)
        
        return str(csv_file)
    
    def _generate_migration_json(self, applications):
        """Generate migration priority JSON"""
        json_file = self.output_dir / f"migration_priority_{self.timestamp}.json"
        
        data = {
            'report_date': datetime.utcnow().isoformat() + 'Z',
            'total_applications': len(applications),
            'migration_priorities': [
                {
                    'priority': idx,
                    'app_id': app.get('app_id', ''),
                    'migration_readiness_score': app.get('migration_readiness_score', 0),
                    'status': app.get('status', ''),
                    'environment': app.get('environment', ''),
                    'recommendation': self._get_recommendation(app.get('migration_readiness_score', 0))
                }
                for idx, app in enumerate(applications, 1)
            ]
        }
        
        with open(json_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return str(json_file)
    
    def _get_recommendation(self, score):
        """Get migration recommendation based on score"""
        if score >= 80:
            return "Ready for Migration"
        elif score >= 60:
            return "Needs Planning"
        elif score >= 40:
            return "Needs Analysis"
        else:
            return "High Risk - Detailed Review Required"


class CSVReportWriter:
    """Specialized CSV report writer"""
    
    def __init__(self, output_dir="reports"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def write_application_report(self, applications):
        """Write application report to CSV"""
        csv_file = self.output_dir / f"application_report_{self.timestamp}.csv"
        
        with open(csv_file, 'w', newline='') as f:
            if applications:
                writer = csv.DictWriter(f, fieldnames=applications[0].keys())
                writer.writeheader()
                writer.writerows(applications)
        
        return str(csv_file)
    
    def write_executive_summary(self, summary):
        """Write executive summary to CSV"""
        csv_file = self.output_dir / f"executive_summary_{self.timestamp}.csv"
        
        with open(csv_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['Metric', 'Value'])
            for key, value in summary.items():
                writer.writerow([key, value])
        
        return str(csv_file)


class JSONReportWriter:
    """Specialized JSON report writer"""
    
    def __init__(self, output_dir="reports"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def write_report(self, report_name, data):
        """Write report to JSON file"""
        json_file = self.output_dir / f"{report_name}_{self.timestamp}.json"
        
        with open(json_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        return str(json_file)


def main():
    """Main entry point for report generation"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate TKGI reports')
    parser.add_argument('--input-dir', default='aggregated-data', help='Input directory with aggregated data')
    parser.add_argument('--output-dir', default='reports', help='Output directory for reports')
    parser.add_argument('--format', choices=['csv', 'json', 'both'], default='csv', help='Report format')
    
    args = parser.parse_args()
    
    generator = ReportGenerator(args.output_dir)
    
    # Load aggregated data
    input_path = Path(args.input_dir)
    
    try:
        with open(input_path / "applications.json", 'r') as f:
            app_data = json.load(f)
            applications = app_data.get('applications', [])
    except FileNotFoundError:
        print(f"No applications.json found in {args.input_dir}")
        applications = []
    
    try:
        with open(input_path / "summary.json", 'r') as f:
            summary = json.load(f)
    except FileNotFoundError:
        print(f"No summary.json found in {args.input_dir}")
        summary = {}
    
    # Generate reports
    formats = ['csv', 'json'] if args.format == 'both' else [args.format]
    
    for fmt in formats:
        if applications:
            app_report = generator.generate_application_report(applications, fmt)
            print(f"Generated application report: {app_report}")
            
            migration_report = generator.generate_migration_priority_report(applications, fmt)
            print(f"Generated migration priority report: {migration_report}")
        
        if summary:
            summary_report = generator.generate_executive_summary(summary, fmt)
            print(f"Generated executive summary: {summary_report}")
    
    return 0


if __name__ == "__main__":
    exit(main())