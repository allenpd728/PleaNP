#!/usr/bin/env python3
"""Unit tests for the effort re-sum tool (`effort_summary.py`).

Stdlib-only, no secrets, no GitHub calls: uses synthetic issue bodies via
`pass_scan.parse_issue_view`. Verifies the rung map, the totals arithmetic
(per-rung, total, proof-search entry incl. the Rung-6 split), the no-effort
handling, and the CSV/table-row CLI outputs.

Run:  python3 tooling/gates/tests/test_effort_summary.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import effort_summary  # noqa: E402
from pass_scan import parse_issue_view  # noqa: E402


def issue(number, title, body):
    return parse_issue_view({"number": number, "title": title, "body": body,
                             "labels": []})


class SummarizeTest(unittest.TestCase):
    def setUp(self):
        # A small synthetic queue: R2 (#35, #40), R3 (#22), R5 (#65), R6 (#77)
        self.issues = [
            issue(35, "v5", "**Effort:** 2-4 runs."),
            issue(40, "tests v5", "**Effort:** 1 run."),
            issue(22, "diag", "**Effort:** 3 runs."),
            issue(65, "soundness", "**Effort:** 1 run."),
            issue(77, "gap", "**Effort:** 2-4 runs."),
        ]

    def test_per_rung_and_total(self):
        s = effort_summary.summarize(self.issues)
        self.assertEqual(s["by_rung"]["2"], (3, 5))      # 2-4 + 1
        self.assertEqual(s["by_rung"]["3"], (3, 3))
        self.assertEqual(s["by_rung"]["5"], (1, 1))
        self.assertEqual(s["by_rung"]["6"], (2, 4))
        self.assertEqual(s["total"], (9, 13))            # 3+3+1+2 .. 5+3+1+4

    def test_proof_search_split(self):
        s = effort_summary.summarize(self.issues)
        self.assertEqual(s["proof_search"], (9, 13))
        self.assertEqual(s["r6"], (2, 4))
        self.assertEqual(s["proof_search_no_r6"], (7, 9))

    def test_no_effort_counted_zero(self):
        issues = self.issues + [issue(83, "meta", "**Summary:** only")]
        s = effort_summary.summarize(issues)
        self.assertEqual(s["no_effort_issues"], {"meta": 1})
        # total unchanged: no-effort row contributes 0 runs
        self.assertEqual(s["total"], (9, 13))

    def test_unknown_issue_skipped(self):
        issues = self.issues + [issue(999, "unmapped", "**Effort:** 9 runs.")]
        s = effort_summary.summarize(issues)
        self.assertEqual(s["total"], (9, 13))


class CliTest(unittest.TestCase):
    def _run_summary(self, issues, extra=()):
        import contextlib
        import io
        import json
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump([{
                "number": i.number, "title": i.title, "body": i.body,
                "labels": [{"name": l} for l in i.labels]} for i in issues], f)
            p = f.name
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                rc = effort_summary.main(["--json-file", p, *extra])
            out = buf.getvalue()
        finally:
            Path(p).unlink()
        return rc, out

    def test_csv(self):
        issues = [issue(35, "v5", "**Effort:** 2-4 runs."),
                  issue(65, "sound", "**Effort:** 1 run.")]
        rc, out = self._run_summary(issues, extra=("--csv",))
        self.assertEqual(rc, 0)
        self.assertIn("issue,rung,effort_lo,effort_hi,title", out)
        self.assertIn("35,2,2,4", out)
        self.assertIn("65,5,1,1", out)

    def test_table_rows(self):
        issues = [issue(35, "v5", "**Effort:** 2-4 runs.")]
        rc, out = self._run_summary(issues, extra=("--table-rows",))
        self.assertEqual(rc, 0)
        self.assertIn("| Rung 2 substrate | 2 → 4 | |", out)


if __name__ == "__main__":
    unittest.main()