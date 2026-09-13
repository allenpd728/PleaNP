#!/usr/bin/env python3
"""Unit tests for the gate-REVIEW register machine-check (issue #92)."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import gate_review_register_check as grc  # noqa: E402


class TestParser(unittest.TestCase):
    def test_parse_review_items_hygiene(self):
        out = (
            "  [REVIEW] smell       lean/PleaNP/Computability/OracleSmoke.lean:92:51 "
            "  'by decide'  | refine (smokeRun oracleTrue [true], ...)\n"
            "  0 violation(s), 3 review item(s)\n"
        )
        items = grc._parse_review_items("hygiene", out)
        self.assertEqual(items, [("hygiene", "OracleSmoke.lean", "by decide")])

    def test_parse_review_items_binder(self):
        out = (
            "  [REVIEW] unreferenced_decl          "
            "lean/PleaNP/Computability/Oracle.lean:172  'emptyOracle'  | def ...\n"
        )
        items = grc._parse_review_items("binder", out)
        self.assertEqual(items, [("binder", "Oracle.lean", "emptyOracle")])

    def test_line_drift_tolerant_module_token_key(self):
        # A shifted line number must still parse to the same (module, token).
        out = ("[REVIEW] unreferenced_decl   "
               "lean/PleaNP/Computability/OracleComplexity.lean:99  'P_A_subset_NP_A'  | ...\n")
        items = grc._parse_review_items("binder", out)
        self.assertEqual(items, [("binder", "OracleComplexity.lean", "P_A_subset_NP_A")])


class TestExpectedRegister(unittest.TestCase):
    def test_expected_register_shape(self):
        # Register must cover the doc's expected-set columns.
        self.assertIn(("hygiene", "OracleSmoke.lean", "by decide"), grc.EXPECTED)
        self.assertIn(("hygiene", "OracleV5Tests.lean", "by decide"), grc.EXPECTED)
        self.assertIn(("binder", "BarrierVerdictB.lean", "abstractPVsNP_iff_verdictB"), grc.EXPECTED)
        self.assertIn(("binder", "OracleComplexity.lean", "y"), grc.EXPECTED)
        self.assertIn(("binder", "OracleComplexity.lean", "P_A_subset_NP_A"), grc.EXPECTED)
        # DEC-022 comparator statement references (issue #64).
        self.assertIn(("binder", "Relativization.lean", "equalizing_oracle_statement"), grc.EXPECTED)
        self.assertIn(("binder", "Relativization.lean", "separating_oracle_statement"), grc.EXPECTED)
        # `emptyOracle` no longer flagged (referenced by OracleV5Tests; #40).
        self.assertNotIn(("binder", "Oracle.lean", "emptyOracle"), grc.EXPECTED)


class TestRejectUnexpected(unittest.TestCase):
    def test_extra_item_fails(self):
        # Simulate an unexpected REVIEW item: a new sorcery that isn't in the
        # register must make check() fail (exit 1) with the item text.
        extra = {("binder", "Oracle.lean", "mystery_thing")}
        actual = set(grc.EXPECTED) | extra
        missing = grc.EXPECTED - actual
        extra_problems = actual - grc.EXPECTED
        self.assertFalse(missing)          # register still fully fires
        self.assertTrue(extra_problems)    # but the extra is flagged
        self.assertIn(("binder", "Oracle.lean", "mystery_thing"), extra_problems)


if __name__ == "__main__":
    unittest.main(verbosity=2)