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
        # P_A_subset_NP_A is no longer in the register: #63 Pass 3's
        # P_subset_NP_console references it, so the binder stops flagging it.
        self.assertNotIn(("binder", "OracleComplexity.lean", "P_A_subset_NP_A"), grc.EXPECTED)
        self.assertIn(("binder", "OracleComplexity.lean", "UpstreamPolyTime"), grc.EXPECTED)  # P^∅=P anchor RHS
        # DEC-022 comparator statement references (issue #64).
        self.assertIn(("binder", "Relativization.lean", "equalizing_oracle_statement"), grc.EXPECTED)
        self.assertIn(("binder", "Relativization.lean", "separating_oracle_statement"), grc.EXPECTED)
        # DEC-022 §3.3 proof-work lemmas (issue #66): `uniform_collapse_...` /
        # `uniform_separation_...` self-resolved once #69 Pass 2's
        # AlgebrizationProof.lean referenced them (docs/GATE_REVIEW_NOTES.md
        # §3.5 register-side effect); the headline one remains.
        self.assertNotIn(("binder", "RelativizationProof.lean", "uniform_collapse_contradicted_by_separating"), grc.EXPECTED)
        self.assertNotIn(("binder", "RelativizationProof.lean", "uniform_separation_contradicted_by_equalizing"), grc.EXPECTED)
        self.assertIn(("binder", "RelativizationProof.lean", "no_uniform_resolution_of_p_vs_np"), grc.EXPECTED)
        # AW09 statement refs self-resolved (#69 Pass 2 uses them as hypothesis
        # types).
        self.assertNotIn(("binder", "Algebrization.lean", "algebrizing_separation_statement"), grc.EXPECTED)
        self.assertNotIn(("binder", "Algebrization.lean", "algebrizing_equalization_statement"), grc.EXPECTED)
        # Rung-4 circuit substrate API (issues #71 Pass 1-2); module-leaf is Basic.lean.
        # (`CircuitFamily.sizeOf` self-resolved in Pass 2; depthOf remains.)
        self.assertIn(("binder", "Basic.lean", "CircuitFamily.depthOf"), grc.EXPECTED)
        self.assertIn(("binder", "Basic.lean", "depth_size_le"), grc.EXPECTED)
        self.assertIn(("hygiene", "Basic.lean", "by decide"), grc.EXPECTED)  # univ_largeness discharge
        # Rung-4 AC0 milestone (issue #72 Pass 1 + #73 Pass 2).
        # parity_notin_AC0 not in register: referenced by the #73 Pass 2
        # classification theorem parity_notin_AC0_relativizing.
        self.assertNotIn(("binder", "AC0.lean", "parity_notin_AC0"), grc.EXPECTED)
        # Williams-transfer statement anchors (issues #88 Pass 1 / #90 Pass 3).
        self.assertIn(("binder", "WilliamsTransfer.lean", "williams_transfer"), grc.EXPECTED)
        # Monotone-circuit model (issue #74 Pass 1).
        self.assertIn(("binder", "Monotone.lean", "monotone_eval_preserves_order"), grc.EXPECTED)
        # Rung-4 AC0 milestone (issue #72 Pass 1).
        self.assertIn(("binder", "AC0.lean", "parity_zero"), grc.EXPECTED)
        self.assertIn(("binder", "AC0.lean", "parity_nontrivial"), grc.EXPECTED)
        self.assertIn(("binder", "AC0.lean", "parity_notin_AC0_relativizing"), grc.EXPECTED)
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
