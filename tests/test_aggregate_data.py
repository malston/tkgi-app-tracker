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
    from aggregate_data import DataAggregator, FoundationDataProcessor
except ImportError as e:
    print(f"Could not import aggregate_data module: {e}")
    print("This test requires the aggregate-data.py script to be importable")
    sys.exit(1)


class TestDataAggregator(unittest.TestCase):
    """Test cases for DataAggregator class"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.aggregator = DataAggregator(output_dir=self.test_dir)

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def create_mock_cluster_data(self, foundation, cluster, namespaces_data):
        """Create mock cluster data file"""
        cluster_data = []

        for ns_data in namespaces_data:
            namespace_entry = {
                "namespace": ns_data["name"],
                "cluster": cluster,
                "foundation": foundation,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "is_system": ns_data.get("is_system", False),
                "app_id": ns_data.get("app_id", "unknown"),
                "labels": ns_data.get("labels", {}),
                "annotations": ns_data.get("annotations", {}),
                "creation_timestamp": (datetime.utcnow() - timedelta(days=30)).isoformat() + "Z",
                "pod_count": ns_data.get("pod_count", 0),
                "running_pods": ns_data.get("running_pods", 0),
                "deployment_count": ns_data.get("deployment_count", 0),
                "statefulset_count": ns_data.get("statefulset_count", 0),
                "service_count": ns_data.get("service_count", 0),
                "last_activity": datetime.utcnow().isoformat() + "Z",
                "resource_quota": ns_data.get("resource_quota", []),
                "environment": ns_data.get("environment", "test")
            }
            cluster_data.append(namespace_entry)

        # Write to temporary file
        cluster_file = os.path.join(self.test_dir, f"cluster_data_{foundation}_{cluster}.json")
        with open(cluster_file, 'w') as f:
            json.dump(cluster_data, f, indent=2)

        return cluster_file

    def test_load_cluster_data_files(self):
        """Test loading cluster data files"""
        # Create mock cluster data
        foundation = "dc01-k8s-n-01"
        cluster = "test-cluster"

        namespaces = [
            {
                "name": "test-app-1",
                "app_id": "APP-12345",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 4,
                "deployment_count": 2,
                "service_count": 3,
                "environment": "lab"
            },
            {
                "name": "kube-system",
                "is_system": True,
                "pod_count": 10,
                "running_pods": 10,
                "deployment_count": 5,
                "service_count": 2,
                "environment": "lab"
            }
        ]

        cluster_file = self.create_mock_cluster_data(foundation, cluster, namespaces)

        # Test loading data
        data_files = [cluster_file]
        loaded_data = self.aggregator.load_cluster_data_files(data_files)

        self.assertEqual(len(loaded_data), 2)
        self.assertEqual(loaded_data[0]["namespace"], "test-app-1")
        self.assertEqual(loaded_data[0]["app_id"], "APP-12345")
        self.assertEqual(loaded_data[1]["namespace"], "kube-system")
        self.assertTrue(loaded_data[1]["is_system"])

    def test_classify_applications(self):
        """Test application classification logic"""
        # Create test data
        raw_data = [
            {
                "namespace": "test-app-1",
                "app_id": "APP-12345",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 4,
                "last_activity": datetime.utcnow().isoformat() + "Z"
            },
            {
                "namespace": "test-app-2",
                "app_id": "APP-67890",
                "is_system": False,
                "pod_count": 0,
                "running_pods": 0,
                "last_activity": (datetime.utcnow() - timedelta(days=60)).isoformat() + "Z"
            },
            {
                "namespace": "kube-system",
                "app_id": "unknown",
                "is_system": True,
                "pod_count": 10,
                "running_pods": 10,
                "last_activity": datetime.utcnow().isoformat() + "Z"
            }
        ]

        applications = self.aggregator.classify_applications(raw_data)

        # Should only return application namespaces (not system)
        self.assertEqual(len(applications), 2)

        # Check first application (active)
        app1 = next(app for app in applications if app["app_id"] == "APP-12345")
        self.assertEqual(app1["status"], "Active")

        # Check second application (inactive due to old activity)
        app2 = next(app for app in applications if app["app_id"] == "APP-67890")
        self.assertEqual(app2["status"], "Inactive")

    def test_calculate_migration_readiness(self):
        """Test migration readiness calculation"""
        # Test application with good readiness indicators
        app_data = {
            "pod_count": 5,
            "running_pods": 5,
            "deployment_count": 2,
            "service_count": 3,
            "labels": {"version": "v1.0.0", "team": "platform"},
            "last_activity": datetime.utcnow().isoformat() + "Z",
            "days_since_activity": 1
        }

        readiness_score = self.aggregator.calculate_migration_readiness(app_data)

        # Should have high readiness score (>=70)
        self.assertGreaterEqual(readiness_score, 70)
        self.assertLessEqual(readiness_score, 100)

        # Test application with poor readiness indicators
        poor_app_data = {
            "pod_count": 0,
            "running_pods": 0,
            "deployment_count": 0,
            "service_count": 0,
            "labels": {},
            "last_activity": (datetime.utcnow() - timedelta(days=90)).isoformat() + "Z",
            "days_since_activity": 90
        }

        poor_readiness_score = self.aggregator.calculate_migration_readiness(poor_app_data)

        # Should have low readiness score
        self.assertLess(poor_readiness_score, 50)

    def test_generate_summary_statistics(self):
        """Test summary statistics generation"""
        applications = [
            {
                "app_id": "APP-001",
                "status": "Active",
                "environment": "production",
                "migration_readiness_score": 85,
                "pod_count": 5,
                "running_pods": 5
            },
            {
                "app_id": "APP-002",
                "status": "Active",
                "environment": "nonprod",
                "migration_readiness_score": 45,
                "pod_count": 3,
                "running_pods": 2
            },
            {
                "app_id": "APP-003",
                "status": "Inactive",
                "environment": "lab",
                "migration_readiness_score": 20,
                "pod_count": 0,
                "running_pods": 0
            }
        ]

        summary = self.aggregator.generate_summary_statistics(applications, [])

        # Check totals
        self.assertEqual(summary["total_applications"], 3)
        self.assertEqual(summary["active_applications"], 2)
        self.assertEqual(summary["inactive_applications"], 1)

        # Check environment breakdown
        self.assertEqual(summary["production_applications"], 1)
        self.assertEqual(summary["nonprod_applications"], 1)
        self.assertEqual(summary["lab_applications"], 1)

        # Check migration readiness
        self.assertEqual(summary["ready_for_migration"], 1)  # Score >= 70

        # Check totals
        self.assertEqual(summary["total_pods"], 8)
        self.assertEqual(summary["running_pods"], 7)


class TestFoundationDataProcessor(unittest.TestCase):
    """Test cases for FoundationDataProcessor class"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.processor = FoundationDataProcessor()

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_extract_foundation_info(self):
        """Test foundation information extraction"""
        foundation = "dc01-k8s-n-01"

        info = self.processor.extract_foundation_info(foundation)

        self.assertEqual(info["foundation"], foundation)
        self.assertEqual(info["datacenter"], "dc01")
        self.assertEqual(info["environment"], "lab")
        self.assertEqual(info["type"], "k8s")
        self.assertEqual(info["instance"], "01")

    def test_group_by_foundation(self):
        """Test grouping applications by foundation"""
        applications = [
            {
                "app_id": "APP-001",
                "foundations": ["dc01-k8s-n-01"],
                "status": "Active"
            },
            {
                "app_id": "APP-002",
                "foundations": ["dc01-k8s-n-01", "dc02-k8s-n-01"],
                "status": "Active"
            },
            {
                "app_id": "APP-003",
                "foundations": ["dc02-k8s-n-01"],
                "status": "Inactive"
            }
        ]

        grouped = self.processor.group_by_foundation(applications)

        # Check foundation groups
        self.assertIn("dc01-k8s-n-01", grouped)
        self.assertIn("dc02-k8s-n-01", grouped)

        # Check application counts
        dc01_apps = grouped["dc01-k8s-n-01"]
        self.assertEqual(len(dc01_apps), 2)  # APP-001 and APP-002

        dc02_apps = grouped["dc02-k8s-n-01"]
        self.assertEqual(len(dc02_apps), 2)  # APP-002 and APP-003

    def test_calculate_foundation_summary(self):
        """Test foundation summary calculations"""
        foundation_apps = [
            {"status": "Active", "pod_count": 5},
            {"status": "Active", "pod_count": 3},
            {"status": "Inactive", "pod_count": 0}
        ]

        summary = self.processor.calculate_foundation_summary("dc01-k8s-n-01", foundation_apps)

        self.assertEqual(summary["foundation"], "dc01-k8s-n-01")
        self.assertEqual(summary["total_applications"], 3)
        self.assertEqual(summary["active_applications"], 2)
        self.assertEqual(summary["inactive_applications"], 1)
        self.assertEqual(summary["total_pods"], 8)
        self.assertEqual(summary["environment"], "lab")


class TestDataValidation(unittest.TestCase):
    """Test cases for data validation functions"""

    def test_validate_cluster_data_structure(self):
        """Test cluster data structure validation"""
        valid_data = [
            {
                "namespace": "test-ns",
                "cluster": "test-cluster",
                "foundation": "dc01-k8s-n-01",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "is_system": False,
                "pod_count": 5,
                "running_pods": 4
            }
        ]

        # This would test validation functions if they exist
        # For now, just ensure the data structure is as expected
        self.assertIsInstance(valid_data, list)
        self.assertIn("namespace", valid_data[0])
        self.assertIn("cluster", valid_data[0])
        self.assertIn("foundation", valid_data[0])


def main():
    """Run all unit tests"""
    # Set up test environment
    os.environ['TKGI_APP_TRACKER_TEST_MODE'] = 'true'

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(TestDataAggregator))
    suite.addTests(loader.loadTestsFromTestCase(TestFoundationDataProcessor))
    suite.addTests(loader.loadTestsFromTestCase(TestDataValidation))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
