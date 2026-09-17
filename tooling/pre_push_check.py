#!/usr/bin/env python3
"""pre_push_check — run the CI-only checks locally before pushing (issue #118).

Twice now (issues #112, #118) a change to a tracked doc broke CI on a step that
has no local equivalent: the **Galaxy regen smoke**, which asserts the committed
`tooling/galaxy/galaxy.html` still matches the output of regenerating it from
the repo artifacts. `docs/SORRY_TRACKER.md`, `docs/ROADMAP.md`, `formalization.yaml`
and the review points are all embedded in that page, so editing any of them
requires a regen — and neither the Tier-1 scanners nor `pytest` catch a stale
copy. The failure only shows up in CI (this repo's sanctioned "build oracle"),
which costs a round trip.

This script is the local equivalent: it regenerates the page and reports whether
the committed copy is stale, so the fix (regenerate + include it in the commit)
happens before the push rather than after.

Usage:
    python3 tooling/pre_push_check.py          # check only (exit 1 if stale)
    python3 tooling/pre_push_check.py --fix    # regenerate in place if stale

Exit codes: 0 up to date, 1 stale (or regen failed), 2 usage error.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GALAXY = REPO / "tooling" / "galaxy" / "galaxy.html"


def check(fix: bool) -> int:
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "galaxy.html"
        r = subprocess.run(
            [sys.executable, "tooling/galaxy/galaxy.py", "--repo", ".", "--out", str(out)],
            cwd=str(REPO), capture_output=True, text=True,
        )
        if r.returncode != 0:
            print("pre_push_check: galaxy regen FAILED:", file=sys.stderr)
            print(r.stderr[-2000:], file=sys.stderr)
            return 1
        fresh = out.read_bytes()
    committed = GALAXY.read_bytes() if GALAXY.exists() else b""
    if fresh == committed:
        print("pre_push_check: galaxy.html is up to date.")
        return 0
    if fix:
        GALAXY.write_bytes(fresh)
        print("pre_push_check: galaxy.html was STALE — regenerated (re-add it to the commit).")
        return 0
    print("pre_push_check: galaxy.html is STALE — CI's 'Galaxy regen smoke' will fail.")
    print("  Fix: python3 tooling/pre_push_check.py --fix && git add tooling/galaxy/galaxy.html")
    return 1


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="pre-push CI-equivalent checks")
    ap.add_argument("--fix", action="store_true",
                    help="regenerate galaxy.html in place if stale")
    args = ap.parse_args(argv[1:])
    return check(args.fix)


if __name__ == "__main__":
    sys.exit(main(sys.argv))