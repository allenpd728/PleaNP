#!/usr/bin/env python3
"""Gate harness: assert the four `#barrier_check` verdicts appear in a build log.

Issue #3 (Tests: test spec for Rung-5 #barrier_check verdicts). The
`#barrier_check` elaborator in `lean/PleaNP/Calculus/BarrierCalculus.lean`
logs four verdict lines during compile:

  - `thhStatement`          -> "relativizes, not P-vs-NP-shaped -> Inconclusive"
  - `abstractPVsNP`         -> "DEAD - this proof relativizes"
  - `plainRelHeuristic`     -> "relativizes, not P-vs-NP-shaped -> Inconclusive"
  - `nonRelativizingControl` -> "Inconclusive \u2014no Relativizing instance"

CI builds the clean modules (see `.github/workflows/ci.yml`); the harness
runs on the captured build log (the build step `tee`s its output to a log
file) and fails if any expected verdict line is missing or wrong — so a
regression in the elaborator's verdicts (a DEAD flipping to Inconclusive, a
message rewrite, an instance that stops synthesizing) kills the build.

Expected-log match: for each (decl, verdict-template) pair, the log must
contain the segment `#barrier_check PleaNP.Calculus.<decl>: <template-prefix>`.
The verdict templates are extracted verbatim from the elaborator source (the
`logInfo m!"..."` strings at BarrierCalculus.lean:276-280;keep in sync
they are els hard-coded below with the `{n}` placeholder replaced by the full
declaration name and the message text verbatim. Only the part upto the final
clause is matched (so file/line/col prefixes,and the unicode dash variants,
don't bake into the assertion;but the verdict-identifying text does.

Usage:
    python3 barrier_check_test.py <log-file>
    python3 barrier_check_test.py --run-lake [MODULE]   # builds in lean/ then checks
Exit codes:
    0   all four verdicts present
    1   assertion failure (missing/wrong verdict line),
    2   usage error
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# The four declarations the elaborator checks, with their expected verdict
# segments (verbatim from the `logInfo` templates in BarrierCalculus.lean;the
# final clause after the verdict keyword is dropped so punctuation/line-prefix
# variations don't matter, but the verdict-identifying text is exact).
EXPECTED = [
    ("PleaNP.Calculus.thhStatement",
     "#barrier_check PleaNP.Calculus.thhStatement: relativizes,"),
    ("PleaNP.Calculus.abstractPVsNP",
     "#barrier_check PleaNP.Calculus.abstractPVsNP: DEAD"),
    ("PleaNP.Calculus.plainRelHeuristic",
     "#barrier_check PleaNP.Calculus.plainRelHeuristic: relativizes,"),
    ("PleaNP.Calculus.nonRelativizingControl",
     "#barrier_check PleaNP.Calculus.nonRelativizingControl: Inconclusive"),
]

#(The dash in "DEAD - this proof" and "Inconclusive - no Relativizing" is an
# em dash in the source (U+2014);match with a tolerant pattern so the
# assertion survives terminal/environment-specific dash re-encoding.）
_EM_DASH = "\u2014"


def verdict_segment(decl: str, template: str) -> str:
    """Rebuild the exact verdict text from the elaborator's logInfo template.


    The template uses `{n}` for the declaration and the em dash is part of the
    human-readable message. The assertion match includes decl + verdict keyword
    with an em-dash-tolerant boundary. Returns a compiled pattern string."""
    # fold the template's placeholder entirely (decl already carries the name).
    # Keep only the leading clause up to the first comma after the keyword, so the
    # line/col prefix and trailing clauses don't bake in.
    return template.format(n=decl)


_DASH_FAMILY = ("\u2014", "\u2013", "\u2012", "\u2015", "-")

def _normalize_dashes(s: str) -> str:
    """Fold every dash-family char to a sentinel for dash-tolerant verdict match."""
    for d in _DASH_FAMILY:
        s = s.replace(d, "\u2003")
    return s

def check_log(text: str) -> list[str]:
    """Return the list of expected verdicts missing from the log."""
    norm = _normalize_dashes(text)
    missing = []
    for decl, template in EXPECTED:
        seg = _normalize_dashes(verdict_segment(decl, template))
        if seg not in norm:
            missing.append(seg)
    return missing

def check_file(path: Path) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    missing = check_log(text)
    if missing:
        print(f"barrier-check verdict harness: {len(missing)} expected verdict(s) missing from {path}:")
        for seg in missing:

            print(f"  MISSING: {seg[:90]}...")
        return 1
    print(f"barrier-check verdict harness ok: all {len(EXPECTED)} verdicts present in {path}.")
    return 0


def run_lake(module: str) -> int:
    """Build the module in `lean/` (cwd) and feed the captured output through the
    assertions. Used locally;CI instead tees the existing build step's output
    (so no double build)and hands the log to --log."""
    # force a rebuild so the elaborator's logInfo lines actually print (lake
    # skips up-to-date modules silently).
    src = Path("PleaNP/Calculus/BarrierCalculus.lean")
    if src.exists():
        src.touch()
    proc = subprocess.run(
        ["lake", "build", module],
        capture_output=True, text=True,
    )
    log = proc.stdout + "\n" + proc.stderr
    if proc.returncode != 0:
        print(f"barrier-check verdict harness: lake build failed (exit {proc.returncode})", file=sys.stderr)
        print(log[-4000:], file=sys.stderr)
        return 1
    return check_log_stdout(log)


def check_log_stdout(log: str) -> int:
    missing = check_log(log)
    if missing:
        print(f"barrier-check verdict harness: {len(missing)} expected verdict(s) missing from the build output:")
        for seg in missing:
            print(f"  MISSING: {seg[:90]}...")
        return 1
    print(f"barrier-check verdict harness ok: all {len(EXPECTED)} verdicts present.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Assert the four #barrier_check verdicts in a build log (issue #3)")
    ap.add_argument("log", nargs="?", type=Path, help="build log file to check")
    ap.add_argument("--run-lake", nargs="?", const="PleaNP.Calculus.BarrierCalculus", metavar="MODULE",
                    help="build the module with lake (in lean/) first, then check its output")
    args = ap.parse_args()

    if args.log and args.run_lake:
        print("barrier-check verdict harness: pass exactly one of <log-file> or --run-lake", file=sys.stderr)
        return 2
    if args.log:
        return check_file(args.log)
    if args.run_lake:
        return run_lake(args.run_lake)
    print("barrier-check verdict harness: provide a log file or --run-lake", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())