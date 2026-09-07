#!/usr/bin/env python3
# Unit tests for the rendering-disagreement review spec (probe_check.py).
# Tests schema validation (valid/invalid/missing fields) and checklist renderer
# for a rendering disagreement (probes with choices+hint+expected; batch narrative
# prepended; one-wrong-ao-blocked validation output). No Lean toolchain, no
# secrets needed.

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import probe_check  # noqa: E402

VALID_SPEC = {
    "campaign": "bgs-u-b-in-np",
    "lens_a": "structure-first",
    "lens_b": "witness-predicate",
    "informal_claim": "U_B is in NP with oracle B",
    "batch_narrative": "Two renderings disagreed on the shape of the claim.",
    "probes": [
        {"key": "q1", "kind": "quantifier",
         "question": "Does the machine guess?",
         "choices": ["yes", "no"], "expected": "yes",
         "hint": "NP means it can guess."},
        {"key": "q2", "kind": "direction",
         "question": "Which direction?",
         "choices": ["A to B", "B to A"], "expected": "A to B",
         "hint": "Membership of U_B is claimed."},
        {"key": "q3", "kind": "existence",
         "question": "Is a machine exhibited?",
         "choices": ["yes", "no"], "expected": "yes",
         "hint": "A witness machine is the point."},
    ],
}


class RenderingDisagreementTest(unittest.TestCase):
    def test_valid_spec_passes(self):
        self.assertEqual(probe_check.validate_rendering_disagreement_spec(VALID_SPEC), [])

    def test_missing_required_top_level(self):
        spec = dict(VALID_SPEC)
        del spec["lens_a"]
        v = probe_check.validate_rendering_disagreement_spec(spec)
        self.assertIn("missing required field 'lens_a'", v)

    def test_missing_required_probe_field(self):
        spec = json.loads(json.dumps(VALID_SPEC))
        del spec["probes"][0]["hint"]
        v = probe_check.validate_rendering_disagreement_spec(spec)
        self.assertIn("missing required field 'hint'", v[0])

    def test_too_few_probes(self):
        spec = json.loads(json.dumps(VALID_SPEC))
        spec["probes"] = spec["probes"][:2]
        v = probe_check.validate_rendering_disagreement_spec(spec)
        self.assertTrue(any("3-5 items" in x for x in v))

    def test_expected_not_in_choices(self):
        spec = json.loads(json.dumps(VALID_SPEC))
        spec["probes"][0]["expected"] = "maybe"
        v = probe_check.validate_rendering_disagreement_spec(spec)
        self.assertTrue(any("expected value must be one of the choices" in x for x in v))

    def test_unknown_probe_field(self):
        spec = json.loads(json.dumps(VALID_SPEC))
        spec["probes"][0]["bogus"] = 1
        v = probe_check.validate_rendering_disagreement_spec(spec)
        self.assertTrue(any("unknown field" in x for x in v))

    def test_render_includes_batch_narrative_and_probes(self):
        text = probe_check.render_checklist(VALID_SPEC)
        self.assertIn("batch narrative:", text)
        self.assertIn("Two renderings disagreed", text)
        self.assertIn("[q1]", text)
        self.assertIn("choices: yes, no", text)
        self.assertIn("hint: NP means it can guess.", text)
        self.assertIn("expected: yes", text)

    def test_render_uses_spec_question_over_template(self):
        spec = json.loads(json.dumps(VALID_SPEC))
        spec["probes"][1]["question"] = "Custom question?"
        text = probe_check.render_checklist(spec)
        self.assertIn("Custom question?", text)
        self.assertNotIn("{word}", text)

    def test_one_wrong_answer_blocks_with_expected_and_got(self):
        answers = {"q1": "yes", "q2": "B to A", "q3": "yes"}
        v = probe_check.validate_checklist(VALID_SPEC, answers)
        self.assertEqual(len(v), 1)
        self.assertIn("q2", v[0])
        self.assertIn("expected 'A to B'", v[0])
        self.assertIn("answered 'B to A'", v[0])

    def test_example_spec_is_valid(self):
        spec_path = Path(__file__).resolve().parents[1] / "specs" / "rendering_disagreement.example.json"
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        self.assertEqual(probe_check.validate_rendering_disagreement_spec(spec), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)

