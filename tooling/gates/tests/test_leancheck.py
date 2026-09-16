import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import leancheck


class TestParseLoc(unittest.TestCase):
    def test_basic(self):
        r = leancheck._parse_loc("DiagonalUB.lean:123:7: error: unknown identifier 'foo'", ".")
        self.assertEqual(r["path"], "DiagonalUB.lean")
        self.assertEqual(r["line"], 123)
        self.assertEqual(r["col"], "7")

    def test_col_range(self):
        r = leancheck._parse_loc("DiagUB.lean:200:3-9: error: type mismatch", ".")
        self.assertEqual(r["line"], 200)
        self.assertEqual(r["col"], "3-9")

    def test_no_error(self):
        self.assertIsNone(leancheck._parse_loc("DiagUB.lean:1:1: info: everything fine", "."))

    def test_server_prefix(self):
        r = leancheck._parse_loc("[server] Foo.lean:9:2: error: declaration uses sorry", ".")
        self.assertEqual(r["path"], "Foo.lean")
        self.assertEqual(r["line"], 9)
        self.assertEqual(r["col"], "2")


class TestSummary(unittest.TestCase):
    def test_hints(self):
        self.assertEqual(leancheck._summary_for("unknown identifier 'x'"), "unknown identifier")
        self.assertEqual(leancheck._summary_for("type mismatch has type 2 but is expected to have type Nat"),
                         "type mismatch")
        self.assertEqual(leancheck._summary_for("declaration uses `sorry`"), "SORRY in this declaration")
        self.assertEqual(leancheck._summary_for("failed to synthesize instance"),
                         "typeclass synthesis failed (missing instance?)")


class TestLineDetect(unittest.TestCase):
    def test_is_error(self):
        self.assertTrue(leancheck._line_is_error("Foo.lean:1:1: error: boom"))
        self.assertFalse(leancheck._line_is_error("Foo.lean:1:1: warning: meh"))

    def test_real_lean_format(self):
        # Format observed live from Lean v4.31.0 (see docs/TOOLCHAIN_AGENTS.md).
        line = "PleaNP/Barriers/Probe-leancheck.lean:11:2: error: omega could not prove the goal:"
        r = leancheck._parse_loc(line, ".")
        self.assertEqual(r["path"], "PleaNP/Barriers/Probe-leancheck.lean")
        self.assertEqual(r["line"], 11)
        self.assertEqual(r["col"], "2")
        self.assertTrue(r["message"].startswith("omega could not prove"))


if __name__ == "__main__":
    unittest.main()