#!/usr/bin/env python3
"""Fail when changed executable Swift lines miss the coverage threshold."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_THRESHOLD = 80.0
APP_SOURCE_PREFIX = "macos-support-tools/"


@dataclass(frozen=True)
class CoverageLine:
    executable: bool
    covered: bool
    count: int | None = None


@dataclass(frozen=True)
class CoverageResult:
    passed: bool
    message: str
    total_executable_lines: int = 0
    covered_lines: int = 0
    percent: float = 100.0
    missing_files: tuple[str, ...] = ()
    uncovered_lines: tuple[tuple[str, int], ...] = ()


def run_command(args: list[str]) -> str:
    completed = subprocess.run(args, check=True, text=True, capture_output=True)
    return completed.stdout


def normalize_path(path: str) -> str:
    return path.removeprefix("a/").removeprefix("b/")


def is_app_swift_path(path: str) -> bool:
    normalized = normalize_path(path)
    return (
        normalized.startswith(APP_SOURCE_PREFIX)
        and normalized.endswith(".swift")
        and "/Assets.xcassets/" not in normalized
        and not normalized.startswith("macos-support-toolsTests/")
        and not normalized.startswith("macos-support-toolsUITests/")
    )


def parse_changed_lines(diff_text: str) -> dict[str, set[int]]:
    changed_lines: dict[str, set[int]] = {}
    current_path: str | None = None
    new_line_number: int | None = None

    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            path = normalize_path(line[4:].strip())
            current_path = path if is_app_swift_path(path) and path != "/dev/null" else None
            continue

        if current_path is None:
            continue

        hunk_match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
        if hunk_match:
            new_line_number = int(hunk_match.group(1))
            continue

        if new_line_number is None:
            continue

        if line.startswith("+") and not line.startswith("+++"):
            changed_lines.setdefault(current_path, set()).add(new_line_number)
            new_line_number += 1
        elif line.startswith("-") and not line.startswith("---"):
            continue
        else:
            new_line_number += 1

    return changed_lines


def changed_lines_from_git(base_ref: str) -> dict[str, set[int]]:
    diff_text = run_command(["git", "diff", "--unified=0", "--diff-filter=AM", f"{base_ref}...HEAD"])
    return parse_changed_lines(diff_text)


def line_number_from_entry(entry: dict) -> int | None:
    for key in ("line", "lineNumber", "line_number"):
        value = entry.get(key)
        if isinstance(value, int):
            return value
    return None


def execution_count_from_entry(entry: dict) -> int | None:
    for key in ("count", "executionCount", "execution_count", "coveredExecutions"):
        value = entry.get(key)
        if isinstance(value, int):
            return value
    if "covered" in entry and isinstance(entry["covered"], bool):
        return 1 if entry["covered"] else 0
    return None


def lines_from_json_value(value) -> dict[int, CoverageLine]:
    if isinstance(value, dict):
        if all(str(key).isdigit() for key in value):
            return {
                int(key): CoverageLine(executable=True, covered=int(count) > 0, count=int(count))
                for key, count in value.items()
                if isinstance(count, int)
            }
        for key in ("lines", "lineData", "lineCoverageData"):
            if key in value:
                return lines_from_json_value(value[key])

    if isinstance(value, list):
        lines: dict[int, CoverageLine] = {}
        for entry in value:
            if not isinstance(entry, dict):
                continue
            line_number = line_number_from_entry(entry)
            count = execution_count_from_entry(entry)
            if line_number is None or count is None:
                continue
            lines[line_number] = CoverageLine(executable=True, covered=count > 0, count=count)
        return lines

    return {}


def coverage_from_fixture(path: Path) -> dict[str, dict[int, CoverageLine]]:
    data = json.loads(path.read_text())

    if isinstance(data, dict) and "coverage" in data and isinstance(data["coverage"], dict):
        return {
            normalize_path(file_path): lines_from_json_value(lines)
            for file_path, lines in data["coverage"].items()
        }

    files = data.get("files", []) if isinstance(data, dict) else []
    coverage: dict[str, dict[int, CoverageLine]] = {}
    for file_entry in files:
        if not isinstance(file_entry, dict):
            continue
        file_path = file_entry.get("path") or file_entry.get("name")
        if not isinstance(file_path, str):
            continue
        coverage[normalize_path(file_path)] = lines_from_json_value(file_entry)
    return coverage


def archive_file_list(result_bundle: Path) -> list[str]:
    output = run_command(["xcrun", "xccov", "view", "--archive", "--file-list", str(result_bundle)])
    return [line.strip() for line in output.splitlines() if line.strip()]


def archive_path_for_changed_file(changed_path: str, archive_paths: Iterable[str]) -> str | None:
    suffix = "/" + changed_path
    for archive_path in archive_paths:
        if archive_path.endswith(suffix) or archive_path == changed_path:
            return archive_path
    return None


def coverage_from_xccov(result_bundle: Path, changed_files: Iterable[str]) -> dict[str, dict[int, CoverageLine]]:
    archive_paths = archive_file_list(result_bundle)
    coverage: dict[str, dict[int, CoverageLine]] = {}

    for changed_file in changed_files:
        archive_path = archive_path_for_changed_file(changed_file, archive_paths)
        if archive_path is None:
            continue
        output = run_command([
            "xcrun",
            "xccov",
            "view",
            "--archive",
            "--file",
            archive_path,
            "--json",
            str(result_bundle),
        ])
        coverage[changed_file] = lines_from_json_value(json.loads(output))

    return coverage


def evaluate_coverage(
    changed_lines: dict[str, set[int]],
    coverage: dict[str, dict[int, CoverageLine]],
    threshold: float,
) -> CoverageResult:
    if not changed_lines:
        return CoverageResult(passed=True, message="No changed app Swift lines found.")

    missing_files = sorted(path for path in changed_lines if path not in coverage)
    if missing_files:
        return CoverageResult(
            passed=False,
            message="Coverage data is missing for changed app Swift files.",
            missing_files=tuple(missing_files),
        )

    total = 0
    covered = 0
    uncovered: list[tuple[str, int]] = []

    for file_path, line_numbers in sorted(changed_lines.items()):
        file_coverage = coverage[file_path]
        for line_number in sorted(line_numbers):
            line_coverage = file_coverage.get(line_number)
            if line_coverage is None or not line_coverage.executable:
                continue
            total += 1
            if line_coverage.covered:
                covered += 1
            else:
                uncovered.append((file_path, line_number))

    if total == 0:
        return CoverageResult(passed=True, message="No changed executable app Swift lines found.")

    percent = covered / total * 100
    passed = percent >= threshold
    return CoverageResult(
        passed=passed,
        message=f"Changed executable line coverage is {percent:.1f}% ({covered}/{total}).",
        total_executable_lines=total,
        covered_lines=covered,
        percent=percent,
        uncovered_lines=tuple(uncovered),
    )


def markdown_summary(result: CoverageResult, threshold: float) -> str:
    status = "Passed" if result.passed else "Failed"
    lines = [
        "## Changed-Line Coverage",
        "",
        f"Status: **{status}**",
        "",
        "| Metric | Value |",
        "| --- | --- |",
        f"| Threshold | {threshold:.1f}% |",
        f"| Covered executable lines | {result.covered_lines}/{result.total_executable_lines} |",
        f"| Coverage | {result.percent:.1f}% |",
        "",
        result.message,
    ]

    if result.missing_files:
        lines.extend(["", "Missing coverage files:"])
        lines.extend(f"- `{path}`" for path in result.missing_files)

    if result.uncovered_lines:
        lines.extend(["", "Uncovered changed executable lines:"])
        lines.extend(f"- `{path}:{line}`" for path, line in result.uncovered_lines[:20])
        if len(result.uncovered_lines) > 20:
            lines.append(f"- ...and {len(result.uncovered_lines) - 20} more")

    return "\n".join(lines) + "\n"


def write_summary(path: str | None, text: str) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as summary_file:
        summary_file.write(text)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-ref", default=os.environ.get("GITHUB_BASE_REF", "main"))
    parser.add_argument("--result-bundle", default=os.environ.get("COVERAGE_RESULT_BUNDLE"))
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD)
    parser.add_argument("--summary-file", default=os.environ.get("GITHUB_STEP_SUMMARY"))
    parser.add_argument("--diff-file", type=Path, help="Read a unified diff from a fixture instead of git.")
    parser.add_argument("--coverage-json", type=Path, help="Read coverage from a fixture instead of xccov.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    base_ref = args.base_ref
    if not base_ref.startswith("origin/") and args.diff_file is None:
        base_ref = f"origin/{base_ref}"

    changed_lines = (
        parse_changed_lines(args.diff_file.read_text())
        if args.diff_file
        else changed_lines_from_git(base_ref)
    )
    if not changed_lines:
        result = evaluate_coverage(changed_lines, {}, args.threshold)
        summary = markdown_summary(result, args.threshold)
        write_summary(args.summary_file, summary)
        print(summary, end="")
        return 0

    if args.coverage_json:
        coverage = coverage_from_fixture(args.coverage_json)
    else:
        if not args.result_bundle:
            print("error: --result-bundle or COVERAGE_RESULT_BUNDLE is required", file=sys.stderr)
            return 2
        coverage = coverage_from_xccov(Path(args.result_bundle), changed_lines.keys())

    result = evaluate_coverage(changed_lines, coverage, args.threshold)
    summary = markdown_summary(result, args.threshold)
    write_summary(args.summary_file, summary)
    print(summary, end="")

    return 0 if result.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
