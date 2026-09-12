#!/usr/bin/env python3
"""Unit tests for the multi-run pass-sizing compliance scanner (`pass_scan.py`).

Stdlib-only, no secrets, no GitHub calls: the scanner's `validate_body` /
`effort_minmax` / `count_pass_lines` helpers are pure text functions, so the
full behavior (violation/warning/exempt) is covered offline via synthetic
issue bodies. The live-fetch path is exercised only when GITHUB_TOKEN is set
(see the pytest-skipped test at the end).

Run:  python3 tooling/gates/tests/test_pass_scan.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pass_scan  # noqa: E402


def body(effort: str, passes: str | None = None, extra: str = "") -> str:
    """Synthetic issue body: effort line + optional Passes block + extra text."""
    b = f"**Summary:** ...\n\n**Effort:** {effort}.\n"
    if passes:
        b += "\n**Passes:**\n" + passes + "\n"
    if extra:
        b += "\n" + extra + "\n"
    return b


class EffortParseTest(unittest.TestCase):
    def test_single_run(self):
        self.assertEqual(pass_scan.effort_minmax("**Effort:** 1 run."), (1, 1))

    def test_range(self):
        self.assertEqual(pass_scan.effort_minmax("**Effort:** 3–5 runs."), (3, 5))

    def test_hyphen_range(self):
        self.assertEqual(pass_scan.effort_minmax("**Effort:** 2-4 runs."), (2, 4))

    def test_no_effort(self):
        self.assertIsNone(pass_scan.effort_minmax("no effort here"))

    def test_compound(self):
        # "10–15 runs at research level" → (10, 15)
        self.assertEqual(
            pass_scan.effort_minmax("**Effort:** 10-15 runs at research level."),
            (10, 15))


class ComplianceTest(unittest.TestCase):
    def test_single_run_no_passes_ok(self):
        b = body("1 run")
        self.assertEqual(list(pass_scan.validate_body(1, "t", b, 2)), [])

    def test_multi_run_with_full_passes_ok(self):
        # pass lines should cover the effort MAX (each pass = one run)
        b = body("3-5 runs", passes="Pass 1 — a.\nPass 2 — b.\nPass 3 — c.\n"
                                    "Pass 4 — d.\nPass 5 — e.")
        self.assertEqual(list(pass_scan.validate_body(1, "t", b, 2)), [])

    def test_multi_run_with_passes_under_spec_warns(self):
        # 3 pass lines vs effort up to 5 -> under-specified warning
        b = body("3-5 runs", passes="Pass 1 — a.\nPass 2 — b.\nPass 3 — c.")
        f = list(pass_scan.validate_body(1, "t", b, 2))
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0].kind, "warning")
        self.assertIn("under-specified", f[0].detail)

    def test_multi_run_without_passes_violation(self):
        b = body("3-5 runs")
        f = list(pass_scan.validate_body(9, "t", b, 2))
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0].kind, "violation")
        self.assertIn("Passes", f[0].detail)

    def test_design_task_exempt(self):
        b = body("1-2 runs (design + decomposition)")
        # even though max=2, design tasks are exempt
        self.assertEqual(list(pass_scan.validate_body(1, "t", b, 2)), [])

    def test_no_effort_default_silent(self):
        # Without the opt-in flag, a missing Effort line is silent.
        pass_scan._WARN_NO_EFFORT = False
        b = "**Summary:** ...\n"
        self.assertEqual(list(pass_scan.validate_body(1, "t", b, 2)), [])

    def test_no_effort_warn_optin(self):
        old = pass_scan._WARN_NO_EFFORT
        pass_scan._WARN_NO_EFFORT = True
        try:
            b = "**Summary:** ...\n"
            f = list(pass_scan.validate_body(1, "t", b, 2))
            self.assertEqual(len(f), 1)
            self.assertEqual(f[0].kind, "warning")
        finally:
            pass_scan._WARN_NO_EFFORT = old


class PassCountTest(unittest.TestCase):
    def test_counts_lines(self):
        b = body("3-5 runs", passes="Pass 1 — a.\nPass 2 — b.\nPass 3 — c.")
        self.assertEqual(pass_scan.count_pass_lines(b), 3)

    def test_counts_only_inside_block(self):
        b = ("**Passes:**\nPass 1 — a.\nPass 2 — b.\n"
             "other text with Pass 3 not meant as a pass line")
        self.assertEqual(pass_scan.count_pass_lines(b), 2)


class MainExitsTest(unittest.TestCase):
    """Offline CLI: --json-file with synthetic issue views."""

    def _run(self, issues):
        import json
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump({"issues": issues}, f)
            p = f.name
        try:
            return pass_scan.main(["--json-file", p])
        finally:
            Path(p).unlink()

    def test_violation_exit_1(self):
        bad = {"number": 10, "title": "multi-run epic",
               "body": body("4-6 runs"), "labels": []}
        good = {"number": 11, "title": "single",
                "body": body("1 run"), "labels": []}
        self.assertEqual(self._run([bad, good]), 1)

    def test_clean_exit_0(self):
        ok = {"number": 1, "title": "single",
              "body": body("1 run"), "labels": []}
        self.assertEqual(self._run([ok]), 0)


@unittest.skipUnless(_TOKEN := __import__("os").environ.get("GITHUB_TOKEN"),
                     "GITHUB_TOKEN not set; live-fetch path not exercised")
class LiveFetchTest(unittest.TestCase):
    def test_live_scan_returns_exitcode(self):
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = pass_scan.main([])
        self.assertIn(rc, (0, 1))


if __name__ == "__main__":
    unittest.main()