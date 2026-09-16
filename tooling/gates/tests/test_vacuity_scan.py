#!/usr/bin/env python3
"""Unit tests for the Gate 5 vacuity scanner's comment-stripping (issue #60).

Regression-guards the shared docstring-strip regex fix: the old
`/-.*? -/` (requires a space before `-/`) missed Mathlib-convention
docstrings that close with ``\\n-/`` and could over-strip real code.
Now uses the blanking approach from binder_usage_scan (issue #60).
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import vacuity_scan  # noqa: E402


class TestStripComments(unittest.TestCase):
    MATHLIB_DOCSTRING = """/-!
A docstring that closes with a newline before the closer,
as the Mathlib convention does.
-/
def realDef : Nat := 1
"""

    def test_mathlib_nl_docstring_closer_is_stripped(self):
        out = vacuity_scan._strip_comments(self.MATHLIB_DOCSTRING)
        self.assertNotIn("docstring", out)
        self.assertIn("def realDef : Nat := 1", out)
        # Comments blanked, not deleted: output has same length as input.
        self.assertEqual(len(out), len(self.MATHLIB_DOCSTRING))

    def test_real_code_after_docstring_preserved(self):
        src = self.MATHLIB_DOCSTRING + "theorem t : True := by trivial\n"
        out = vacuity_scan._strip_comments(src)
        self.assertIn("theorem t : True", out)
        self.assertIn("def realDef", out)

    def test_line_numbers_preserved(self):
        src = "line1\n" + self.MATHLIB_DOCSTRING + "lineN\n"
        out = vacuity_scan._strip_comments(src)
        # 'def realDef' must appear on the same line number as in the source.
        src_line = src.split("\n").index("def realDef : Nat := 1")
        out_line = out.split("\n").index("def realDef : Nat := 1")
        self.assertEqual(src_line, out_line)

    def test_line_comment_stripped(self):
        src = "def x : Nat := 1 -- a comment\ntheorem t : True := by trivial\n"
        out = vacuity_scan._strip_comments(src)
        self.assertNotIn("a comment", out)
        self.assertIn("theorem t : True", out)

    def test_overstrip_does_not_happen_mid_file(self):
        # A ` -/` elsewhere must not swallow the rest of the file.
        src = """/-! first docstring -/
def a := 1
/- some comment with ` -/` inside a string -/
def b := 2
"""
        out = vacuity_scan._strip_comments(src)
        self.assertIn("def a := 1", out)
        self.assertIn("def b := 2", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)