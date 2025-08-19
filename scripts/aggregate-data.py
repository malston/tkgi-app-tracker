#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timedelta
from collections import defaultdict
import argparse
from pathlib import Path

class DataAggregator:
    """Aggregates TKGI cluster data across multiple collections"""

    def __init__(self, data_dir="data", reports_dir="reports"):
        self.data_dir = Path(data_dir)
        self.reports_dir = Path(reports_dir)
        self.data_dir.mkdir(exist_ok=True)
        self.reports_dir.mkdir(exist_ok=True)

    def load_latest_data(self):
        """Load the most recent all_clusters JSON file"""
        json_files = list(self.data_dir.glob("all_clusters_*.json"))
        if not json_files:
            raise FileNotFoundError("No cluster data files found")

        latest_file = max(json_files, key=lambda f: f.stat().st_mtime)
        print(f"Loading data from: {latest_file}")

        with open(latest_file, 'r') as f:
            return json.load(f)

    def load_historical_data(self, days_back=90):
        """Load historical data for trending"""
        historical = []
        cutoff_date = datetime.now() - timedelta(days=days_back)

        for json_file in self.data_dir.glob("all_clusters_*.json"):
            file_time = datetime.fromtimestamp(json_file.stat().st_mtime)
            if file_time >= cutoff_date:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    historical.append({
                        'timestamp': file_time.isoformat(),
                        'file': json_file.name,
                        'data': data
                    })

        return sorted(historical, key=lambda x: x['timestamp'])

    def aggregate_by_application(self, data):
        """Aggregate namespace data by application ID"""
        apps = defaultdict(lambda: {
            'app_id': None,
            'namespaces': [],
            'foundations': set(),
            'environments': set(),
            'total_pods': 0,
            'running_pods': 0,
            'total_deployments': 0,
            'total_services': 0,
            'clusters': set(),
            'last_activity': None,
            'is_active': False,
            'data_quality': 'good'
        })

        for ns_data in data:
            # Skip system namespaces
            if ns_data.get('is_system', False):
                continue

            app_id = ns_data.get('app_id', 'unknown')
            if app_id == 'unknown':
                # Try to derive from namespace name
                app_id = self._extract_app_id_from_name(ns_data['namespace'])

            app = apps[app_id]
            app['app_id'] = app_id
            app['namespaces'].append(ns_data['namespace'])
            app['foundations'].add(ns_data.get('foundation', 'unknown'))
            app['environments'].add(ns_data.get('environment', 'unknown'))
            app['clusters'].add(ns_data.get('cluster_full', ns_data.get('cluster', 'unknown')))

            # Aggregate metrics
            app['total_pods'] += ns_data.get('pod_count', 0)
            app['running_pods'] += ns_data.get('running_pods', 0)
            app['total_deployments'] += ns_data.get('deployment_count', 0)
            app['total_services'] += ns_data.get('service_count', 0)

            # Track last activity
            last_activity = ns_data.get('last_activity')
            if last_activity and last_activity != 'unknown':
                if not app['last_activity'] or last_activity > app['last_activity']:
                    app['last_activity'] = last_activity

            # Check data quality
            if app_id == 'unknown' or not ns_data.get('labels'):
                app['data_quality'] = 'incomplete'

        # Convert sets to lists for JSON serialization
        for app_id, app in apps.items():
            app['foundations'] = list(app['foundations'])
            app['environments'] = list(app['environments'])
            app['clusters'] = list(app['clusters'])

            # Determine if app is active (has activity in last 30 days)
            if app['last_activity']:
                try:
                    last_activity_date = datetime.fromisoformat(app['last_activity'].replace('Z', '+00:00'))
                    days_since_activity = (datetime.now(last_activity_date.tzinfo) - last_activity_date).days
                    app['is_active'] = days_since_activity <= 30
                    app['days_since_activity'] = days_since_activity
                except:
                    app['is_active'] = False
                    app['days_since_activity'] = None

            # Calculate migration readiness score
            app['migration_readiness'] = self._calculate_migration_readiness(app)

        return dict(apps)

    def _extract_app_id_from_name(self, namespace_name):
        """Extract app ID from namespace name patterns"""
        import re

        # Common patterns: app-12345, app-12345-dev, acme-app-prod
        patterns = [
            r'^([a-zA-Z]+)-(\d{4,6})',  # app-12345
            r'^([a-zA-Z]+)-([a-zA-Z]+)-(\d{4,6})',  # acme-app-12345
        ]

        for pattern in patterns:
            match = re.match(pattern, namespace_name)
            if match:
                return '-'.join(match.groups()[:2])

        # If no pattern matches, use the namespace name prefix
        parts = namespace_name.split('-')
        if len(parts) > 1:
            return parts[0]

        return 'unknown'

    def _calculate_migration_readiness(self, app):
        """Calculate migration readiness score (0-100)"""
        score = 100

        # Deduct points for various factors
        if app['is_active']:
            score -= 30  # Active apps need more planning

        if app['running_pods'] > 10:
            score -= 20  # Large apps are complex
        elif app['running_pods'] > 5:
            score -= 10

        if 'production' in app['environments']:
            score -= 20  # Production apps need careful migration

        if app['total_services'] > 5:
            score -= 10  # Many services mean complex networking

        if app['data_quality'] == 'incomplete':
            score -= 15  # Poor metadata means more investigation needed

        # Boost score for inactive apps
        days_inactive = app.get('days_since_activity')
        if days_inactive and days_inactive > 60:
            score += 20  # Likely abandoned
        elif days_inactive and days_inactive > 30:
            score += 10

        return max(0, min(100, score))

    def aggregate_by_cluster(self, data):
        """Aggregate statistics by cluster"""
        clusters = defaultdict(lambda: {
            'cluster': None,
            'foundation': None,
            'environment': None,
            'total_namespaces': 0,
            'app_namespaces': 0,
            'system_namespaces': 0,
            'total_pods': 0,
            'running_pods': 0,
            'applications': set()
        })

        for ns_data in data:
            cluster_name = ns_data.get('cluster_full', ns_data.get('cluster', 'unknown'))
            cluster = clusters[cluster_name]

            cluster['cluster'] = cluster_name
            cluster['foundation'] = ns_data.get('foundation', 'unknown')
            cluster['environment'] = ns_data.get('environment', 'unknown')
            cluster['total_namespaces'] += 1

            if ns_data.get('is_system', False):
                cluster['system_namespaces'] += 1
            else:
                cluster['app_namespaces'] += 1
                app_id = ns_data.get('app_id', 'unknown')
                if app_id != 'unknown':
                    cluster['applications'].add(app_id)

            cluster['total_pods'] += ns_data.get('pod_count', 0)
            cluster['running_pods'] += ns_data.get('running_pods', 0)

        # Convert sets to lists
        for cluster in clusters.values():
            cluster['applications'] = list(cluster['applications'])
            cluster['application_count'] = len(cluster['applications'])

        return dict(clusters)

    def generate_summary(self, app_data, cluster_data):
        """Generate executive summary"""
        total_apps = len(app_data)
        active_apps = sum(1 for app in app_data.values() if app['is_active'])
        inactive_apps = total_apps - active_apps

        prod_apps = sum(1 for app in app_data.values() if 'production' in app['environments'])
        nonprod_apps = total_apps - prod_apps

        ready_for_migration = sum(1 for app in app_data.values() if app['migration_readiness'] >= 70)
        needs_analysis = sum(1 for app in app_data.values() if app['data_quality'] == 'incomplete')

        total_clusters = len(cluster_data)
        total_pods = sum(cluster['total_pods'] for cluster in cluster_data.values())

        summary = {
            'timestamp': datetime.now().isoformat(),
            'totals': {
                'applications': total_apps,
                'active_applications': active_apps,
                'inactive_applications': inactive_apps,
                'production_applications': prod_apps,
                'nonproduction_applications': nonprod_apps,
                'clusters': total_clusters,
                'total_pods': total_pods
            },
            'migration': {
                'ready_for_migration': ready_for_migration,
                'needs_planning': active_apps,
                'needs_metadata_analysis': needs_analysis
            },
            'by_foundation': {}
        }

        # Breakdown by foundation
        for foundation in ['dc01', 'dc02', 'dc03', 'dc04']:
            foundation_apps = [app for app in app_data.values() if foundation in app['foundations']]
            summary['by_foundation'][foundation] = {
                'applications': len(foundation_apps),
                'active': sum(1 for app in foundation_apps if app['is_active']),
                'inactive': sum(1 for app in foundation_apps if not app['is_active'])
            }

        return summary

    def save_aggregated_data(self, app_data, cluster_data, summary):
        """Save aggregated data to JSON files"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Save application aggregation
        app_file = self.reports_dir / f"applications_{timestamp}.json"
        with open(app_file, 'w') as f:
            json.dump(app_data, f, indent=2, default=str)
        print(f"Application data saved to: {app_file}")

        # Save cluster aggregation
        cluster_file = self.reports_dir / f"clusters_{timestamp}.json"
        with open(cluster_file, 'w') as f:
            json.dump(cluster_data, f, indent=2, default=str)
        print(f"Cluster data saved to: {cluster_file}")

        # Save summary
        summary_file = self.reports_dir / f"summary_{timestamp}.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"Summary saved to: {summary_file}")

        return app_file, cluster_file, summary_file

def main():
    parser = argparse.ArgumentParser(description='Aggregate TKGI application tracking data')
    parser.add_argument('-d', '--data-dir', default='data', help='Directory containing cluster data')
    parser.add_argument('-r', '--reports-dir', default='reports', help='Directory for output reports')
    parser.add_argument('--historical-days', type=int, default=90, help='Days of historical data to analyze')

    args = parser.parse_args()

    aggregator = DataAggregator(args.data_dir, args.reports_dir)

    try:
        # Load latest data
        print("Loading cluster data...")
        data = aggregator.load_latest_data()

        # Aggregate by application
        print("Aggregating by application...")
        app_data = aggregator.aggregate_by_application(data)

        # Aggregate by cluster
        print("Aggregating by cluster...")
        cluster_data = aggregator.aggregate_by_cluster(data)

        # Generate summary
        print("Generating summary...")
        summary = aggregator.generate_summary(app_data, cluster_data)

        # Save results
        print("Saving aggregated data...")
        aggregator.save_aggregated_data(app_data, cluster_data, summary)

        # Print summary
        print("\n" + "="*60)
        print("EXECUTIVE SUMMARY")
        print("="*60)
        print(f"Total Applications: {summary['totals']['applications']}")
        print(f"  Active: {summary['totals']['active_applications']}")
        print(f"  Inactive: {summary['totals']['inactive_applications']}")
        print(f"  Ready for Migration: {summary['migration']['ready_for_migration']}")
        print(f"  Needs Analysis: {summary['migration']['needs_metadata_analysis']}")
        print("="*60)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
