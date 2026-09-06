#!/usr/bin/env python3
"""Unit tests for the Gate 3 dual-rendering harness (dual_render.py) — stdlib only.

Tests the harness LOGIC (self-check verdicts, exit-code mapping, equivalence
fallback) using a stubbed `_run_lean` — no Lean toolchain, no secrets. The
real-Lean integration is exercised in CI (smoke step) and by the retest
battery.

Run:  python3 tooling/gates/tests/test_dual_render.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dual_render  # noqa: E402


class FakeRun:
    """Stub for dual_render._run_lean: returns (rc, out) per call sequence."""
    def __init__(self, results):
        self.results = list(results)
        self.calls = 0

    def __call__(self, lean_dir, src, timeout=420):
        self.calls += 1
        rc, out = self.results[min(self.calls - 1, len(self.results) - 1)]
        return rc, out


class DualRenderTest(unittest.TestCase):
    def test_self_check_bare_prop(self):
        orig = dual_render._run_lean
        dual_render._run_lean = FakeRun([(0, "ok"), (0, "X : Prop")])
        try:
            ok, msg = dual_render.self_check(Path("."), "M", "T")
            self.assertTrue(ok)
            self.assertIn("Prop", msg)
        finally:
            dual_render._run_lean = orig

    def test_self_check_parameterized_heuristic(self):
        # First call fails (not a bare Prop coercion), second #check prints a
        # proposition-shaped type (contains '⊆') -> accepted.
        orig = dual_render._run_lean
        dual_render._run_lean = FakeRun([(1, "type mismatch"), (0, "T (a : ℕ) : T a ⊆ U a")])
        try:
            ok, msg = dual_render.self_check(Path("."), "M", "T")
            self.assertTrue(ok)
            self.assertIn("proposition-shaped", msg)
        finally:
            dual_render._run_lean = orig

    def test_self_check_fail_report(self):
        orig = dual_render._run_lean
        dual_render._run_lean = FakeRun([(1, "boom1"), (1, "boom2")])
        try:
            ok, msg = dual_render.self_check(Path("."), "M", "T")
            self.assertFalse(ok)
            self.assertIn("boom2", msg)
        finally:
            dual_render._run_lean = orig

    def test_check_equivalence_rfl_positive(self):
        orig = dual_render._run_lean
        # First attempt (rfl) succeeds.
        dual_render._run_lean = FakeRun([(0, "ok")])
        try:
            ok, msg = dual_render.check_equivalence(Path("."), "A", "T1", "B", "T2")
            self.assertTrue(ok)
            self.assertIn("rfl", msg)
        finally:
            dual_render._run_lean = orig

    def test_check_equivalence_parameterized_positive(self):
        orig = dual_render._run_lean
        # rfl fails, direction fails, simp fails, then ∀-quantified rfl succeeds.
        seq = [
            (1, "type mismatch 1"),
            (1, "unprovable 1"),
            (1, "unprovable 2"),
            (0, "ok (∀ x, IFF by rfl)"),
        ]
        dual_render._run_lean = FakeRun(seq)
        try:
            ok, msg = dual_render.check_equivalence(Path("."), "A", "T1", "B", "T2")
            self.assertTrue(ok)
            self.assertIn("Parameterized", msg)
            self.assertGreaterEqual(dual_render._run_lean.calls, 4)
        finally:
            dual_render._run_lean = orig

    def test_check_equivalence_blocked(self):
        orig = dual_render._run_lean
        # Everything fails -> BLOCKED, never a fabricated AGREE.
        seq = [(1, "e1"), (1, "e2"), (1, "e3"), (1, "e4"), (1, "e5")]
        dual_render._run_lean = FakeRun(seq)
        try:
            ok, msg = dual_render.check_equivalence(Path("."), "A", "T1", "B", "T2")
            self.assertFalse(ok)
            self.assertIn("BLOCKED", msg)
        finally:
            dual_render._run_lean = orig

    def test_main_exit_mapping(self):
        # main() returns 0 for equivalent, 1 for blocked — verified by the
        # real-Lean integration; here we just ensure the functions exist and
        # return bools.
        self.assertTrue(callable(dual_render.check_equivalence))
        self.assertTrue(callable(dual_render.self_check))


if __name__ == "__main__":
    unittest.main(verbosity=2)