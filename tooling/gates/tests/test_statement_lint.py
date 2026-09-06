#!/usr/bin/env python3
"""Unit tests for the statement linter (statement_lint.py) — stdlib only.

Tests the pure-code SHAPE classification (no Lean toolchain, no LLM) by
feeding pretty-printed type texts directly to classify().

Run:  python3 tooling/gates/tests/test_statement_lint.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import statement_lint  # noqa: E402


class StatementLintTest(unittest.TestCase):
    def test_containment_theorem(self):
        t = "{Q : Type} (alpha : Type) (A : Oracle Q) : P_A A ⊆ NP_A A"
        f = statement_lint.classify(t)
        self.assertIn("containment/subset (⊆)", f["relations"])
        self.assertTrue(f["oracle_dependence"])
        self.assertIn("P_A", f["classes"])
        self.assertIn("NP_A", f["classes"])
        self.assertIn("containment/subset", f["english"])

    def test_quantified_def(self):
        t = "∀ (O : Type) (A : AbstOracle O), ∃ L, LangAtom O A L"
        f = statement_lint.classify(t)
        self.assertEqual(f["quantifiers"], ["for every (∀)", "there exists (∃)"])
        self.assertTrue(f["oracle_dependence"])
        self.assertIn("for every", f["english"])

    def test_equality_vs_containment_distinguished(self):
        eq = statement_lint.classify("∃ A : Oracle Q, P_A A = NP_A A")
        sub = statement_lint.classify("∀ A : Oracle Q, P_A A ⊆ NP_A A")
        self.assertIn("equality (=)", eq["relations"])
        self.assertIn("containment/subset (⊆)", sub["relations"])
        # equality and containment must NOT be conflated
        self.assertNotIn("containment/subset", eq["english"])
        self.assertNotIn("equality (=)", sub["relations"])

    def test_inequality_detected(self):
        f = statement_lint.classify("∃ B : Oracle Q, P_A B ≠ NP_A B")
        self.assertIn("inequality (≠)", f["relations"])
        self.assertEqual(f["quantifiers"], ["there exists (∃)"])

    def test_no_oracle_no_classes(self):
        f = statement_lint.classify("∀ x : Nat, x ≤ x + 1")
        self.assertFalse(f["oracle_dependence"])
        self.assertNotIn("P_A", f["classes"])
        self.assertIn("less-equal (≤)", f["relations"])
        self.assertEqual(f["quantifiers"], ["for every (∀)"])

    def test_connective_detection(self):
        f = statement_lint.classify("(A x) ∧ (B x) → (C x)")
        self.assertIn("and (∧)", f["connectives"])
        self.assertIn("implies (→)", f["connectives"])


if __name__ == "__main__":
    unittest.main(verbosity=2)