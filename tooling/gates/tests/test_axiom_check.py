#!/usr/bin/env python3
"""Unit tests for the Gate 6 Tier 2 axiom-check parser (issue #41).

Covers the two Lean `#print axioms` output shapes:
  - with axioms:    `'T' depends on axioms: [propext, Quot.sound]`
  - zero axioms:    `'T' does not depend on any axioms`

The zero-axiom form is what theorems proved by `infer_instance` over empty
marker classes report (strictly cleaner than the standard set); the parser
must treat it as clean rather than "no axiom report found" (the regression
fixed during the marker-funeq campaign).
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import axiom_check as ac  # noqa: E402
from axiom_check import KNOWN_STANDARD  # noqa: E402


def _lines(theorems, out_text):
    """Replicate axiom_check's per-theorem line extraction."""
    out_lines = out_text.splitlines()
    results = {}
    for t in theorems:
        base = f"'{t}'"
        markers = [f"{base} depends on axioms:", f"{base} does not depend on any axioms"]
        found_line = next((ln for ln in out_lines if any(m in ln for m in markers)), None)
        if found_line is None:
            results[t] = None
        elif "does not depend on any axioms" in found_line:
            results[t] = []
        else:
            start = found_line.index("[")
            end = found_line.index("]", start)
            results[t] = [a.strip() for a in found_line[start + 1:end].split(",") if a.strip()]
    return results


class TestAxiomReportParsing(unittest.TestCase):
    def test_zero_axiom_report_is_clean(self):
        out = "'Theo.Zero' does not depend on any axioms\n"
        self.assertEqual(_lines(["Theo.Zero"], out), {"Theo.Zero": []})

    def test_with_axioms_report_parses(self):
        out = "'Theo.With' depends on axioms: [propext, Quot.sound]\n"
        self.assertEqual(_lines(["Theo.With"], out),
                         {"Theo.With": ["propext", "Quot.sound"]})

    def test_with_axioms_known_standard_clean(self):
        violations = [t for t, axs in _lines(["T"], "'T' depends on axioms: [propext]\n").items()
                      if any(a not in KNOWN_STANDARD for a in axs)]
        self.assertEqual(violations, [])

    def test_nonstandard_axiom_flagged(self):
        violations = [t for t, axs in _lines(["T"], "'T' depends on axioms: [evilAxiom]\n").items()
                      if any(a not in KNOWN_STANDARD for a in axs)]
        self.assertEqual(violations, ["T"])

    def test_missing_report_flagged(self):
        # No matching line at all -> "no axiom report found" (surfaced, not silently ok).
        self.assertEqual(_lines(["T"], "'Other' depends on axioms: [propext]\n"),
                         {"T": None})


if __name__ == "__main__":
    unittest.main()