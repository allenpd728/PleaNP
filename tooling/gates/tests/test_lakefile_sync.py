#!/usr/bin/env python3
"""Tests for the lakefile sync guard (PleaNP #102).

The guard exists because the root `lakefile.lean` must duplicate the library
declarations in `lean/lakefile.lean` (a minimal root file was tested and does not
work — consumers fail with `unknown module prefix 'PleaNP'`). A guard that cannot
detect drift is worthless, so each drift class is asserted to be caught, and a
matching pair is asserted to be accepted.

Run: python3 tooling/gates/tests/test_lakefile_sync.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
GUARD = REPO / "tooling" / "gates" / "lakefile_sync_check.py"
sys.path.insert(0, str(GUARD.parent))

import lakefile_sync_check as g  # noqa: E402

INNER = """import Lake
open Lake DSL

package «PleaNP» where

@[default_target]
lean_lib «PleaNP» where
  globs := #[.andSubmodules `PleaNP]

lean_lib tests where
  roots := #[`tests.OracleV5, `tests.BarrierCalculusFuneq]

lean_exe test where
  root := `tests.Basic
  deps := #[`tests]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.31.0"
"""

ROOT_MATCHING = INNER.replace("package «PleaNP» where",
                              'package «PleaNP» where\n  srcDir := "lean"')

DRIFTS = {
    "mathlib pin": ROOT_MATCHING.replace('@ "v4.31.0"', '@ "v4.30.0"'),
    "dropped lib": ROOT_MATCHING.replace(
        "lean_lib tests where\n  roots := #[`tests.OracleV5, `tests.BarrierCalculusFuneq]\n", ""),
    "changed roots": ROOT_MATCHING.replace(
        "roots := #[`tests.OracleV5, `tests.BarrierCalculusFuneq]",
        "roots := #[`tests.OracleV5]"),
    "extra lib": ROOT_MATCHING.replace(
        "require mathlib from git", "lean_lib extra where\n  roots := #[`extra]\n\nrequire mathlib from git"),
    "exe root": ROOT_MATCHING.replace("root := `tests.Basic", "root := `tests.Other"),
    "package name": ROOT_MATCHING.replace("package «PleaNP» where", "package «Rename» where"),
    "dropped exe": ROOT_MATCHING.replace(
        "lean_exe test where\n  root := `tests.Basic\n  deps := #[`tests]\n", ""),
}


def _write(tmp: Path, root_src: str) -> None:
    (tmp / "lane").mkdir(exist_ok=True)
    (tmp / "lakefile.lean").write_text(root_src)
    (tmp / "lane" / "lakefile.lean").write_text(INNER)


def test_matching_accepted():
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        _write(tmp, ROOT_MATCHING)
        # Point the module globals at the temp tree for this test.
        g.ROOT_LAKEFILE = tmp / "lakefile.lean"
        g.LEAN_LAKEFILE = tmp / "lane" / "lakefile.lean"
        rc = g.main()
        assert rc == 0, f"matching lakefiles rejected (exit {rc})"
    print("PASS: test_matching_accepted")


def test_each_drift_detected():
    for label, src in DRIFTS.items():
        with tempfile.TemporaryDirectory() as t:
            tmp = Path(t)
            _write(tmp, src)
            g.ROOT_LAKEFILE = tmp / "lakefile.lean"
            g.LEAN_LAKEFILE = tmp / "lane" / "lakefile.lean"
            rc = g.main()
            assert rc == 1, f"drift {label!r} NOT detected (exit {rc})"
    print(f"PASS: test_each_drift_detected ({len(DRIFTS)} drift classes)")


def test_comments_ignored():
    """A commented-out declaration must not count as drift."""
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        src = ROOT_MATCHING.replace(
            "require mathlib from git",
            "/- lean_lib commented where\n  roots := #[`x] -/\n\nrequire mathlib from git")
        _write(tmp, src)
        g.ROOT_LAKEFILE = tmp / "lakefile.lean"
        g.LEAN_LAKEFILE = tmp / "lane" / "lakefile.lean"
        rc = g.main()
        assert rc == 0, f"commented-out decl counted as drift (exit {rc})"
    print("PASS: test_comments_ignored")


def test_whitespace_reformat_not_drift():
    """Reformatting the roots list must not be reported as drift."""
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        src = ROOT_MATCHING.replace(
            "roots := #[`tests.OracleV5, `tests.BarrierCalculusFuneq]",
            "roots := #[  `tests.OracleV5 ,   `tests.BarrierCalculusFuneq  ]")
        _write(tmp, src)
        g.ROOT_LAKEFILE = tmp / "lakefile.lean"
        g.LEAN_LAKEFILE = tmp / "lane" / "lakefile.lean"
        rc = g.main()
        assert rc == 0, f"whitespace-only change reported as drift (exit {rc})"
    print("PASS: test_whitespace_reformat_not_drift")


def test_real_repo_in_sync():
    """The actual repo files must be in sync right now."""
    r = subprocess.run([sys.executable, str(GUARD)], capture_output=True, text=True,
                       cwd=str(REPO))
    assert r.returncode == 0, f"real repo lakefiles are out of sync:\n{r.stdout}\n{r.stderr}"
    print("PASS: test_real_repo_in_sync")


def main() -> int:
    tests = [
        test_matching_accepted,
        test_each_drift_detected,
        test_comments_ignored,
        test_whitespace_reformat_not_drift,
        test_real_repo_in_sync,
    ]
    passed = failed = 0
    for t in tests:
        try:
            t()
            passed += 1
        except AssertionError as e:
            print(f"FAIL: {t.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"ERROR: {t.__name__}: {type(e).__name__}: {e}")
            failed += 1
    print()
    print("=" * 40)
    print(f"Tests: {passed} passed, {failed} failed")
    print("=" * 40)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())