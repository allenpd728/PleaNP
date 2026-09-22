#!/usr/bin/env python3
"""Tests for the SORRY_TRACKER scan (PleaNP #127).

A guard that cannot detect the drift it exists for is worthless: each failure
mode found in the live tree is asserted to be caught, and a matching tracker is
asserted to be accepted. stdlib-only; no Lean, no network.

Run: python3 tooling/gates/tests/test_sorry_tracker_scan.py
"""
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO / "tooling" / "gates"))

import sorry_tracker_scan as s  # noqa: E402


def _repo(tmp: Path, lean_files: dict[str, str], tracker: str) -> Path:
    for rel, body in lean_files.items():
        p = tmp / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body, encoding="utf-8")
    (tmp / "docs").mkdir(exist_ok=True)
    (tmp / "docs" / "SORRY_TRACKER.md").write_text(tracker, encoding="utf-8")
    return tmp


MATCHING = """# Sorry tracker

## Summary

| File | `sorry` count | Level |
|---|---|---|
| `lean/PleaNP/A.lean` | 1 | Substrate |
| **Total** | **1 open** | |

## Detailed inventory

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 7 | `A.lean:4` | a real pending proof. | Upstream P. | Medium |
"""

STALE_LINE = MATCHING.replace("`A.lean:4`", "`A.lean:2`")
STALE_COUNT = MATCHING.replace("| **1 open** |", "| **2 open** |")
UNTRACKED = """| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 7 | `A.lean:2` | wrong line, real site at 4. | Upstream P. | Medium |
"""

LEAN = "namespace A\n\ntheorem t : True := by\n  sorry\n\nend A\n"
SOURCE = {"lean/PleaNP/A.lean": LEAN}


class TestSorryTrackerScan(unittest.TestCase):
    def _check(self, lean_files, tracker):
        with tempfile.TemporaryDirectory() as d:
            return s.check(_repo(Path(d), lean_files, tracker))

    def test_matching_tracker_is_clean(self):
        ok, problems = self._check(SOURCE, MATCHING)
        self.assertTrue(ok, problems)
        self.assertEqual(problems, [])

    def test_stale_line_number_is_caught(self):
        ok, problems = self._check(SOURCE, STALE_LINE)
        self.assertFalse(ok)
        self.assertTrue(any("not a `sorry` site" in p for p in problems), problems)

    def test_undercounted_total_is_caught(self):
        ok, problems = self._check(SOURCE, STALE_COUNT)
        self.assertFalse(ok)
        self.assertTrue(any("Total claims 2 open, actual 1" in p for p in problems), problems)

    def test_untracked_sorry_site_is_caught(self):
        ok, problems = self._check(SOURCE, UNTRACKED)
        self.assertFalse(ok)
        self.assertTrue(any("has no open row" in p for p in problems), problems)

    def test_sorry_in_comment_is_not_a_site(self):
        src = {"lean/PleaNP/A.lean": "-- sorry, none here\ntheorem t : True := trivial\n"}
        ok, problems = self._check(src, MATCHING)
        # No actual sites: the row now dangles, and that is the reported defect.
        self.assertFalse(ok)
        self.assertTrue(any("not a `sorry` site" in p for p in problems), problems)

    def test_resolved_row_is_not_open_debt(self):
        tracker = (
            "## Detailed inventory\n\n"
            "| # | File:Line | What it is | Pending on | Priority |\n"
            "|---|---|---|---|---|\n"
            "| 6 | ~~`A.lean:4`~~ **Resolved** — RHS was `{ L | sorry }`. | — | — |\n"
        )
        ok, problems = self._check(SOURCE, tracker)
        self.assertFalse(ok)  # the real site at A.lean:3 is still untracked
        self.assertTrue(any("has no open row" in p for p in problems), problems)
        self.assertFalse(any("#6" in p for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
