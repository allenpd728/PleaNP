#!/usr/bin/env python3
"""Effort re-sum tool — one command to recompute the effort ledger totals.

Re-computes the authoritative per-rung run totals from the live GitHub issue
queue (or an offline JSON dump of it) by summing each issue's `**Effort:**`
line, grouped by the Rung map below. This is the reproducible replacement for
"sum the ledger rows by hand" in docs/EFFORT_ESTIMATE.md.

The Rung map is the single source of truth for which issue belongs to which
rung. Keep it in sync with the ledger (docs/EFFORT_ESTIMATE.md) when tasks
are filed, closed, or re-runged.

Usage:
    python3 effort_summary.py                # live GitHub (GITHUB_TOKEN)
    python3 effort_summary.py --json-file issues.json
    python3 effort_summary.py --csv           # also print a CSV of per-issue rows
    python3 effort_summary.py --table-rows   # print Markdown table rows for EFFORT_ESTIMATE.md

Exit codes:
    0  ok (even if estimates exist beyond min-runs)
    2  usage error
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pass_scan import effort_minmax, fetch_live, load_json  # noqa: E402

# Rung map: issue number -> rung label. Single source of truth; keep in sync
# with the ledger's table. Entries for issues that have no Effort line yet are
# still listed here so the summary can report them as "no effort" (they won't
# be falsely counted as 0).
RUNG_MAP = {
    4: "2", 18: "3", 22: "3", 23: "3", 26: "3", 35: "2", 36: "3", 37: "3",
    40: "2",
    62: "3", 63: "3", 64: "3", 65: "5", 66: "3", 67: "3", 68: "3", 69: "3",
    70: "4", 71: "4", 72: "4", 73: "4", 74: "4", 75: "4", 76: "4",
    77: "6", 78: "6", 79: "6",
    80: "8", 81: "7", 82: "5",
    83: "meta", 84: "sweep",
}
# Rungs counted in "proof-search entry path" (ROADMAP dependency note).
PROOF_SEARCH_RUNGS = ("2", "3", "4", "5", "6")
# Rungs counted as "in-scope work" (everything except meta/sweep housekeeping).
TOTAL_RUNGS = ("2", "3", "4", "5", "6", "7", "8")
# Human label per rung for output readability.
RUNG_LABELS = {
    "2": "Rung 2 substrate", "3": "Rung 3 barriers",
    "4": "Rung 4 lower bounds", "5": "Rung 5 calculus",
    "6": "Rung 6 anchor", "7": "Rung 7 benchmark",
    "8": "Rung 8 compiler", "meta": "meta", "sweep": "sweep",
}


@dataclass
class Row:
    number: int
    title: str
    rung: str
    lo: int
    hi: int


def to_rows(issues: list) -> list[Row]:
    rows = []
    for iv in issues:
        rung = RUNG_MAP.get(iv.number)
        if not rung:
            continue
        emm = effort_minmax(iv.body)
        if emm is None:
            rows.append(Row(iv.number, iv.title, rung, 0, 0))
        else:
            rows.append(Row(iv.number, iv.title, rung, emm[0], emm[1]))
    return rows


def summarize(issues: list) -> dict:
    rows = to_rows(issues)
    by = defaultdict(lambda: [0, 0, 0])   # rung -> [lo, hi, no_effort_count]
    for r in rows:
        if r.lo == 0 and r.hi == 0:
            by[r.rung][2] += 1
            continue
        by[r.rung][0] += r.lo
        by[r.rung][1] += r.hi
    tr = [v for k, v in by.items() if k in TOTAL_RUNGS]
    total_lo = sum(v[0] for v in tr)
    total_hi = sum(v[1] for v in tr)
    ps = [v for k, v in by.items() if k in PROOF_SEARCH_RUNGS]
    ps_lo = sum(v[0] for v in ps)
    ps_hi = sum(v[1] for v in ps)
    ps6 = by.get("6", [0, 0, 0])
    no_effort = {k: v[2] for k, v in by.items() if v[2]}
    return {
        "by_rung": {k: (v[0], v[1]) for k, v in sorted(by.items())},
        "total": (total_lo, total_hi),
        "proof_search": (ps_lo, ps_hi),
        "proof_search_no_r6": (ps_lo - ps6[0], ps_hi - ps6[1]),
        "r6": (ps6[0], ps6[1]),
        "meta_sweep": (by.get("meta", [0,0,0])[0] + by.get("sweep", [0,0,0])[0],
                       by.get("meta", [0,0,0])[1] + by.get("sweep", [0,0,0])[1]),
        "no_effort_issues": no_effort,
        "rows": rows,
    }


def _fmt_range(t: tuple) -> str:
    lo, hi = t
    return f"{lo}" if lo == hi else f"{lo}–{hi}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Effort re-sum from the issue queue")
    ap.add_argument("--json-file", type=Path, default=None,
                    help="Offline JSON dump of issues; default: live GitHub")
    ap.add_argument("--csv", action="store_true",
                    help="Print a CSV of per-issue rows")
    ap.add_argument("--table-rows", action="store_true",
                    help="Print Markdown table rows for EFFORT_ESTIMATE.md")
    args = ap.parse_args(argv)

    if args.json_file is not None:
        if not args.json_file.exists():
            ap.error(f"file not found: {args.json_file}")
        issues = load_json(args.json_file)   # returns IssueView objects
    else:
        issues = fetch_live()                # same shape

    s = summarize(issues)

    print("Effort re-sum (per-rung run totals):")
    for k, (lo, hi) in s["by_rung"].items():
        if k in ("meta", "sweep"):
            continue
        label = RUNG_LABELS.get(k, k)
        print(f"  {k:>5}  {label:<22} {lo}–{hi} runs")
    print("  ----")
    tot_lo, tot_hi = s["total"]
    ms_lo, ms_hi = s["meta_sweep"]
    print(f"  TOTAL in-scope work (Rungs 2–8): {tot_lo}–{tot_hi} runs")
    print(f"    (meta + sweep housekeeping: {ms_lo}-{ms_hi} run(s))")
    print(f"  Proof-search entry (Rungs {'+'.join(PROOF_SEARCH_RUNGS)}): "
          f"{_fmt_range(s['proof_search'])} runs")
    print(f"    of which unblocked now (excl Rung 6): "
          f"{_fmt_range(s['proof_search_no_r6'])} runs")
    print(f"    Rung 6 slice (upstream-gated): {_fmt_range(s['r6'])} runs")
    if s["no_effort_issues"]:
        print("\n  NOTE — issues with no Effort line (counted as 0):")
        for k, c in s["no_effort_issues"].items():
            print(f"    rung {k}: {c} issue(s)")

    if args.csv:
        print("\nissue,rung,effort_lo,effort_hi,title")
        for r in sorted(s["rows"], key=lambda r: (r.rung, r.number)):
            print(f"{r.number},{r.rung},{r.lo},{r.hi},{r.title!r}")

    if args.table_rows:
        print("\nMarkdown rows for docs/EFFORT_ESTIMATE.md (Rungs 2–8):")
        for k, (lo, hi) in s["by_rung"].items():
            if k in ("meta", "sweep"):
                continue
            label = RUNG_LABELS.get(k, k)
            print(f"| {label} | {lo} → {hi} | |")
    return 0


if __name__ == "__main__":
    sys.exit(main())