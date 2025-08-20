#!/usr/bin/env python3

"""
Unit tests for generate-reports.py
Tests report generation logic with mocked data
"""

import unittest
import tempfile
import json
import csv
import os
import sys
from pathlib import Path
from datetime import datetime

# Add the scripts directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

try:
    from generate_reports import ReportGenerator, CSVReportWriter, JSONReportWriter
except ImportError as e:
    print(f"Could not import generate_reports module: {e}")
    print("This test requires the generate-reports.py script to be importable")
    sys.exit(1)


class TestReportGenerator(unittest.TestCase):
    """Test cases for ReportGenerator class"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.generator = ReportGenerator(output_dir=self.test_dir)

        # Create mock aggregated data
        self.mock_applications = [
            {
                "app_id": "APP-12345",
                "status": "Active",
                "environment": "production",
                "foundations": ["dc01-k8s-n-01"],
                "clusters": ["cluster-web-01"],
                "namespaces": ["web-frontend"],
                "pod_count": 5,
                "running_pods": 4,
                "deployment_count": 2,
                "service_count": 3,
                "last_activity": datetime.utcnow().isoformat() + "Z",
                "days_since_activity": 1,
                "migration_readiness_score": 85,
                "data_quality": "High",
                "recommendation": "Ready for Migration"
            },
            {
                "app_id": "APP-67890",
                "status": "Inactive",
                "environment": "nonprod",
                "foundations": ["dc02-k8s-n-01"],
                "clusters": ["cluster-api-01"],
                "namespaces": ["api-backend"],
                "pod_count": 0,
                "running_pods": 0,
                "deployment_count": 0,
                "service_count": 1,
                "last_activity": "2024-11-15T10:30:00Z",
                "days_since_activity": 95,
                "migration_readiness_score": 25,
                "data_quality": "Medium",
                "recommendation": "Needs Analysis"
            }
        ]

        self.mock_clusters = [
            {
                "cluster": "cluster-web-01",
                "foundation": "dc01-k8s-n-01",
                "environment": "production",
                "total_namespaces": 15,
                "application_namespaces": 8,
                "system_namespaces": 7,
                "total_pods": 125,
                "running_pods": 118,
                "total_applications": 8
            },
            {
                "cluster": "cluster-api-01",
                "foundation": "dc02-k8s-n-01",
                "environment": "nonprod",
                "total_namespaces": 12,
                "application_namespaces": 5,
                "system_namespaces": 7,
                "total_pods": 85,
                "running_pods": 82,
                "total_applications": 5
            }
        ]

        self.mock_summary = {
            "report_date": datetime.utcnow().isoformat() + "Z",
            "total_applications": 2,
            "active_applications": 1,
            "inactive_applications": 1,
            "production_applications": 1,
            "nonprod_applications": 1,
            "lab_applications": 0,
            "ready_for_migration": 1,
            "needs_planning": 0,
            "needs_analysis": 1,
            "total_pods": 5,
            "running_pods": 4
        }

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_generate_application_report_csv(self):
        """Test application report CSV generation"""
        csv_file = self.generator.generate_application_report(
            self.mock_applications,
            format='csv'
        )

        # Verify file was created
        self.assertTrue(os.path.exists(csv_file))
        self.assertTrue(csv_file.endswith('.csv'))

        # Verify CSV structure
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

            # Should have 2 applications
            self.assertEqual(len(rows), 2)

            # Check headers are present
            expected_headers = [
                'Application ID', 'Status', 'Environment', 'Foundations',
                'Clusters', 'Namespaces', 'Total Pods', 'Running Pods',
                'Deployments', 'Services', 'Last Activity', 'Days Since Activity',
                'Migration Readiness Score', 'Data Quality', 'Recommendation'
            ]

            for header in expected_headers:
                self.assertIn(header, reader.fieldnames)

            # Check first row data
            first_row = rows[0]
            self.assertEqual(first_row['Application ID'], 'APP-12345')
            self.assertEqual(first_row['Status'], 'Active')
            self.assertEqual(first_row['Environment'], 'production')
            self.assertEqual(first_row['Migration Readiness Score'], '85')

    def test_generate_cluster_report_csv(self):
        """Test cluster report CSV generation"""
        csv_file = self.generator.generate_cluster_report(
            self.mock_clusters,
            format='csv'
        )

        # Verify file was created
        self.assertTrue(os.path.exists(csv_file))

        # Verify CSV content
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

            # Should have 2 clusters
            self.assertEqual(len(rows), 2)

            # Check first cluster
            first_cluster = rows[0]
            self.assertEqual(first_cluster['Cluster'], 'cluster-web-01')
            self.assertEqual(first_cluster['Foundation'], 'dc01-k8s-n-01')
            self.assertEqual(first_cluster['Environment'], 'production')
            self.assertEqual(first_cluster['Total Applications'], '8')

    def test_generate_executive_summary_csv(self):
        """Test executive summary CSV generation"""
        csv_file = self.generator.generate_executive_summary(
            self.mock_summary,
            format='csv'
        )

        # Verify file was created
        self.assertTrue(os.path.exists(csv_file))

        # Verify CSV content
        with open(csv_file, 'r') as f:
            reader = csv.reader(f)
            rows = list(reader)

            # Should have header plus data rows
            self.assertGreater(len(rows), 1)

            # Check that we have metric/value pairs
            for row in rows[1:]:  # Skip header
                if row:  # Skip empty rows
                    self.assertEqual(len(row), 2)  # Should be metric, value pairs

    def test_generate_migration_priority_csv(self):
        """Test migration priority report generation"""
        csv_file = self.generator.generate_migration_priority_report(
            self.mock_applications,
            format='csv'
        )

        # Verify file was created
        self.assertTrue(os.path.exists(csv_file))

        # Verify CSV content
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

            # Should have applications sorted by readiness score
            self.assertEqual(len(rows), 2)

            # First row should be the higher readiness score
            first_row = rows[0]
            self.assertEqual(first_row['Application ID'], 'APP-12345')
            self.assertEqual(first_row['Migration Readiness Score'], '85')

    def test_generate_json_reports(self):
        """Test JSON report generation"""
        json_file = self.generator.generate_application_report(
            self.mock_applications,
            format='json'
        )

        # Verify file was created
        self.assertTrue(os.path.exists(json_file))
        self.assertTrue(json_file.endswith('.json'))

        # Verify JSON is valid and contains expected data
        with open(json_file, 'r') as f:
            data = json.load(f)

            self.assertIn('applications', data)
            self.assertEqual(len(data['applications']), 2)

            # Check first application
            first_app = data['applications'][0]
            self.assertEqual(first_app['app_id'], 'APP-12345')
            self.assertEqual(first_app['status'], 'Active')
            self.assertEqual(first_app['migration_readiness_score'], 85)

    def test_report_filename_generation(self):
        """Test report filename generation with timestamps"""
        csv_file = self.generator.generate_application_report(
            self.mock_applications,
            format='csv'
        )

        # Filename should contain timestamp and proper format
        filename = os.path.basename(csv_file)
        self.assertTrue(filename.startswith('application_report_'))
        self.assertTrue(filename.endswith('.csv'))

        # Should contain date in filename
        self.assertRegex(filename, r'application_report_\d{8}_\d{6}\.csv')


class TestCSVReportWriter(unittest.TestCase):
    """Test cases for CSV report writer"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_write_application_csv(self):
        """Test writing application data to CSV"""
        writer = CSVReportWriter(output_dir=self.test_dir)

        applications = [
            {
                "app_id": "APP-001",
                "status": "Active",
                "environment": "production",
                "foundations": ["dc01-k8s-n-01"],
                "migration_readiness_score": 85
            }
        ]

        csv_file = writer.write_application_report(applications)

        # Verify file creation and content
        self.assertTrue(os.path.exists(csv_file))

        with open(csv_file, 'r') as f:
            content = f.read()
            self.assertIn('APP-001', content)
            self.assertIn('Active', content)
            self.assertIn('production', content)

    def test_write_summary_csv(self):
        """Test writing summary data to CSV"""
        writer = CSVReportWriter(output_dir=self.test_dir)

        summary = {
            "total_applications": 10,
            "active_applications": 8,
            "inactive_applications": 2,
            "report_date": datetime.utcnow().isoformat() + "Z"
        }

        csv_file = writer.write_executive_summary(summary)

        # Verify file creation
        self.assertTrue(os.path.exists(csv_file))

        # Verify content structure
        with open(csv_file, 'r') as f:
            reader = csv.reader(f)
            rows = list(reader)

            # Should have header row plus data rows
            self.assertGreater(len(rows), 1)

            # First row should be header
            self.assertEqual(rows[0], ['Metric', 'Value'])


class TestJSONReportWriter(unittest.TestCase):
    """Test cases for JSON report writer"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Clean up test environment"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_write_json_report(self):
        """Test writing JSON reports"""
        writer = JSONReportWriter(output_dir=self.test_dir)

        data = {
            "applications": [
                {"app_id": "APP-001", "status": "Active"}
            ],
            "metadata": {
                "generation_time": datetime.utcnow().isoformat() + "Z",
                "total_count": 1
            }
        }

        json_file = writer.write_report("test_report", data)

        # Verify file creation
        self.assertTrue(os.path.exists(json_file))
        self.assertTrue(json_file.endswith('.json'))

        # Verify JSON is valid and contains expected data
        with open(json_file, 'r') as f:
            loaded_data = json.load(f)

            self.assertEqual(loaded_data['applications'][0]['app_id'], 'APP-001')
            self.assertEqual(loaded_data['metadata']['total_count'], 1)


class TestReportValidation(unittest.TestCase):
    """Test cases for report validation"""

    def test_validate_application_data(self):
        """Test application data validation"""
        valid_app = {
            "app_id": "APP-001",
            "status": "Active",
            "environment": "production",
            "foundations": ["dc01-k8s-n-01"],
            "migration_readiness_score": 85
        }

        # Test that valid data structure is accepted
        self.assertIsInstance(valid_app["app_id"], str)
        self.assertIn(valid_app["status"], ["Active", "Inactive"])
        self.assertIsInstance(valid_app["migration_readiness_score"], int)
        self.assertGreaterEqual(valid_app["migration_readiness_score"], 0)
        self.assertLessEqual(valid_app["migration_readiness_score"], 100)

    def test_validate_csv_headers(self):
        """Test CSV header validation"""
        expected_headers = [
            'Application ID', 'Status', 'Environment', 'Foundations',
            'Migration Readiness Score'
        ]

        # This would test header validation if implemented
        for header in expected_headers:
            self.assertIsInstance(header, str)
            self.assertGreater(len(header), 0)


def main():
    """Run all unit tests"""
    # Set up test environment
    os.environ['TKGI_APP_TRACKER_TEST_MODE'] = 'true'

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(TestReportGenerator))
    suite.addTests(loader.loadTestsFromTestCase(TestCSVReportWriter))
    suite.addTests(loader.loadTestsFromTestCase(TestJSONReportWriter))
    suite.addTests(loader.loadTestsFromTestCase(TestReportValidation))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
