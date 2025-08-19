#!/usr/bin/env python3

"""
Sample Data Generator for TKGI Application Tracker
Creates realistic test data for Excel report testing and validation
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
import random

class SampleDataGenerator:
    """Generate realistic sample data for testing"""

    def __init__(self, output_dir="."):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

        # Create reports subdirectory for compatibility - directly under output_dir
        self.reports_dir = self.output_dir / "reports"
        self.reports_dir.mkdir(exist_ok=True)

        # Sample data configuration - Generic datacenter references
        self.foundations = {
            'dc01-k8s-n-01': {'datacenter': 'dc01', 'environment': 'lab', 'clusters': 5},
            'dc01-k8s-n-02': {'datacenter': 'dc01', 'environment': 'lab', 'clusters': 3},
            'dc02-k8s-n-01': {'datacenter': 'dc02', 'environment': 'nonprod', 'clusters': 8},
            'dc02-k8s-n-02': {'datacenter': 'dc02', 'environment': 'nonprod', 'clusters': 6},
            'dc03-k8s-p-01': {'datacenter': 'dc03', 'environment': 'prod', 'clusters': 12},
            'dc03-k8s-p-02': {'datacenter': 'dc03', 'environment': 'prod', 'clusters': 10},
            'dc04-k8s-p-01': {'datacenter': 'dc04', 'environment': 'prod', 'clusters': 15},
            'dc04-k8s-p-02': {'datacenter': 'dc04', 'environment': 'prod', 'clusters': 8}
        }

        # Application patterns
        self.app_types = [
            'web-portal', 'api-gateway', 'user-service', 'payment-service',
            'inventory-mgmt', 'order-processor', 'notification-hub', 'analytics-engine',
            'reporting-service', 'auth-service', 'file-processor', 'data-pipeline',
            'monitoring-dashboard', 'config-service', 'backup-utility', 'batch-processor'
        ]

        # Business divisions for realistic app naming
        self.divisions = ['finance', 'hr', 'marketing', 'sales', 'operations', 'it', 'legal', 'procurement']

    def generate_app_id(self):
        """Generate realistic application ID"""
        division = random.choice(self.divisions)
        app_type = random.choice(self.app_types)
        number = random.randint(1, 999)
        return f"{division}-{app_type}-{number:03d}"

    def generate_cluster_name(self, foundation):
        """Generate cluster names for a foundation"""
        datacenter = self.foundations[foundation]['datacenter']
        env_suffix = 'n' if self.foundations[foundation]['environment'] == 'nonprod' else 'p'
        if self.foundations[foundation]['environment'] == 'lab':
            env_suffix = 'l'

        clusters = []
        cluster_count = self.foundations[foundation]['clusters']
        for i in range(1, cluster_count + 1):
            cluster_name = f"{datacenter}-cluster-{env_suffix}-{i:02d}"
            clusters.append(cluster_name)

        return clusters

    def calculate_migration_readiness(self, app_data):
        """Calculate migration readiness score using same algorithm as main system"""
        score = 100

        # Deduct points for various factors
        if app_data['is_active']:
            score -= 30  # Active apps need more planning

        if app_data['running_pods'] > 10:
            score -= 20  # Large apps are complex
        elif app_data['running_pods'] > 5:
            score -= 10

        if app_data['environment'] == 'production':
            score -= 20  # Production apps need careful migration

        if app_data['total_services'] > 5:
            score -= 10  # Many services mean complex networking

        if app_data['data_quality'] == 'incomplete':
            score -= 15  # Poor metadata means more investigation needed

        # Boost score for inactive apps
        days_inactive = app_data.get('days_since_activity')
        if days_inactive and days_inactive > 60:
            score += 20  # Likely abandoned
        elif days_inactive and days_inactive > 30:
            score += 10

        return max(0, min(100, score))

    def generate_applications_data(self):
        """Generate comprehensive application dataset"""
        applications = {}

        # Generate 150 applications across all foundations
        for _ in range(150):
            app_id = self.generate_app_id()

            # Ensure unique app IDs
            while app_id in applications:
                app_id = self.generate_app_id()

            # Pick random foundation and environment
            foundation = random.choice(list(self.foundations.keys()))
            foundation_info = self.foundations[foundation]

            # Determine if app is active (70% chance)
            is_active = random.random() < 0.7

            # Generate activity timing
            if is_active:
                last_activity = datetime.now() - timedelta(days=random.randint(0, 30))
                days_since_activity = (datetime.now() - last_activity).days
            else:
                last_activity = datetime.now() - timedelta(days=random.randint(31, 180))
                days_since_activity = (datetime.now() - last_activity).days

            # Generate resource counts based on app characteristics
            if foundation_info['environment'] == 'prod':
                # Production apps tend to be larger
                running_pods = random.randint(1, 25) if is_active else 0
                total_services = random.randint(1, 12)
                total_deployments = random.randint(1, 8)
            else:
                # Non-prod apps are typically smaller
                running_pods = random.randint(1, 15) if is_active else 0
                total_services = random.randint(1, 8)
                total_deployments = random.randint(1, 5)

            total_pods = running_pods + random.randint(0, 3)  # Some pods might be pending/failed

            # Assign data quality (85% complete, 10% partial, 5% incomplete)
            data_quality_rand = random.random()
            if data_quality_rand < 0.85:
                data_quality = 'complete'
            elif data_quality_rand < 0.95:
                data_quality = 'partial'
            else:
                data_quality = 'incomplete'

            # Create application record
            app_data = {
                'app_id': app_id,
                'is_active': is_active,
                'last_activity': last_activity.isoformat(),
                'days_since_activity': days_since_activity,
                'foundations': [foundation],
                'clusters': [random.choice(self.generate_cluster_name(foundation))],
                'namespaces': [f"{app_id}-{foundation_info['environment']}"],
                'environments': [foundation_info['environment']],
                'environment': foundation_info['environment'],  # For scoring algorithm
                'total_pods': total_pods,
                'running_pods': running_pods,
                'total_deployments': total_deployments,
                'total_services': total_services,
                'data_quality': data_quality
            }

            # Calculate migration readiness score
            app_data['migration_readiness'] = self.calculate_migration_readiness(app_data)

            applications[app_id] = app_data

        # Add some multi-foundation apps (apps deployed across multiple foundations)
        multi_foundation_apps = random.sample(list(applications.keys()), 15)
        for app_id in multi_foundation_apps:
            app = applications[app_id]

            # Add a second foundation
            additional_foundation = random.choice(list(self.foundations.keys()))
            if additional_foundation not in app['foundations']:
                app['foundations'].append(additional_foundation)
                app['clusters'].append(random.choice(self.generate_cluster_name(additional_foundation)))

                # Update environment if it's now mixed
                additional_env = self.foundations[additional_foundation]['environment']
                if additional_env not in app['environments']:
                    app['environments'].append(additional_env)

        return applications

    def generate_clusters_data(self, applications):
        """Generate cluster-level statistics"""
        clusters = {}

        for foundation, foundation_info in self.foundations.items():
            cluster_names = self.generate_cluster_name(foundation)

            for cluster_name in cluster_names:
                # Find apps in this cluster
                cluster_apps = []
                total_namespaces = random.randint(15, 40)  # Mix of system and app namespaces
                app_namespaces = 0
                total_pods = 0
                running_pods = 0

                for app_id, app in applications.items():
                    if cluster_name in app['clusters']:
                        cluster_apps.append(app_id)
                        app_namespaces += 1
                        total_pods += app['total_pods']
                        running_pods += app['running_pods']

                # Add some base load for system namespaces
                total_pods += random.randint(20, 50)  # System pods
                running_pods += random.randint(18, 48)  # Most system pods are running

                clusters[cluster_name] = {
                    'cluster': cluster_name,
                    'foundation': foundation,
                    'environment': foundation_info['environment'],
                    'total_namespaces': total_namespaces,
                    'app_namespaces': app_namespaces,
                    'system_namespaces': total_namespaces - app_namespaces,
                    'applications': cluster_apps,
                    'application_count': len(cluster_apps),
                    'total_pods': total_pods,
                    'running_pods': running_pods
                }

        return clusters

    def generate_summary_data(self, applications, clusters):
        """Generate executive summary statistics"""
        total_apps = len(applications)
        active_apps = sum(1 for app in applications.values() if app['is_active'])
        inactive_apps = total_apps - active_apps

        prod_apps = sum(1 for app in applications.values() if 'production' in app['environments'])
        nonprod_apps = sum(1 for app in applications.values() if 'nonprod' in app['environments'])
        lab_apps = sum(1 for app in applications.values() if 'lab' in app['environments'])

        ready_for_migration = sum(1 for app in applications.values() if app['migration_readiness'] >= 70)
        needs_analysis = sum(1 for app in applications.values() if app['data_quality'] == 'incomplete')

        total_clusters = len(clusters)
        total_pods = sum(cluster['total_pods'] for cluster in clusters.values())

        # Foundation-level breakdown
        by_foundation = {}
        for foundation in self.foundations.keys():
            foundation_apps = [app for app in applications.values() if foundation in app['foundations']]
            active_count = sum(1 for app in foundation_apps if app['is_active'])

            by_foundation[foundation] = {
                'applications': len(foundation_apps),
                'active': active_count,
                'inactive': len(foundation_apps) - active_count
            }

        summary = {
            'timestamp': datetime.now().isoformat(),
            'totals': {
                'applications': total_apps,
                'active_applications': active_apps,
                'inactive_applications': inactive_apps,
                'production_applications': prod_apps,
                'nonproduction_applications': nonprod_apps,
                'lab_applications': lab_apps,
                'clusters': total_clusters,
                'total_pods': total_pods
            },
            'migration': {
                'ready_for_migration': ready_for_migration,
                'needs_planning': active_apps,
                'needs_metadata_analysis': needs_analysis
            },
            'by_foundation': by_foundation
        }

        return summary

    def generate_historical_data(self, applications):
        """Generate historical trend data for the last 12 weeks"""
        historical_data = []

        for week in range(12, 0, -1):  # 12 weeks ago to present
            week_date = datetime.now() - timedelta(weeks=week)

            # Simulate gradual migration progress
            migration_progress = (12 - week) * 0.05  # 5% improvement per week

            # Simulate some applications becoming ready over time
            base_ready = sum(1 for app in applications.values() if app['migration_readiness'] >= 70)
            weekly_ready = int(base_ready * (1 + migration_progress))

            # Simulate some migrations completed (remove from active count)
            migrations_completed = int((12 - week) * 2)  # 2 per week

            weekly_data = {
                'week_ending': week_date.strftime('%Y-%m-%d'),
                'total_applications': len(applications) + migrations_completed,  # Higher in the past
                'active_applications': sum(1 for app in applications.values() if app['is_active']) + migrations_completed,
                'ready_for_migration': weekly_ready,
                'migrations_completed_week': 2 if week < 12 else 0,
                'migrations_completed_total': migrations_completed
            }

            historical_data.append(weekly_data)

        return historical_data

    def save_data_files(self, applications, clusters, summary, historical):
        """Save all generated data to files"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Save applications data (for aggregation script compatibility)
        apps_file = self.reports_dir / f"applications_{timestamp}.json"
        with open(apps_file, 'w') as f:
            json.dump(applications, f, indent=2, default=str)

        # Save clusters data
        clusters_file = self.reports_dir / f"clusters_{timestamp}.json"
        with open(clusters_file, 'w') as f:
            json.dump(clusters, f, indent=2, default=str)

        # Save summary data
        summary_file = self.reports_dir / f"summary_{timestamp}.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2, default=str)

        # Save historical data
        historical_file = self.reports_dir / f"historical_{timestamp}.json"
        with open(historical_file, 'w') as f:
            json.dump(historical, f, indent=2, default=str)

        # Create a combined report for completeness
        combined_report = {
            'timestamp': timestamp,
            'summary': summary,
            'applications': applications,
            'clusters': clusters,
            'historical': historical
        }

        combined_file = self.reports_dir / f"complete_report_{timestamp}.json"
        with open(combined_file, 'w') as f:
            json.dump(combined_report, f, indent=2, default=str)

        return {
            'applications': apps_file,
            'clusters': clusters_file,
            'summary': summary_file,
            'historical': historical_file,
            'combined': combined_file
        }

    def print_summary_stats(self, applications, summary):
        """Print summary statistics for verification"""
        print("\n" + "="*60)
        print("SAMPLE DATA GENERATION SUMMARY")
        print("="*60)

        print(f"Total Applications: {len(applications)}")
        print(f"Active Applications: {summary['totals']['active_applications']}")
        print(f"Inactive Applications: {summary['totals']['inactive_applications']}")
        print("")

        print("By Environment:")
        print(f"  Production: {summary['totals']['production_applications']}")
        print(f"  Non-Production: {summary['totals']['nonproduction_applications']}")
        print(f"  Lab: {summary['totals']['lab_applications']}")
        print("")

        print("Migration Readiness Distribution:")
        ready_80_plus = sum(1 for app in applications.values() if app['migration_readiness'] >= 80)
        ready_60_79 = sum(1 for app in applications.values() if 60 <= app['migration_readiness'] < 80)
        ready_40_59 = sum(1 for app in applications.values() if 40 <= app['migration_readiness'] < 60)
        ready_0_39 = sum(1 for app in applications.values() if app['migration_readiness'] < 40)

        print(f"  Ready (80-100): {ready_80_plus} ({ready_80_plus/len(applications)*100:.1f}%)")
        print(f"  Planning (60-79): {ready_60_79} ({ready_60_79/len(applications)*100:.1f}%)")
        print(f"  Complex (40-59): {ready_40_59} ({ready_40_59/len(applications)*100:.1f}%)")
        print(f"  High Risk (0-39): {ready_0_39} ({ready_0_39/len(applications)*100:.1f}%)")
        print("")

        print("By Foundation:")
        for foundation, stats in summary['by_foundation'].items():
            print(f"  {foundation}: {stats['applications']} apps ({stats['active']} active, {stats['inactive']} inactive)")

        print("="*60)

    def generate_all_sample_data(self):
        """Generate complete sample dataset"""
        print("Generating sample data for TKGI Application Tracker...")

        # Generate core data
        print("  → Creating application data...")
        applications = self.generate_applications_data()

        print("  → Creating cluster statistics...")
        clusters = self.generate_clusters_data(applications)

        print("  → Creating executive summary...")
        summary = self.generate_summary_data(applications, clusters)

        print("  → Creating historical trends...")
        historical = self.generate_historical_data(applications)

        print("  → Saving data files...")
        files = self.save_data_files(applications, clusters, summary, historical)

        # Print summary
        self.print_summary_stats(applications, summary)

        print("\nGenerated Files:")
        for file_type, file_path in files.items():
            print(f"  {file_type.title()}: {file_path.name}")

        return files

def main():
    """Main function"""
    import argparse

    parser = argparse.ArgumentParser(description='Generate sample data for TKGI Application Tracker testing')
    parser.add_argument('-o', '--output-dir', default='.',
                       help='Output directory for sample data (default: current directory)')
    parser.add_argument('--seed', type=int, help='Random seed for reproducible data generation')

    args = parser.parse_args()

    # Set random seed if provided
    if args.seed:
        random.seed(args.seed)
        print(f"Using random seed: {args.seed}")

    try:
        generator = SampleDataGenerator(args.output_dir)
        files = generator.generate_all_sample_data()

        print(f"\n✅ Sample data generation complete!")
        print(f"   Output directory: {args.output_dir}")
        print(f"   Ready for Excel report testing!")

    except Exception as e:
        print(f"❌ Error generating sample data: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
