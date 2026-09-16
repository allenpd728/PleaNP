#!/usr/bin/env python3
"""Tests for the prose-corruption scan (PleaNP #101).

A guard that cannot detect the failure it exists for is worthless, so each
violation class is asserted caught, and — critically — the legitimate Lean
constructs that *look* like corruption (space-free tuples like `⟨n,x⟩`,
`(true,true)`, inline code spans) are asserted NOT to be flagged.

Run: python3 tooling/gates/tests/test_prose_scan.py
"""
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
GUARD = REPO / "tooling" / "gates" / "prose_scan.py"
sys.path.insert(0, str(GUARD.parent))

import prose_scan as p  # noqa: E402


def scan_text(text: str, suffix: str = ".lean") -> list[str]:
    with tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False) as fh:
        fh.write(text)
        tmp = Path(fh.name)
    try:
        return p.scan_file(tmp, allowed=False)
    finally:
        tmp.unlink()


class TestProseScan(unittest.TestCase):
    def test_doubled_punctuation_caught(self):
        self.assertTrue(scan_text("/-- a comment,,with a doubled comma -/\n"))
        self.assertTrue(scan_text("/-- a comment;;with a doubled semicolon -/\n"))
        self.assertTrue(scan_text("/-- rationale..issue one -/\n"))

    def test_canonical_101_double_period_caught(self):
        # Issue #101's own canonical example: period doubled before a space.
        self.assertTrue(scan_text("/-- below for the full rationale.. Issue #1 -/\n"))

    def test_numeric_range_not_flagged(self):
        self.assertEqual(scan_text("/-- a block (Pass 1..n, each = one run) -/\n"), [])

    def test_colon_absorbed_space_caught(self):
        self.assertTrue(scan_text("/-- Marker:the construction relativizes -/\n"))

    def test_semicolon_absorbed_space_caught(self):
        self.assertTrue(scan_text("/-- it holds;and stays true -/\n"))

    def test_string_literal_corruption_caught(self):
        # The #101 signature also lives in machine-authored prose inside Lean
        # string literals (the #barrier_check verdict templates).
        src = 'def f : String := "a fused;so is this"\n'
        self.assertTrue(scan_text(src))

    def test_clean_string_literal_not_flagged(self):
        src = 'def f : String := "a well-formed; still fine sentence."\n'
        self.assertEqual(scan_text(src), [])

    def test_comma_absorbed_space_caught(self):
        self.assertTrue(scan_text("/-- the functions themselves,not any query -/\n"))

    def test_lean_tuple_notation_not_flagged(self):
        # The false-positive class: space-free bracketed groups.
        self.assertEqual(scan_text("/-- add the point ⟨n,x⟩ to the oracle -/\n"), [])
        self.assertEqual(scan_text("/-- and2 on (true,true) is satisfiable -/\n"), [])
        self.assertEqual(scan_text("/-- run ea (n,y) for steps -/\n"), [])

    def test_code_span_not_flagged(self):
        self.assertEqual(scan_text("/-- see `foo,bar` and `a:b` for details -/\n"), [])

    def test_ellipsis_not_flagged(self):
        self.assertEqual(scan_text("/-- stages B_0 ⊆ B_1 ⊆ ... hold -/\n"), [])

    def test_code_line_not_flagged(self):
        # A real (non-comment) Lean line with a tuple must never be flagged.
        src = "def f : Nat × Nat := (1,2)\n"
        self.assertEqual(scan_text(src), [])

    def test_clean_comment_not_flagged(self):
        self.assertEqual(scan_text("/-- A well-written sentence, with spaces. -/\n"), [])

    def test_live_tree_is_clean_of_scanner_crashes(self):
        # The scan must run over the real tree without raising.
        p.scan([REPO / "lean" / "PleaNP"], set())


if __name__ == "__main__":
    unittest.main()