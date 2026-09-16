#!/usr/bin/env python3
"""Tests for the workflow-file integrity scan (PleaNP #101 / #110).

A guard that cannot detect the failure it exists for is worthless, so each
violation class is asserted to be caught, and a well-formed workflow is asserted
to be accepted. The regression fixture reproduces the actual #101 corruption:
the three swallowed step boundaries found in `dev`'s `ci.yml` before `1037101`.

Run: python3 tooling/gates/tests/test_workflow_scan.py
"""
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
GUARD = REPO / "tooling" / "gates" / "workflow_scan.py"
sys.path.insert(0, str(GUARD.parent))

import workflow_scan as w  # noqa: E402

CLEAN = """name: CI
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install elan
        run: |
          curl -sSf https://example.invalid/elan-init.sh | sh -s -- -y
      - name: Build
        run: lake build
        working-directory: lean
"""

# The #101 signature, all three shapes found in dev's ci.yml before 1037101:
#   (a) a step boundary swallowed into the previous scalar;
#   (b) a step boundary joined with no separator;
#   (c) a step mis-indented.
SWALLOWED = """name: CI
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build
        run: lake build
        working-directory: lean      - name: Barrier-check harness
        run: python3 harness.py
      - name: Scans
        run: python3 scans.py
            - name: GR register check
        run: python3 register.py
      - name: Last
        run: python3 last.py
"""

BAD_SHAPE = """name: CI
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: No command
        working-directory: lean
"""


def findings_for(text, label="wf.yml"):
    return w._violations_for_text(text, label)


class TestWorkflowScan(unittest.TestCase):
    def test_clean_workflow_passes(self):
        self.assertEqual(findings_for(CLEAN), [])

    def test_swallowed_step_boundary_is_caught(self):
        fs = findings_for(SWALLOWED)
        self.assertTrue(
            any("not at the start of its line" in f for f in fs),
            f"expected the swallowed-boundary signature, got {fs}",
        )

    def test_step_without_run_or_uses_is_caught(self):
        fs = findings_for(BAD_SHAPE)
        self.assertTrue(
            any("exactly one of 'uses'/'run'" in f for f in fs),
            f"expected the missing-command violation, got {fs}",
        )

    def test_unparseable_yaml_is_caught(self):
        # A mis-indented sequence dash is outside miniyaml's supported subset.
        fs = findings_for("name: CI\njobs:\n  build:\n    steps:\n      - uses: x\n     - uses: y\n")
        self.assertTrue(any("does not parse" in f for f in fs), fs)

    def test_missing_jobs_is_caught(self):
        fs = findings_for("name: CI\non: push\n")
        self.assertTrue(any("jobs" in f for f in fs), fs)

    def test_real_repo_workflows_are_clean(self):
        self.assertEqual(w.scan(REPO), [], "live workflows must pass the scan")


if __name__ == "__main__":
    unittest.main()