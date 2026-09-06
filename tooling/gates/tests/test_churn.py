#!/usr/bin/env python3
"""Unit tests for the Gate 3 churn driver (churn.py) — stdlib only.

Uses a temp CHURN root so tests never touch the real churn/ tree, and stubs
dual_render.check_equivalence so no Lean is needed. Tests the pipeline:
init -> render -> check (matrix) -> mine (review points).

Run:  python3 tooling/gates/tests/test_churn.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import churn  # noqa: E402


class ChurnTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        churn.CHURN = Path(self._tmp.name) / "churn"
        # Point review_inbox at a temp tree too (churn.mine calls it).
        import review_inbox
        self._rroot = Path(self._tmp.name) / "reviews"
        review_inbox.REVIEWS = self._rroot
        review_inbox.PENDING = self._rroot / "pending"
        review_inbox.CONFIRMED = self._rroot / "confirmed"
        review_inbox.FLAGGED = self._rroot / "flagged"
        review_inbox.INBOX = self._rroot / "INBOX.md"
        for d in (review_inbox.PENDING, review_inbox.CONFIRMED, review_inbox.FLAGGED):
            d.mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self._tmp.cleanup()

    def test_init_creates_workspace(self):
        self.assertEqual(churn.init("demo", "some claim"), 0)
        ws = churn._ws("demo")
        self.assertTrue((ws / "informal.md").exists())
        self.assertTrue((ws / "renderings").is_dir())

    def test_render_registers(self):
        churn.init("demo", "c")
        self.assertEqual(churn.render("demo", "r1", "M", "T"), 0)
        self.assertEqual(len(list(churn._ws("demo").glob("renderings/*.json"))), 1)

    def test_render_requires_init(self):
        self.assertEqual(churn.render("nope", "r1", "M", "T"), 1)

    def test_check_requires_two(self):
        churn.init("demo", "c")
        churn.render("demo", "r1", "M", "T")
        self.assertEqual(churn.check("demo", Path(".")), 1)

    def test_check_builds_matrix_with_stubbed_equiv(self):
        churn.init("demo", "c")
        churn.render("demo", "r1", "MA", "TA")
        churn.render("demo", "r2", "MB", "TB")
        calls = []
        def fake(lean_dir, a_mod, a_t, b_mod, b_t):
            calls.append((a_t, b_t))
            return (True, "ok") if a_t == "TA" and b_t == "TB" else (False, "nope")
        orig = churn.dual_render.check_equivalence
        churn.dual_render.check_equivalence = fake
        try:
            self.assertEqual(churn.check("demo", Path(".")), 0)
        finally:
            churn.dual_render.check_equivalence = orig
        matrix = json.loads((churn._ws("demo") / "matrix.json").read_text())
        self.assertEqual(matrix["pairs"][0]["equivalent"], True)
        self.assertEqual(len(calls), 1)

    def test_mine_emits_review_point_per_disagreement(self):
        churn.init("demo", "the informal claim")
        churn.render("demo", "r1", "MA", "TA")
        churn.render("demo", "r2", "MB", "TB")
        churn.dual_render.check_equivalence = lambda ld, a, b, c, d: (False, "disagree")
        self.assertEqual(churn.check("demo", Path(".")), 0)
        self.assertEqual(churn.mine("demo"), 0)
        pending = list(churn.review_inbox.PENDING.glob("*.yaml"))
        self.assertEqual(len(pending), 1)
        text = pending[0].read_text()
        self.assertIn("disagree", text.lower().split("machine_summary:")[1].split("\n")[0].lower())
        self.assertIn("question:", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)