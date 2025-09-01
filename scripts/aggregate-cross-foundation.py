#!/usr/bin/env python3

"""
Cross-Foundation Data Aggregator

This script combines CSV reports from multiple foundations into a single
consolidated dataset for cross-foundation Excel workbook generation.

It reads the latest CSV reports from each foundation and creates unified
datasets that can be used to generate a comprehensive Excel workbook.
"""

import argparse
import json
import pandas as pd
from pathlib import Path
from datetime import datetime
import sys
import logging

class CrossFoundationAggregator:
    """Aggregates data from multiple foundation CSV reports"""

    def __init__(self, foundation_reports_dir, output_dir=None):
        self.foundation_reports_dir = Path(foundation_reports_dir)
        self.output_dir = Path(output_dir) if output_dir else self.foundation_reports_dir / "consolidated"
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Setup logging
        logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
        self.logger = logging.getLogger(__name__)

    def discover_foundation_reports(self):
        """Discover CSV reports from each foundation directory"""
        foundation_data = {}

        # Look for foundation directories
        for foundation_dir in self.foundation_reports_dir.glob("*/"):
            if not foundation_dir.is_dir():
                continue

            foundation_name = foundation_dir.name
            if foundation_name in ['consolidated', 'data']:  # Skip non-foundation dirs
                continue

            self.logger.info(f"Discovering reports in foundation: {foundation_name}")

            # Find CSV files in this foundation
            csv_files = {
                'applications': None,
                'clusters': None,
                'executive_summary': None,
                'migration_priority': None
            }

            for csv_file in foundation_dir.glob("*.csv"):
                filename = csv_file.name.lower()
                if 'application_report' in filename:
                    csv_files['applications'] = csv_file
                elif 'cluster_report' in filename:
                    csv_files['clusters'] = csv_file
                elif 'executive_summary' in filename:
                    csv_files['executive_summary'] = csv_file
                elif 'migration_priority' in filename:
                    csv_files['migration_priority'] = csv_file

            # Count available reports
            available_reports = sum(1 for f in csv_files.values() if f is not None)
            self.logger.info(f"  Found {available_reports}/4 report types for {foundation_name}")

            if available_reports > 0:
                foundation_data[foundation_name] = csv_files
            else:
                self.logger.warning(f"  No CSV reports found for {foundation_name}")

        return foundation_data

    def load_and_combine_applications(self, foundation_data):
        """Load and combine application reports from all foundations"""
        self.logger.info("Combining application reports...")

        combined_apps = []
        foundation_stats = {}

        for foundation, files in foundation_data.items():
            if files['applications'] is None:
                self.logger.warning(f"No application report found for {foundation}")
                continue

            try:
                df = pd.read_csv(files['applications'])

                # Add foundation column if not present
                if 'Foundation' not in df.columns:
                    df['Foundation'] = foundation

                # Ensure consistent column names
                df.columns = [col.strip().replace(' ', '_').lower() for col in df.columns]

                # Track stats
                foundation_stats[foundation] = {
                    'total_applications': len(df),
                    'active_applications': len(df[df.get('is_active', True) == True]) if 'is_active' in df.columns else len(df),
                    'file_path': str(files['applications'])
                }

                combined_apps.append(df)
                self.logger.info(f"  {foundation}: {len(df)} applications")

            except Exception as e:
                self.logger.error(f"Failed to load applications from {foundation}: {e}")

        if not combined_apps:
            raise ValueError("No application data could be loaded from any foundation")

        # Combine all dataframes
        combined_df = pd.concat(combined_apps, ignore_index=True)

        # Sort by foundation, then by app_id
        if 'foundation' in combined_df.columns and 'app_id' in combined_df.columns:
            combined_df = combined_df.sort_values(['foundation', 'app_id'])

        self.logger.info(f"Combined total: {len(combined_df)} applications across {len(foundation_stats)} foundations")

        return combined_df, foundation_stats

    def load_and_combine_clusters(self, foundation_data):
        """Load and combine cluster reports from all foundations"""
        self.logger.info("Combining cluster reports...")

        combined_clusters = []

        for foundation, files in foundation_data.items():
            if files['clusters'] is None:
                self.logger.warning(f"No cluster report found for {foundation}")
                continue

            try:
                df = pd.read_csv(files['clusters'])

                # Add foundation column if not present
                if 'Foundation' not in df.columns:
                    df['Foundation'] = foundation

                # Ensure consistent column names
                df.columns = [col.strip().replace(' ', '_').lower() for col in df.columns]

                combined_clusters.append(df)
                self.logger.info(f"  {foundation}: {len(df)} clusters")

            except Exception as e:
                self.logger.error(f"Failed to load clusters from {foundation}: {e}")

        if not combined_clusters:
            self.logger.warning("No cluster data could be loaded from any foundation")
            return pd.DataFrame()

        # Combine all dataframes
        combined_df = pd.concat(combined_clusters, ignore_index=True)

        # Sort by foundation, then by cluster
        if 'foundation' in combined_df.columns and 'cluster' in combined_df.columns:
            combined_df = combined_df.sort_values(['foundation', 'cluster'])

        self.logger.info(f"Combined total: {len(combined_df)} clusters")

        return combined_df

    def load_and_combine_migration_priority(self, foundation_data):
        """Load and combine migration priority reports from all foundations"""
        self.logger.info("Combining migration priority reports...")

        combined_migration = []

        for foundation, files in foundation_data.items():
            if files['migration_priority'] is None:
                self.logger.warning(f"No migration priority report found for {foundation}")
                continue

            try:
                df = pd.read_csv(files['migration_priority'])

                # Add foundation column if not present
                if 'Foundation' not in df.columns:
                    df['Foundation'] = foundation

                # Ensure consistent column names
                df.columns = [col.strip().replace(' ', '_').lower() for col in df.columns]

                combined_migration.append(df)
                self.logger.info(f"  {foundation}: {len(df)} migration candidates")

            except Exception as e:
                self.logger.error(f"Failed to load migration priority from {foundation}: {e}")

        if not combined_migration:
            self.logger.warning("No migration priority data could be loaded from any foundation")
            return pd.DataFrame()

        # Combine all dataframes
        combined_df = pd.concat(combined_migration, ignore_index=True)

        # Sort by migration_readiness descending, then by foundation
        if 'migration_readiness' in combined_df.columns:
            combined_df = combined_df.sort_values(['migration_readiness', 'foundation'], ascending=[False, True])

        self.logger.info(f"Combined total: {len(combined_df)} migration candidates")

        return combined_df

    def generate_cross_foundation_summary(self, foundation_stats, apps_df, clusters_df):
        """Generate cross-foundation executive summary"""
        self.logger.info("Generating cross-foundation summary...")

        summary_data = []

        # Per-foundation summary
        for foundation, stats in foundation_stats.items():
            foundation_apps = apps_df[apps_df['foundation'] == foundation] if 'foundation' in apps_df.columns else pd.DataFrame()
            foundation_clusters = clusters_df[clusters_df['foundation'] == foundation] if 'foundation' in clusters_df.columns and not clusters_df.empty else pd.DataFrame()

            # Calculate metrics
            total_apps = len(foundation_apps)
            active_apps = len(foundation_apps[foundation_apps.get('is_active', True) == True]) if 'is_active' in foundation_apps.columns else 0
            inactive_apps = total_apps - active_apps

            prod_apps = len(foundation_apps[foundation_apps.get('environment', '').str.contains('prod', case=False, na=False)]) if 'environment' in foundation_apps.columns else 0

            migration_ready = len(foundation_apps[foundation_apps.get('migration_readiness', 0) >= 70]) if 'migration_readiness' in foundation_apps.columns else 0

            total_clusters = len(foundation_clusters)
            total_pods = foundation_apps['total_pods'].sum() if 'total_pods' in foundation_apps.columns else 0

            summary_data.append({
                'Foundation': foundation,
                'Total_Applications': total_apps,
                'Active_Applications': active_apps,
                'Inactive_Applications': inactive_apps,
                'Production_Applications': prod_apps,
                'Migration_Ready_Apps': migration_ready,
                'Total_Clusters': total_clusters,
                'Total_Pods': total_pods,
                'Report_File': Path(stats['file_path']).name
            })

        # Add cross-foundation totals
        if summary_data:
            totals = {
                'Foundation': 'TOTAL',
                'Total_Applications': sum(row['Total_Applications'] for row in summary_data),
                'Active_Applications': sum(row['Active_Applications'] for row in summary_data),
                'Inactive_Applications': sum(row['Inactive_Applications'] for row in summary_data),
                'Production_Applications': sum(row['Production_Applications'] for row in summary_data),
                'Migration_Ready_Apps': sum(row['Migration_Ready_Apps'] for row in summary_data),
                'Total_Clusters': sum(row['Total_Clusters'] for row in summary_data),
                'Total_Pods': sum(row['Total_Pods'] for row in summary_data),
                'Report_File': 'Combined'
            }
            summary_data.append(totals)

        return pd.DataFrame(summary_data)

    def save_consolidated_reports(self, apps_df, clusters_df, migration_df, summary_df):
        """Save all consolidated reports to CSV files"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Save consolidated CSV reports
        reports = {
            'applications': (apps_df, f"consolidated_applications_{timestamp}.csv"),
            'clusters': (clusters_df, f"consolidated_clusters_{timestamp}.csv"),
            'migration_priority': (migration_df, f"consolidated_migration_priority_{timestamp}.csv"),
            'executive_summary': (summary_df, f"consolidated_executive_summary_{timestamp}.csv")
        }

        saved_files = {}

        for report_type, (df, filename) in reports.items():
            if df is not None and not df.empty:
                filepath = self.output_dir / filename
                df.to_csv(filepath, index=False)
                saved_files[report_type] = filepath
                self.logger.info(f"Saved {report_type}: {filepath} ({len(df)} rows)")
            else:
                self.logger.warning(f"No data available for {report_type} report")

        return saved_files, timestamp

    def generate_metadata(self, foundation_stats, saved_files, timestamp):
        """Generate metadata about the consolidation"""
        metadata = {
            'consolidation_timestamp': datetime.now().isoformat(),
            'timestamp': timestamp,
            'foundations_processed': list(foundation_stats.keys()),
            'foundation_stats': foundation_stats,
            'consolidated_files': {k: str(v) for k, v in saved_files.items()},
            'total_foundations': len(foundation_stats),
            'total_applications': sum(stats['total_applications'] for stats in foundation_stats.values()),
            'total_active_applications': sum(stats['active_applications'] for stats in foundation_stats.values())
        }

        metadata_file = self.output_dir / f"consolidation_metadata_{timestamp}.json"
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

        self.logger.info(f"Saved metadata: {metadata_file}")
        return metadata_file

    def run_consolidation(self):
        """Run the full consolidation process"""
        try:
            # Discover available foundation reports
            foundation_data = self.discover_foundation_reports()

            if not foundation_data:
                raise ValueError("No foundation reports found to consolidate")

            # Load and combine data from all foundations
            apps_df, foundation_stats = self.load_and_combine_applications(foundation_data)
            clusters_df = self.load_and_combine_clusters(foundation_data)
            migration_df = self.load_and_combine_migration_priority(foundation_data)

            # Generate cross-foundation summary
            summary_df = self.generate_cross_foundation_summary(foundation_stats, apps_df, clusters_df)

            # Save consolidated reports
            saved_files, timestamp = self.save_consolidated_reports(apps_df, clusters_df, migration_df, summary_df)

            # Generate metadata
            metadata_file = self.generate_metadata(foundation_stats, saved_files, timestamp)

            # Print summary
            print("\n" + "="*60)
            print("CROSS-FOUNDATION CONSOLIDATION COMPLETE")
            print("="*60)
            print(f"Processed {len(foundation_stats)} foundations:")
            for foundation, stats in foundation_stats.items():
                print(f"  {foundation}: {stats['total_applications']} applications")

            print(f"\nConsolidated files saved to: {self.output_dir}")
            for report_type, filepath in saved_files.items():
                print(f"  {report_type.replace('_', ' ').title()}: {filepath.name}")

            print(f"\nMetadata: {metadata_file.name}")
            print("="*60)

            return {
                'saved_files': saved_files,
                'metadata_file': metadata_file,
                'timestamp': timestamp,
                'foundation_stats': foundation_stats
            }

        except Exception as e:
            self.logger.error(f"Consolidation failed: {e}")
            raise

def main():
    parser = argparse.ArgumentParser(description='Aggregate CSV reports from multiple foundations')
    parser.add_argument('foundation_reports_dir', help='Directory containing foundation report subdirectories')
    parser.add_argument('-o', '--output-dir', help='Output directory for consolidated reports')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose logging')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        aggregator = CrossFoundationAggregator(
            args.foundation_reports_dir,
            args.output_dir
        )

        result = aggregator.run_consolidation()
        print(f"\nConsolidation completed successfully!")
        print(f"Ready for Excel workbook generation with timestamp: {result['timestamp']}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
