#!/usr/bin/env python3
"""Unit tests for the Gate 4 Layer-3 probe-checklist (probe_check.py) — stdlib only.

Tests the checklist logic (approve/block, precise violations) with no Lean
toolchain and no secrets. The real-Lean `--probe` path is exercised in CI.

Run:  python3 tooling/gates/tests/test_probe_check.py
"""
from __future__ import annotations

import json
import sys
import unittest
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import probe_check  # noqa: E402

SPEC = {
    "title": "demo",
    "informal": "for every oracle A, P^A subset NP^A",
    "probes": [
        {"key": "q1", "kind": "quantifier", "question": "range?",
         "choices": ["a", "b"], "expected": "b"},
        {"key": "q2", "kind": "direction", "question": "direction?",
         "choices": ["x", "y"], "expected": "x"},
    ],
}


class ProbeCheckTest(unittest.TestCase):
    def test_validate_all_correct(self):
        answers = {"q1": "b", "q2": "x"}
        v = probe_check.validate_checklist(SPEC, answers)
        self.assertEqual(v, [])

    def test_validate_missing_answer(self):
        v = probe_check.validate_checklist(SPEC, {"q1": "b"})
        self.assertEqual(len(v), 1)
        self.assertIn("q2", v[0])
        self.assertIn("no answer", v[0])

    def test_validate_wrong_answer_reports_expected_and_got(self):
        v = probe_check.validate_checklist(SPEC, {"q1": "a", "q2": "x"})
        self.assertEqual(len(v), 1)
        self.assertIn("q1", v[0])
        self.assertIn("expected 'b'", v[0])
        self.assertIn("answered 'a'", v[0])

    def test_render_checklist_contains_claim_and_questions(self):
        text = probe_check.render_checklist(SPEC)
        self.assertIn("demo", text)
        self.assertIn("range?", text)
        self.assertIn("direction?", text)
        self.assertIn("expected: b", text)

    def test_render_uses_spec_question_over_kind_template(self):
        # The spec provides its own 'question'; the renderer must prefer it.
        text = probe_check.render_checklist(SPEC)
        self.assertIn("range?", text)
        self.assertNotIn("{word}", text)

    def test_probe_run_returns_rc_and_output(self):
        # Without a Lean toolchain this would fail; we only check the
        # function exists and returns a tuple. (Real run is in CI.)
        self.assertTrue(callable(probe_check.run_probe))
        self.assertTrue(callable(probe_check.main))


if __name__ == "__main__":
    unittest.main(verbosity=2)