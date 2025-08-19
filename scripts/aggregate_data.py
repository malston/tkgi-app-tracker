#!/usr/bin/env python3

"""
Data Aggregator for TKGI Application Tracker
Aggregates cluster data across multiple foundations and clusters
"""

import json
import os
from datetime import datetime, timedelta
from pathlib import Path


class DataAggregator:
    """Aggregates TKGI cluster data across foundations"""
    
    def __init__(self, output_dir="aggregated-data"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
    
    def load_cluster_data_files(self, data_files):
        """Load cluster data from JSON files"""
        all_data = []
        for file_path in data_files:
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        all_data.extend(data)
                    else:
                        all_data.append(data)
        return all_data
    
    def classify_applications(self, raw_data):
        """Classify applications from namespace data"""
        applications = []
        app_map = {}
        
        for entry in raw_data:
            if entry.get("is_system", False):
                continue
                
            app_id = entry.get("app_id", "unknown")
            if app_id == "unknown":
                app_id = f"app-{entry.get('namespace', 'unknown')}"
            
            # Determine status based on activity
            last_activity = entry.get("last_activity", "")
            days_since = self._calculate_days_since(last_activity)
            status = "Active" if days_since < 30 else "Inactive"
            
            if app_id not in app_map:
                app_map[app_id] = {
                    "app_id": app_id,
                    "status": status,
                    "environment": entry.get("environment", "unknown"),
                    "foundations": set(),
                    "clusters": set(),
                    "namespaces": [],
                    "pod_count": 0,
                    "running_pods": 0,
                    "deployment_count": 0,
                    "service_count": 0,
                    "last_activity": last_activity,
                    "days_since_activity": days_since
                }
            
            app = app_map[app_id]
            app["foundations"].add(entry.get("foundation", ""))
            app["clusters"].add(entry.get("cluster", ""))
            app["namespaces"].append(entry.get("namespace", ""))
            app["pod_count"] += entry.get("pod_count", 0)
            app["running_pods"] += entry.get("running_pods", 0)
            app["deployment_count"] += entry.get("deployment_count", 0)
            app["service_count"] += entry.get("service_count", 0)
        
        # Convert sets to lists for JSON serialization
        for app in app_map.values():
            app["foundations"] = list(app["foundations"])
            app["clusters"] = list(app["clusters"])
            applications.append(app)
        
        return applications
    
    def calculate_migration_readiness(self, app_data):
        """Calculate migration readiness score (0-100)"""
        score = 0
        
        # Active status (30 points)
        if app_data.get("status") == "Active":
            score += 30
        
        # Has running pods (20 points)
        if app_data.get("running_pods", 0) > 0:
            score += 20
        
        # Has deployments (15 points)
        if app_data.get("deployment_count", 0) > 0:
            score += 15
        
        # Has services (15 points)
        if app_data.get("service_count", 0) > 0:
            score += 15
        
        # Has metadata/labels (10 points)
        if app_data.get("labels"):
            score += 10
        
        # Recent activity (10 points)
        if app_data.get("days_since_activity", 999) < 7:
            score += 10
        
        return min(score, 100)
    
    def generate_summary_statistics(self, applications, clusters):
        """Generate summary statistics"""
        summary = {
            "report_date": datetime.utcnow().isoformat() + "Z",
            "total_applications": len(applications),
            "active_applications": sum(1 for app in applications if app.get("status") == "Active"),
            "inactive_applications": sum(1 for app in applications if app.get("status") == "Inactive"),
            "production_applications": sum(1 for app in applications if app.get("environment") == "production"),
            "nonprod_applications": sum(1 for app in applications if app.get("environment") in ["nonprod", "non-production"]),
            "lab_applications": sum(1 for app in applications if app.get("environment") == "lab"),
            "ready_for_migration": sum(1 for app in applications if app.get("migration_readiness_score", 0) >= 70),
            "needs_planning": sum(1 for app in applications if 40 <= app.get("migration_readiness_score", 0) < 70),
            "needs_analysis": sum(1 for app in applications if app.get("migration_readiness_score", 0) < 40),
            "total_pods": sum(app.get("pod_count", 0) for app in applications),
            "running_pods": sum(app.get("running_pods", 0) for app in applications)
        }
        return summary
    
    def _calculate_days_since(self, timestamp_str):
        """Calculate days since a timestamp"""
        if not timestamp_str:
            return 999
        
        try:
            timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            delta = datetime.utcnow().replace(tzinfo=timestamp.tzinfo) - timestamp
            return delta.days
        except:
            return 999


class FoundationDataProcessor:
    """Process foundation-specific data"""
    
    def extract_foundation_info(self, foundation_name):
        """Extract foundation components"""
        parts = foundation_name.split('-')
        if len(parts) >= 4:
            return {
                "foundation": foundation_name,
                "datacenter": parts[0],
                "type": parts[1],
                "environment": self._determine_environment(parts[0], parts[2]),
                "instance": parts[3]
            }
        return {
            "foundation": foundation_name,
            "datacenter": "unknown",
            "type": "unknown", 
            "environment": "unknown",
            "instance": "unknown"
        }
    
    def _determine_environment(self, datacenter, env_code):
        """Determine environment from datacenter and code"""
        if datacenter == "dc01":
            return "lab"
        elif env_code == "p":
            return "prod"
        elif env_code == "n":
            return "nonprod"
        elif env_code == "l":
            return "lab"
        else:
            return "unknown"
    
    def group_by_foundation(self, applications):
        """Group applications by foundation"""
        grouped = {}
        for app in applications:
            for foundation in app.get("foundations", []):
                if foundation not in grouped:
                    grouped[foundation] = []
                grouped[foundation].append(app)
        return grouped
    
    def calculate_foundation_summary(self, foundation_name, foundation_apps):
        """Calculate summary for a foundation"""
        return {
            "foundation": foundation_name,
            "total_applications": len(foundation_apps),
            "active_applications": sum(1 for app in foundation_apps if app.get("status") == "Active"),
            "inactive_applications": sum(1 for app in foundation_apps if app.get("status") == "Inactive"),
            "total_pods": sum(app.get("pod_count", 0) for app in foundation_apps),
            "environment": self.extract_foundation_info(foundation_name).get("environment", "unknown")
        }


def main():
    """Main entry point for data aggregation"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Aggregate TKGI cluster data')
    parser.add_argument('--input-dir', default='collected-data', help='Input directory with cluster data')
    parser.add_argument('--output-dir', default='aggregated-data', help='Output directory for aggregated data')
    
    args = parser.parse_args()
    
    aggregator = DataAggregator(args.output_dir)
    
    # Find and load data files
    input_path = Path(args.input_dir)
    data_files = list(input_path.glob("*.json"))
    
    if not data_files:
        print(f"No data files found in {args.input_dir}")
        return 1
    
    # Load and aggregate data
    raw_data = aggregator.load_cluster_data_files(data_files)
    applications = aggregator.classify_applications(raw_data)
    
    # Add migration readiness scores
    for app in applications:
        app["migration_readiness_score"] = aggregator.calculate_migration_readiness(app)
    
    # Generate summary
    summary = aggregator.generate_summary_statistics(applications, [])
    
    # Save results
    output_path = Path(args.output_dir)
    output_path.mkdir(exist_ok=True)
    
    with open(output_path / "applications.json", 'w') as f:
        json.dump({"applications": applications}, f, indent=2)
    
    with open(output_path / "summary.json", 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"Aggregation complete. Results saved to {args.output_dir}")
    return 0


if __name__ == "__main__":
    exit(main())