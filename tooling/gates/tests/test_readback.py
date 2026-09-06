#!/usr/bin/env python3
"""Unit tests for the Gate 4 read-back harness (readback.py) — stdlib only.

These test the harness LOGIC (agreement, disagreement, blocking, fallback)
using deterministic fake translators — no LLM keys, no Lean toolchain needed.
The Lean-integration path is exercised separately (or in CI with a key).

Run:  python3 tooling/gates/tests/test_readback.py
"""
from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import readback  # noqa: E402


class ReadbackTest(unittest.TestCase):
    def test_agreement_verbatim(self):
        a = "for every oracle A, P^A equals NP^A"
        b = "for every oracle A, P^A equals NP^A"
        ok, expl = readback._agreement(a, b, "none", False)
        self.assertTrue(ok)
        self.assertIn("agree", expl.lower())

    def test_agreement_normalized_whitespace_and_backticks(self):
        a = "`for every oracle A`, P^A equals NP^A"
        b = "for every oracle A,  P^A equals NP^A"
        ok, _ = readback._agreement(a, b, "none", False)
        self.assertTrue(ok)

    def test_disagreement_quantifier_swap(self):
        # Existential vs universal is a REAL semantic difference -> must block.
        a = "there exists an oracle A such that P^A equals NP^A"
        b = "for every oracle A, P^A equals NP^A"
        ok, expl = readback._agreement(a, b, "none", False)
        self.assertFalse(ok)
        self.assertIn("disagree", expl.lower())

    def test_disagreement_equality_vs_containment(self):
        a = "P is equal to NP"
        b = "P is a subset of NP"
        ok, _ = readback._agreement(a, b, "none", False)
        self.assertFalse(ok)

    def test_disagreement_needs_human_never(self):
        # The harness must not manufacture an AGREE for a real difference:
        # a false DISAGREE is safe (blocks), a false AGREE is not.
        a = "for every machine M, M accepts x"
        b = "for every machine M, M rejects x"
        ok, _ = readback._agreement(a, b, "none", False)
        self.assertFalse(ok)

    def test_llm_judge_falls_back_without_key(self):
        saved = (os.environ.pop("OPENAI_API_KEY", None),
                 os.environ.pop("ANTHROPIC_API_KEY", None))
        try:
            ok, _ = readback._llm_judge("for all A, P = NP", "exists B, P != NP")
            self.assertFalse(ok)  # never fabricate an AGREE
        finally:
            if saved[0] is not None:
                os.environ["OPENAI_API_KEY"] = saved[0]
            if saved[1] is not None:
                os.environ["ANTHROPIC_API_KEY"] = saved[1]

    def test_translator_b_falls_back_to_deterministic_without_key(self):
        saved = (os.environ.pop("OPENAI_API_KEY", None),
                 os.environ.pop("ANTHROPIC_API_KEY", None))
        original = readback.lean_readback.extract_type

        def fake_extract(module, decl, lean_dir):
            return "forall A : Type, P A -> NP A"

        readback.lean_readback.extract_type = fake_extract
        try:
            a = readback.translator_a("x", "m", Path("."))
            b = readback.translator_b("x", "m", Path("."), llm_env={})
            self.assertEqual(readback._normalize(a), readback._normalize(b))
        finally:
            readback.lean_readback.extract_type = original
            if saved[0] is not None:
                os.environ["OPENAI_API_KEY"] = saved[0]
            if saved[1] is not None:
                os.environ["ANTHROPIC_API_KEY"] = saved[1]

    def test_translator_b_never_returns_none(self):
        original = readback.lean_readback.extract_type

        def fake_extract(module, decl, lean_dir):
            return "forall A : Type, P A -> NP A"

        readback.lean_readback.extract_type = fake_extract
        try:
            s = readback.translator_b("any", "m", Path("."), llm_env={})
            self.assertIsInstance(s, str)
            self.assertTrue(s)
        finally:
            readback.lean_readback.extract_type = original


if __name__ == "__main__":
    unittest.main(verbosity=2)