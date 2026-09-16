#!/usr/bin/env python3
"""Unit tests for the Gate 8 Tier 1 Unicode-hygiene scanner (`unicode_scan.py`).

Stdlib-only, no Lean toolchain, no secrets: every rule is a pure text
function, so the full behavior is covered offline with synthetic snippets
written to a temp dir.

Run:  python3 tooling/gates/tests/test_unicode_scan.py
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import unicode_scan  # noqa: E402


class ScanTextTest(unittest.TestCase):
    """scan_text takes (text, path, allow, lrm_legal) and returns Findings."""

    def _scan(self, text: str, filename: str = "x.md",
              allow: set[str] | None = None, lrm_legal: bool = False) -> list:
        return unicode_scan.scan_text(text, Path(filename), allow=allow,
                                      lrm_legal=lrm_legal)

    def test_fullwidth_paren_is_flagged(self):
        found = self._scan("\uff08 see the (note) \uff09")
        kinds = [f.kind for f in found]
        # a fullwidth \uff08 and \uff09 are flagged
        self.assertEqual(len(found), 2)
        self.assertTrue(all(k == "fullwidth" for k in kinds))

    def test_fullwidth_comma_and_plus(self):
        found = self._scan("a\uff0bb, c\uff0cd")
        bychar = {f.char: f.kind for f in found}
        self.assertEqual(bychar, {"\uff0b": "fullwidth", "\uff0c": "fullwidth"})

    def test_cjk_full_stop_flagged(self):
        found = self._scan("no-spec\u3002")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].char, "\u3002")
        self.assertEqual(found[0].kind, "cjk-punct")

    def test_cjk_comma_flagged(self):
        found = self._scan("a\u3001b")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "cjk-punct")

    def test_zwsp_flagged(self):
        found = self._scan("exit \u200b0")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "invisible-zw")

    def test_lrm_violation_outside_bidi_files(self):
        # An LRM in an ordinary file is a violation.
        found = self._scan("\u200e2,655", lrm_legal=False)
        self.assertTrue(any(f.kind == "invisible-bidi" and f.char == "\u200e"
                            for f in found))

    def test_lrm_soft_in_bidi_file(self):
        # In the two bidi-sensitive files it is SOFT (reported, exit 0),
        # which scan() treats as non-violation. scan_text still returns it.
        found = self._scan("\u200e2,655", lrm_legal=True)
        self.assertTrue(any(f.kind == "invisible-bidi" and f.char == "\u200e"
                            for f in found))

    def test_combining_after_letter_is_legal(self):
        # B + U+0303 = B-tilde. The only correct spelling (no precomposed
        # B-tilde exists). Must NOT be flagged.
        found = self._scan("B\u0303")
        self.assertEqual(found, [])

    def test_combining_macron_after_space_flagged(self):
        # "##  ¯3." corruption: combining macron after a space.
        found = self._scan("##  \u03043. The BGS-facing")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "combining")

    def test_combining_char_glued_to_space_flagged(self):
        # "slot  `CorruptWord`2" corruption: combining latin-small-c
        # (U+0368) after a space.
        found = self._scan("slot  \u03682")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "combining")

    def test_devanagari_danda_flagged(self):
        found = self._scan("length\u0964the tape")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "devanagari")

    def test_circled_digit_flagged(self):
        found = self._scan("per §4.2\u2463")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "circled")

    def test_emoji_vs16_legal(self):
        # ⚠️ = U+26A0 + U+FE0F. Legal after an emoji base.
        found = self._scan("⚠\ufe0f spec failed")
        self.assertEqual(found, [])

    def test_bare_vs16_flagged(self):
        found = self._scan("u\uFE0F")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].kind, "vs")

    def test_math_glyphs_legal(self):
        # The project's genuine math/Lean glyphs must not be flagged.
        sample = ("∀ ∃ ∈ ⊆ ∧ ∨ ¬ ≠ ℕ ∅ ▸ · § Γ Σ Ω α β → ↔ ↦ ⟨⟩ ⇒ ⇔ "
                  "₀₁₂₃ ⁰⁴⁵ ² ³ ¹ … — – ‘ ’ “ ” 𝒞 𝒫")
        self.assertEqual(self._scan(sample), [])

    def test_greek_and_box_legal(self):
        sample = ("Γ kq : Fin (tm.Γ.length)   ⊔ ⊓ ⊗ ⊕ …")
        self.assertEqual(self._scan(sample), [])

    def test_latin1_accents_legal(self):
        sample = "Jeřábek č è ö Ã"
        self.assertEqual(self._scan(sample), [])

    def test_allow_exact_char_wins(self):
        # `--allow` / `--allow-file` provide the audited escape hatch.
        found = self._scan("\uff08note\uff09", allow={"\uff08", "\uff09"})
        self.assertEqual(found, [])

    def test_clean_ascii_passes(self):
        self.assertEqual(self._scan("plain ascii: P vs NP, no stray chars"), [])


class ScanFileTest(unittest.TestCase):
    """scan() walks dirs and filters to the owned text suffixes."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel: str, text: str | bytes) -> Path:
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, bytes):
            p.write_bytes(text)
        else:
            p.write_text(text, encoding="utf-8")
        return p

    def test_scan_finds_py_md_yaml_lean_but_ignores_binary(self):
        self.write("a.md", "no-spec\u3002")
        self.write("b.py", "# comment with \u3002\ndef x(): pass")
        self.write("c.yaml", "note: slot  \u03682")
        self.write("d.lean", "-- ZWSP here\u200b")
        self.write("e.bin", b"\x00\x01\x02")  # non-UTF8 binary, ignored (bytes)
        findings = unicode_scan.scan([self.root])
        files = {str(f.file.relative_to(self.root)) for f in findings}
        self.assertEqual(files, {"a.md", "b.py", "c.yaml", "d.lean"})

    def test_scan_reports_soft_lrm_files(self):
        self.write("docs/decisions/LOG.md", "text \u200e token")
        findings = unicode_scan.scan([self.root])
        self.assertTrue(any(f.kind == "invisible-bidi" and f.char == "\u200e"
                            for f in findings))


if __name__ == "__main__":
    unittest.main()