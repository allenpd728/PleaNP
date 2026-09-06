#!/usr/bin/env python3
"""Unit tests for the Gate 3 multi_render driver (multi_render.py) — stdlib only.

Uses a temp CHURN root so tests never touch the real multi_render/ tree, and stubs
dual_render.check_equivalence so no Lean is needed. Tests the pipeline:
init -> render -> check (matrix) -> mine (review points).

Run:  python3 tooling/gates/tests/test_multi_render.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import multi_render  # noqa: E402


class multi_renderTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        multi_render.CHURN = Path(self._tmp.name) / "multi_render"
        # Point review_inbox at a temp tree too (multi_render.mine calls it).
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
        self.assertEqual(multi_render.init("demo", "some claim"), 0)
        ws = multi_render._ws("demo")
        self.assertTrue((ws / "informal.md").exists())
        self.assertTrue((ws / "renderings").is_dir())

    def test_render_registers(self):
        multi_render.init("demo", "c")
        self.assertEqual(multi_render.render("demo", "r1", "M", "T"), 0)
        self.assertEqual(len(list(multi_render._ws("demo").glob("renderings/*.json"))), 1)

    def test_render_requires_init(self):
        self.assertEqual(multi_render.render("nope", "r1", "M", "T"), 1)

    def test_check_requires_two(self):
        multi_render.init("demo", "c")
        multi_render.render("demo", "r1", "M", "T")
        self.assertEqual(multi_render.check("demo", Path(".")), 1)

    def test_check_builds_matrix_with_stubbed_equiv(self):
        multi_render.init("demo", "c")
        multi_render.render("demo", "r1", "MA", "TA")
        multi_render.render("demo", "r2", "MB", "TB")
        calls = []
        def fake(lean_dir, a_mod, a_t, b_mod, b_t, lemma=None):
            calls.append((a_t, b_t))
            return (True, "ok") if a_t == "TA" and b_t == "TB" else (False, "nope")
        orig = multi_render.dual_render.check_equivalence
        multi_render.dual_render.check_equivalence = fake
        try:
            self.assertEqual(multi_render.check("demo", Path(".")), 0)
        finally:
            multi_render.dual_render.check_equivalence = orig
        matrix = json.loads((multi_render._ws("demo") / "matrix.json").read_text())
        self.assertEqual(matrix["pairs"][0]["equivalent"], True)
        self.assertEqual(len(calls), 1)

    def test_mine_emits_review_point_per_disagreement(self):
        multi_render.init("demo", "the informal claim")
        multi_render.render("demo", "r1", "MA", "TA")
        multi_render.render("demo", "r2", "MB", "TB")
        multi_render.dual_render.check_equivalence = lambda ld, a, b, c, d, lemma=None: (False, "disagree")
        self.assertEqual(multi_render.check("demo", Path(".")), 0)
        self.assertEqual(multi_render.mine("demo"), 0)
        pending = list(multi_render.review_inbox.PENDING.glob("*.yaml"))
        self.assertEqual(len(pending), 1)
        text = pending[0].read_text()
        self.assertIn("disagree", text.lower().split("machine_summary:")[1].split("\n")[0].lower())
        self.assertIn("question:", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)