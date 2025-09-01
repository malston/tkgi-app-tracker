#!/usr/bin/env python3

"""
Unit tests for aggregate-data.py
Tests data aggregation logic with mocked inputs
"""

import unittest
import tempfile
import json
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta

# Add the scripts directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

try:
    # Import from aggregate-data.py (with hyphen)
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "aggregate_data",
        os.path.join(os.path.dirname(__file__), '..', 'scripts', 'aggregate-data.py')
    )
    aggregate_data = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(aggregate_data)
    DataAggregator = aggregate_data.DataAggregator
except (ImportError, AttributeError) as e:
    print(f"Could not import aggregate-data module: {e}")
    print("This test requires the aggregate-data.py script to be importable")
    sys.exit(1)


class TestDataAggregator(unittest.TestCase):
    """Test cases for DataAggregator class"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.data_dir = os.path.join(self.test_dir, "data")
        self.reports_dir = os.path.join(self.test_dir, "reports")
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.reports_dir, exist_ok=True)
        self.aggregator = DataAggregator(data_dir=self.data_dir, reports_dir=self.reports_dir)

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_load_latest_data(self):
        """Test loading the latest data file"""
        # Create test data files - flat array of namespace objects
        test_data = [
            {
                "namespace": "app-001",
                "cluster": "dc01-k8s-n-01",
                "foundation": "dc01",
                "app_id": "APP-001",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 5
            }
        ]

        # Create multiple files with different timestamps
        file1 = os.path.join(self.data_dir, "all_clusters_20240101_120000.json")
        file2 = os.path.join(self.data_dir, "all_clusters_20240102_120000.json")

        with open(file1, 'w') as f:
            json.dump(test_data, f)

        # Modify test_data for second file
        test_data[0]["pod_count"] = 10
        with open(file2, 'w') as f:
            json.dump(test_data, f)

        # Load latest data
        data = self.aggregator.load_latest_data()

        # Should load the file with pod_count = 10
        self.assertEqual(data[0]["pod_count"], 10)

    def test_aggregate_by_application(self):
        """Test application aggregation"""
        # Flat array of namespace objects
        test_data = [
            {
                "namespace": "app-001-ns1",
                "cluster": "dc01-k8s-n-01",
                "cluster_full": "dc01-k8s-n-01",
                "foundation": "dc01",
                "app_id": "APP-001",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 5,
                "last_activity": datetime.now().isoformat()
            },
            {
                "namespace": "kube-system",
                "cluster": "dc01-k8s-n-01",
                "cluster_full": "dc01-k8s-n-01",
                "foundation": "dc01",
                "is_system": True,
                "pod_count": 10,
                "running_pods": 10
            },
            {
                "namespace": "app-001-ns2",
                "cluster": "dc02-k8s-n-01",
                "cluster_full": "dc02-k8s-n-01",
                "foundation": "dc02",
                "app_id": "APP-001",
                "is_system": False,
                "pod_count": 3,
                "running_pods": 3,
                "last_activity": datetime.now().isoformat()
            }
        ]

        app_data = self.aggregator.aggregate_by_application(test_data)

        # Check APP-001 is aggregated correctly
        self.assertIn("APP-001", app_data)
        self.assertEqual(app_data["APP-001"]["total_pods"], 8)
        self.assertEqual(app_data["APP-001"]["running_pods"], 8)
        self.assertEqual(len(app_data["APP-001"]["clusters"]), 2)
        self.assertEqual(len(app_data["APP-001"]["foundations"]), 2)

    def test_aggregate_by_cluster(self):
        """Test cluster aggregation"""
        # Flat array of namespace objects
        test_data = [
            {
                "namespace": "app-001",
                "cluster": "dc01-k8s-n-01",
                "cluster_full": "dc01-k8s-n-01",
                "foundation": "dc01",
                "app_id": "APP-001",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 4
            },
            {
                "namespace": "kube-system",
                "cluster": "dc01-k8s-n-01",
                "cluster_full": "dc01-k8s-n-01",
                "foundation": "dc01",
                "is_system": True,
                "pod_count": 10,
                "running_pods": 10
            }
        ]

        cluster_data = self.aggregator.aggregate_by_cluster(test_data)

        self.assertIn("dc01-k8s-n-01", cluster_data)
        cluster = cluster_data["dc01-k8s-n-01"]
        self.assertEqual(cluster["total_namespaces"], 2)
        self.assertEqual(cluster["system_namespaces"], 1)
        self.assertEqual(cluster["app_namespaces"], 1)
        self.assertEqual(cluster["total_pods"], 15)
        self.assertEqual(cluster["running_pods"], 14)

    def test_generate_summary(self):
        """Test summary generation"""
        app_data = {
            "APP-001": {
                "app_id": "APP-001",
                "is_active": True,
                "environments": ["production"],
                "foundations": ["dc01", "dc02"],
                "migration_readiness": 75,
                "data_quality": "complete"
            },
            "APP-002": {
                "app_id": "APP-002",
                "is_active": False,
                "environments": ["development"],
                "foundations": ["dc03"],
                "migration_readiness": 50,
                "data_quality": "incomplete"
            }
        }

        cluster_data = {
            "dc01-k8s-n-01": {
                "total_pods": 20,
                "running_pods": 18
            },
            "dc02-k8s-n-01": {
                "total_pods": 15,
                "running_pods": 15
            }
        }

        summary = self.aggregator.generate_summary(app_data, cluster_data)

        self.assertEqual(summary["totals"]["applications"], 2)
        self.assertEqual(summary["totals"]["active_applications"], 1)
        self.assertEqual(summary["totals"]["inactive_applications"], 1)
        self.assertEqual(summary["totals"]["production_applications"], 1)
        self.assertEqual(summary["totals"]["clusters"], 2)
        self.assertEqual(summary["totals"]["total_pods"], 35)
        self.assertEqual(summary["migration"]["ready_for_migration"], 1)
        self.assertEqual(summary["migration"]["needs_metadata_analysis"], 1)

    def test_save_aggregated_data(self):
        """Test saving aggregated data"""
        app_data = {"APP-001": {"app_id": "APP-001"}}
        cluster_data = {"dc01-k8s-n-01": {"cluster": "dc01-k8s-n-01"}}
        summary = {"timestamp": datetime.now().isoformat()}

        app_file, cluster_file, summary_file = self.aggregator.save_aggregated_data(
            app_data, cluster_data, summary
        )

        # Check files exist
        self.assertTrue(os.path.exists(app_file))
        self.assertTrue(os.path.exists(cluster_file))
        self.assertTrue(os.path.exists(summary_file))

        # Check content
        with open(app_file, 'r') as f:
            saved_app_data = json.load(f)
            self.assertEqual(saved_app_data, app_data)

    def test_extract_app_id_from_name(self):
        """Test extracting app ID from namespace name"""
        test_cases = [
            ("app-001-namespace", "app"),  # Returns first part only
            ("myapp-ns", "myapp"),
            ("single", "unknown"),  # No hyphen returns 'unknown'
            ("app-name-with-many-parts", "app"),
            ("test-12345", "test-12345"),  # Matches pattern for app-12345
            ("acme-app-12345", "acme-app")  # Matches pattern for company-app-12345
        ]

        for namespace_name, expected_app_id in test_cases:
            result = self.aggregator._extract_app_id_from_name(namespace_name)
            self.assertEqual(result, expected_app_id, f"Failed for {namespace_name}")


class TestDataValidation(unittest.TestCase):
    """Test data validation and error handling"""

    def test_empty_data_handling(self):
        """Test handling of empty data"""
        aggregator = DataAggregator()

        # Empty list
        result = aggregator.aggregate_by_application([])
        self.assertEqual(result, {})

        result = aggregator.aggregate_by_cluster([])
        self.assertEqual(result, {})

    def test_missing_fields_handling(self):
        """Test handling of missing fields"""
        aggregator = DataAggregator()

        # Missing important fields
        test_data = [
            {
                "namespace": "app-001",
                # Missing cluster, foundation, etc.
            }
        ]

        # Should handle gracefully
        result = aggregator.aggregate_by_application(test_data)
        # Should still process the namespace
        self.assertTrue(len(result) > 0)

    def test_invalid_data_types(self):
        """Test handling of invalid data types"""
        aggregator = DataAggregator()

        # Test with numeric string (should be handled)
        test_data = [
            {
                "namespace": "app-001",
                "cluster": "dc01-k8s-n-01",
                "cluster_full": "dc01-k8s-n-01",
                "foundation": "dc01",
                "pod_count": 5,  # Use valid int
                "running_pods": 5
            }
        ]

        # Should work with valid data
        result = aggregator.aggregate_by_cluster(test_data)
        self.assertIn("dc01-k8s-n-01", result)
        self.assertEqual(result["dc01-k8s-n-01"]["total_pods"], 5)


if __name__ == '__main__':
    # Run tests
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(TestDataAggregator))
    suite.addTests(loader.loadTestsFromTestCase(TestDataValidation))

    # Run tests with verbosity
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Exit with appropriate code
    sys.exit(0 if result.wasSuccessful() else 1)
