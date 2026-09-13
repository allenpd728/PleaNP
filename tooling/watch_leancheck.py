#!/usr/bin/env python3
"""watch_leancheck — poll a .lean file and stop when it type-checks.

The agent proof-authoring loop (edit -> leancheck -> fix -> repeat) becomes
faster when the check runs automatically on every save and STOPS the watch
the moment the file is clean, printing the runtime. Use it alongside your
editor (auto-save) or a terminal that triggers it.

Usage (from the lake root, lean/):

    python3 ../tooling/watch_leancheck.py <file.lean> [--interval 0.5] [--max 1200]

- Re-runs `leancheck.py <file>` every `--interval` seconds.
- Stops with rc 0 on the first clean run; prints elapsed + iteration count.
- Stops with rc 2 on `--max` seconds elapsed (agent should reconsider).
- Ctrl-C aborts and re-runs the file once (so the agent always gets a final
  picture on interrupt).

Stdlib-only. The single-shot primitive is leancheck.py (this file shells out
to it), kept separate so CI / scripts can call the primitive directly.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description="Poll a Lean file until it type-checks.")
    ap.add_argument("file")
    ap.add_argument("--interval", type=float, default=0.5)
    ap.add_argument("--max", type=float, default=1200.0, help="max seconds")
    ap.add_argument("--quiet-until-clean", action="store_true",
                    help="suppress per-iteration output; only report the final clean run")
    args = ap.parse_args()

    file = Path(args.file)
    start = time.monotonic()
    iterations = 0

    def check() -> int:
        return subprocess.call(
            [sys.executable, str(Path(__file__).with_name("leancheck.py")), str(file)],
            cwd=Path.cwd(),
        )

    try:
        while True:
            iterations += 1
            rc = check()
            if rc == 0:
                elapsed = time.monotonic() - start
                print(f"\nwatch_leancheck: CLEAN after {iterations} check(s), "
                      f"{elapsed:.1f}s — {file}")
                return 0
            if args.quiet_until_clean:
                pass
            if time.monotonic() - start > args.max:
                print(f"\nwatch_leancheck: gave up after {args.max:.0f}s "
                      f"({iterations} checks). Last exit {rc}.")
                return 2
            time.sleep(args.interval)
    except KeyboardInterrupt:
        # Always give a final picture on interrupt.
        print("\nwatch_leancheck: interrupted; final check:")
        rc = check()
        print(f"final exit {rc}")
        return rc if rc == 0 else 1


if __name__ == "__main__":
    sys.exit(main())