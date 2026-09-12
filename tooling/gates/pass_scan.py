#!/usr/bin/env python3
"""Process-compliance scanner (multi-run pass sizing rule, 2026-09-12).

Enforces the multi-run pass-sizing rule codified in
docs/MULTI_AGENT_WORKFLOW.md (Task definition): an issue that is a true
multi-run epic — an "Effort: N–M runs" (or "Effort: N runs") line with
N >= 2 — MUST carry an explicit "**Passes:**" block (Pass 1..n) in its body,
so long-horizon targets are worked as successive one-run passes rather than
as one oversized claim. An issue that is single-run ("Effort: 1 run") or a
design task ("Effort: 1–2 runs (design ...)") is allowed to omit the block.

This is a *process* scan (Gate 0 herd / queue health), not a Lean gate. It
reads GitHub issue pages (via the REST API) OR a local JSON dump of the same
shape, so it is stdlib-only, no secrets required in tests.

Usage:
    python3 pass_scan.py                                  # live via GITHUB_TOKEN (env)
    python3 pass_scan.py --json-file issues.json          # offline (issue dump)
    python3 pass_scan.py --min-runs 2                     # default; min effort runs to require Passes

Exit codes:
    0  compliant (no violations, or only allow-listed ones)
    1  violations found (prints a report)
    2  usage error

A "violation" is an issue whose Effort line claims >= `--min-runs` (default 2)
total runs but whose body has no "**Passes:**" marker, and which is not a
single-pass-by-design design task. Warnings (non-fatal) are emitted for
issues with no Effort line and for issues whose Passes block has fewer pass
lines than the Effort max (sizing under-specification).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_MIN_RUNS = 2
REPO = "allenpd728/PleaNP"
API = f"https://api.github.com/repos/{REPO}/issues"

# Set via --warn-no-effort: report legacy issues that have no Effort line at
# all (they predate the convention and stay claimable, but are then invisible
# to the pass-sizing enforcement).
_WARN_NO_EFFORT = False

# Matches "**Effort:** 2-4 runs." / "3–6  runs (…)" — number/range then the word
# "runs" (or nothing, e.g. "Effort: 1 run (abstract form)").
_EFFORT_LINE = re.compile(
    r"\*\*Effort:\*\*\s*"
    r"(?P<min>\d+)\s*(?:[–-]\s*(?P<max>\d+))?"
    r"(?:\s+runs?)?",
    re.IGNORECASE,
)
# "1–2 runs (design ...)" — design tasks produce the decomposition as output,
# so they are single-claim by design and exempt from the Passes requirement.
_DESIGN_TASK = re.compile(r"(?:design|decomposition)\b", re.IGNORECASE)
_PASSES_MARKER = re.compile(r"\*\*Passes\b", re.IGNORECASE)
# Counts the "Pass N —" clauses inside a Passes block (used for the under-spec
# warning, not the violation).
_PASS_PATTERN = re.compile(r"^\s*Pass\s+\d+\b", re.MULTILINE)


@dataclass
class IssueView:
    number: int
    title: str
    body: str
    labels: list = field(default_factory=list)


@dataclass
class Finding:
    number: int
    title: str
    kind: str          # "violation" | "warning"
    detail: str


def parse_issue_view(d: dict) -> IssueView:
    labels = [l["name"] for l in d.get("labels", [])] if isinstance(d.get("labels"), list) else []
    return IssueView(
        number=int(d.get("number", 0)),
        title=str(d.get("title", "")),
        body=str(d.get("body") or ""),
        labels=labels,
    )


def effort_minmax(body: str):
    """Return (min_runs, max_runs) from the Effort line, or None."""
    m = _EFFORT_LINE.search(body)
    if not m:
        return None
    lo = int(m.group("min"))
    hi = int(m.group("max")) if m.group("max") else lo
    return lo, max(lo, hi)


def is_design_task(body: str) -> bool:
    """Design/decomposition tasks are single-claim by design (their output IS
    the decomposition) — exempt from the Passes requirement even at >=2 runs."""
    return bool(_DESIGN_TASK.search(body))


def has_passes(body: str) -> bool:
    return bool(_PASSES_MARKER.search(body))


def count_pass_lines(body: str) -> int:
    m = _PASSES_MARKER.search(body)
    if not m:
        return 0
    return len(_PASS_PATTERN.findall(body[m.start():]))


def validate_body(number: int, title: str, body: str, min_runs: int):
    """Yield Findings for one issue body."""
    emm = effort_minmax(body)
    if emm is None:
        # No Effort line at all — legacy issues predate the convention. By
        # default this is silent (they are claimable but unenforceable); pass
        # --warn-no-effort to surface them in a sweep.
        if _WARN_NO_EFFORT:
            yield Finding(number, title, "warning",
                          "no Effort line found; cannot enforce pass sizing")
        return
    lo, hi = emm
    if hi < min_runs:
        return  # single-run or under threshold: compliant
    if is_design_task(body):
        return  # exempt (design task's deliverable is the decomposition)
    if has_passes(body):
        npass = count_pass_lines(body)
        if npass < hi:
            yield Finding(number, title, "warning",
                          f"Effort claims up to {hi} runs but Passes block has "
                          f"only {npass} pass line(s); under-specified")
        return
    yield Finding(number, title, "violation",
                  f"Effort claims {lo}-{hi} runs (multi-run) but the body has no "
                  f"'**Passes:**' block; must decompose into Pass 1..n per "
                  f"docs/MULTI_AGENT_WORKFLOW.md §Task definition")


def fetch_live() -> list:
    """Fetch issue pages via the GitHub REST API (requires GITHUB_TOKEN)."""
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        raise SystemExit("GITHUB_TOKEN not set; use --json-file for offline mode")
    issues = []
    page = 1
    while True:
        req = urllib.request.Request(
            f"{API}?state=open&per_page=100&page={page}",
            headers={"Authorization": f"Bearer {token}",
                     "Accept": "application/vnd.github+json",
                     "User-Agent": "pass-scan"},
        )
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
        if not data:
            break
        issues.extend(data)
        page += 1
        if len(data) < 100:
            break
    return [parse_issue_view(d) for d in issues]


def load_json(path: Path) -> list:
    data = json.loads(path.read_text())
    if isinstance(data, dict) and "issues" in data:
        data = data["issues"]
    return [parse_issue_view(d) for d in data]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Multi-run pass-sizing compliance scan")
    ap.add_argument("--json-file", type=Path, default=None,
                    help="Offline JSON dump of issues (list of issue dicts); "
                         "default: live GitHub fetch")
    ap.add_argument("--min-runs", type=int, default=DEFAULT_MIN_RUNS,
                    help="Minimum Effort runs that require a Passes block (default 2)")
    ap.add_argument("--warn-no-effort", action="store_true", default=False,
                    help="Also report legacy issues with no Effort line")
    args = ap.parse_args(argv)

    global _WARN_NO_EFFORT
    _WARN_NO_EFFORT = args.warn_no_effort

    if args.json_file is not None:
        if not args.json_file.exists():
            ap.error(f"file not found: {args.json_file}")
        issues = load_json(args.json_file)
    else:
        issues = fetch_live()

    violations: list[Finding] = []
    warnings: list[Finding] = []
    for iv in issues:
        if iv.number < 1:
            continue
        for f in validate_body(iv.number, iv.title, iv.body, args.min_runs):
            if f.kind == "violation":
                violations.append(f)
            elif f.kind == "warning":
                warnings.append(f)

    for f in violations:
        print(f"[VIOLATION] #{f.number} {f.title[:60]} — {f.detail}")
    for f in warnings:
        print(f"[warning]   #{f.number} {f.title[:60]} — {f.detail}")

    print(f"\n{len(issues)} issues scanned; "
          f"{len(violations)} violation(s), {len(warnings)} warning(s).")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())