#!/usr/bin/env python3
"""leancheck — fast Lean file type-check iteration loop.

Lean iteration helper: instead of scrolling `lake env lean` wall-output after
every edit, print just the FIRST error with its location, a one-line summary,
and (when the error mentions a missing simp lemma) a tiny checklist hint.

Usage (from the lake root, lean/):

    python3 ../tooling/leancheck.py <file.lean> [--all] [--no-context] [--json]

- default: prints the first error (file:line:col), its message, and a compact
  slice of the goal context.
- --all: print every error/warning (not just the first).
- --no-context: skip the goal-context slice (cleaner for tiny errors).
- --json: emit one JSON object summarizing the run (first-error fields).

Stdlib-only (no secrets, no network). CI-safe: exits 0 when the file is
clean (no errors, and warnings only if allowed), 1 on error. Intended for
the agent loop: edit -> leancheck -> fix -> repeat.

The watch-loop form (poll every 0.5s, stop on clean) is in
watch_leancheck.py; this file is the single-shot primitive.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


ERROR_RE = None  # populated lazily; lean error lines look like:
#   <file>.lean:12:3: error: some message
#   <file>.lean:12:3-5: error: ...
# locations may also be "5:2" or "5:2-4" or with `(interactive)` binds.


def _line_is_error(line: str) -> bool:
    return "error:" in line


def _parse_loc(line: str, cwd: str) -> dict | None:
    """Best-effort parse of `path:line:col(:col2): error: msg`."""
    if "error:" not in line:
        return None
    head, _, msg = line.partition(" error: ")
    if not head:
        return None
    # head may be `<path>:<l>:<c>:` (Lean, note the trailing colon before
    # ` error:`) or `[server] <path>:<l>:<c>:` etc. Strip a trailing `:`.
    head = head.split("] ")[-1].lstrip("[").strip().rstrip(":")
    parts = head.split(":")
    if len(parts) < 3:
        return None
    path = ":".join(parts[:-2])
    try:
        line_no = int(parts[-2])
        col = parts[-1]
    except ValueError:
        return None
    return {"path": path, "line": line_no, "col": col, "message": msg.strip()}


def _summary_for(msg: str) -> str:
    low = msg.lower()
    if "declaration uses `sorry`" in low:
        return "SORRY in this declaration"
    if "type mismatch" in low:
        return "type mismatch"
    if "don't know how to synthesize" in low or "failed to synthesize" in low:
        return "typeclass synthesis failed (missing instance?)"
    if "unknown identifier" in low:
        return "unknown identifier"
    if "invalid field" in low:
        return "invalid field projection"
    if "expected" in low and "but has type" in low:
        return "expected-type mismatch"
    if "no goals to be solved" in low:
        return "no goals left; drop a redundant tactic"
    if "unexpected" in low and ("identifier" in low or "token" in low):
        return "syntax error (unexpected identifier/token)"
    if "declaration uses" in low and "sorry" in low:
        return "sorry present"
    return ""


def run(file: str, cwd: str, lean_bin: str | None = None, timeout: int = 240):
    """Run `lake env lean <file>` and return (rc, parsed_errors, raw).

    rc: 0 clean, 1 errors, 2 timeout / not-found.
    """
    if lean_bin is None:
        lean_bin = "lean"
    # In a lake project, `lake env lean file.lean` ensures imports resolve via
    # the olean cache.
    cmd = ["lake", "env", lean_bin, str(file)]
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return 2, [], "lake not found on PATH (bootstrap elan first)"
    except subprocess.TimeoutExpired:
        return 2, [], f"timed out after {timeout}s"

    raw = proc.stdout + "\n" + proc.stderr
    errors = []
    warnings = []
    for line in raw.splitlines():
        if "warning:" in line:
            warnings.append(line)
        elif _line_is_error(line):
            errors.append(line)
    return (0 if not errors else 1), errors, raw


def _print_first(errors: list[str], raw: str, cwd: str, show_context: bool):
    if not errors:
        return
    first = errors[0]
    loc = _parse_loc(first, cwd)
    print("=" * 72)
    if loc:
        print(f"ERROR {loc['path']}:{loc['line']}:{loc['col']}")
    else:
        print("ERROR (no location parsed)")
    # print the raw error line + up to 3 following lines (the goal context)
    lines = raw.splitlines()
    for i, ln in enumerate(lines):
        if ln == first:
            # print the error line and a bounded context slice
            for j in range(i, min(i + 6, len(lines))):
                print("  " + lines[j])
            break
    msg = loc["message"] if loc else first
    s = _summary_for(msg)
    if s:
        print("-" * 72)
        print(f"hint: {s}\n     common fixes: unfold the def in the Lean goal (simp [<def>]),\n     or add the missing [simp]/instance, or use `erw`/`change` to expose the pattern.")
    if show_context:
        print("-" * 72)
        # Stop context at the first blank line (Lean's goal block often has one)
        printed = 0
        for i, ln in enumerate(lines):
            if ln == first:
                for j in range(i + 1, min(i + 14, len(lines))):
                    if not lines[j].strip() and printed:
                        break
                    print("   " + lines[j])
                    printed += 1
                break
    print("=" * 72)


def main() -> int:
    ap = argparse.ArgumentParser(description="First-error Lean type-checker.")
    ap.add_argument("file", help=".lean file (path relative to cwd or absolute)")
    ap.add_argument("--all", action="store_true", help="print all errors, not just the first")
    ap.add_argument("--no-context", action="store_true", help="skip the goal-context slice")
    ap.add_argument("--json", action="store_true", help="emit JSON summary to stdout")
    args = ap.parse_args()

    cwd = os.getcwd()
    file = args.file
    rc, errors, raw = run(file, cwd)
    if rc == 2:
        if args.json:
            print(json.dumps({"clean": False, "timeout_or_missing": True, "raw": raw[:400]}))
        else:
            print(f"leancheck: {raw}")
        return 2

    show_ctx = not args.no_context
    if args.json:
        first = errors[0] if errors else None
        loc = _parse_loc(first, cwd) if first else None
        print(json.dumps({
            "clean": rc == 0,
            "n_errors": len(errors),
            "first": loc,
            "raw_first": first,
        }, indent=1))
        return rc

    if rc == 0:
        nw = raw.count("warning:")
        print(f"leancheck: OK ({nw} warning(s)) — {file}")
        return 0

    if args.all:
        for e in errors:
            print(e)
    else:
        _print_first(errors, raw, cwd, show_ctx)
    # a compact warning count so the agent sees the whole picture
    nw = raw.count("warning:")
    print(f"\n({len(errors)} error(s), {nw} warning(s); use --all to list every error)")
    return 1


if __name__ == "__main__":
    sys.exit(main())