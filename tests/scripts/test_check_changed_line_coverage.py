import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "check-changed-line-coverage.py"
SPEC = importlib.util.spec_from_file_location("check_changed_line_coverage", SCRIPT_PATH)
coverage_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = coverage_checker
SPEC.loader.exec_module(coverage_checker)


class ChangedLineCoverageTests(unittest.TestCase):
    def test_passing_changed_executable_line_coverage(self):
        diff = """diff --git a/macos-support-tools/App/Example.swift b/macos-support-tools/App/Example.swift
--- a/macos-support-tools/App/Example.swift
+++ b/macos-support-tools/App/Example.swift
@@ -1,0 +1,2 @@
+let covered = true
+let alsoCovered = true
"""
        changed_lines = coverage_checker.parse_changed_lines(diff)
        coverage = {
            "macos-support-tools/App/Example.swift": {
                1: coverage_checker.CoverageLine(executable=True, covered=True, count=1),
                2: coverage_checker.CoverageLine(executable=True, covered=True, count=2),
            }
        }

        result = coverage_checker.evaluate_coverage(changed_lines, coverage, 80)

        self.assertTrue(result.passed)
        self.assertEqual(result.covered_lines, 2)
        self.assertEqual(result.total_executable_lines, 2)

    def test_failing_changed_executable_line_coverage(self):
        changed_lines = {"macos-support-tools/App/Example.swift": {10, 11, 12, 13, 14}}
        coverage = {
            "macos-support-tools/App/Example.swift": {
                10: coverage_checker.CoverageLine(executable=True, covered=True, count=1),
                11: coverage_checker.CoverageLine(executable=True, covered=True, count=1),
                12: coverage_checker.CoverageLine(executable=True, covered=True, count=1),
                13: coverage_checker.CoverageLine(executable=True, covered=False, count=0),
                14: coverage_checker.CoverageLine(executable=True, covered=False, count=0),
            }
        }

        result = coverage_checker.evaluate_coverage(changed_lines, coverage, 80)

        self.assertFalse(result.passed)
        self.assertEqual(result.covered_lines, 3)
        self.assertEqual(result.total_executable_lines, 5)
        self.assertEqual(result.uncovered_lines, (
            ("macos-support-tools/App/Example.swift", 13),
            ("macos-support-tools/App/Example.swift", 14),
        ))

    def test_ignored_paths_are_not_counted_as_changed_app_lines(self):
        diff = """diff --git a/README.md b/README.md
--- a/README.md
+++ b/README.md
@@ -1,0 +1 @@
+Docs
diff --git a/macos-support-toolsTests/ExampleTests.swift b/macos-support-toolsTests/ExampleTests.swift
--- a/macos-support-toolsTests/ExampleTests.swift
+++ b/macos-support-toolsTests/ExampleTests.swift
@@ -1,0 +1 @@
+test
"""

        result = coverage_checker.evaluate_coverage(
            coverage_checker.parse_changed_lines(diff),
            {},
            80,
        )

        self.assertTrue(result.passed)
        self.assertEqual(result.message, "No changed app Swift lines found.")

    def test_no_executable_lines_passes(self):
        changed_lines = {"macos-support-tools/App/Example.swift": {1, 2}}
        coverage = {"macos-support-tools/App/Example.swift": {}}

        result = coverage_checker.evaluate_coverage(changed_lines, coverage, 80)

        self.assertTrue(result.passed)
        self.assertEqual(result.message, "No changed executable app Swift lines found.")

    def test_missing_coverage_fails(self):
        changed_lines = {"macos-support-tools/App/Example.swift": {1}}

        result = coverage_checker.evaluate_coverage(changed_lines, {}, 80)

        self.assertFalse(result.passed)
        self.assertEqual(result.missing_files, ("macos-support-tools/App/Example.swift",))

    def test_fixture_coverage_parser_accepts_line_count_maps(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "coverage.json"
            fixture.write_text(json.dumps({
                "coverage": {
                    "macos-support-tools/App/Example.swift": {
                        "3": 0,
                        "4": 2,
                    }
                }
            }))

            coverage = coverage_checker.coverage_from_fixture(fixture)

        self.assertFalse(coverage["macos-support-tools/App/Example.swift"][3].covered)
        self.assertTrue(coverage["macos-support-tools/App/Example.swift"][4].covered)


if __name__ == "__main__":
    unittest.main()
