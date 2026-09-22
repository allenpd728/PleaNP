#!/usr/bin/env python3
"""Gate (Tier 1) — `docs/SORRY_TRACKER.md` must match the real `sorry` sites.

`docs/SORRY_TRACKER.md` is the repo's declared `sorry` ledger: AGENTS.md says
"every `sorry` in `lean/PleaNP/` must appear in this table". Nothing checked it
against the code, so it silently drifted — stale line numbers and an undercount
(issue #127). This scanner closes that gap: it asserts

  * **site equality** — the set of open tracker rows (file:line) equals the set
    of `sorry` sites actually present in `lean/PleaNP/`; and
  * **count consistency** — the Summary table's per-file counts and its Total
    agree with the actual sites (so a row that lives in a second table cannot
    silently fall out of the total).

A Resolved/Removed row is *not* an open row: only rows under
`## Detailed inventory` count, and struck-through (`~~`) rows are ignored. (If
the heading is absent — e.g. a unit-test fixture — the whole document is treated
as active, preserving the old fixture behaviour.)

Tier 1 only: a text scanner with no Lean toolchain, so it sees `sorry` tokens in
source (comments/strings stripped, the same machinery as Gate 6's
`hygiene_scan.py`) but not one smuggled in via a meta-program. Tier 2
(`axiom_check.py`, `#print axioms`) covers that.

Usage:
    python3 tooling/gates/sorry_tracker_scan.py [repo_root]

Exit codes:
    0  clean (tracker matches the code)
    1  drift (prints a report)
    2  usage error
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hygiene_scan import _strip_comments  # noqa: E402  (same-dir sibling)

SORRY_RE = re.compile(r"\bsorry\b")
# A tracker row that is either struck through or whose What-cell says Resolved/Removed.
RESOLVED_MARKERS = ("~~", "**Resolved", "**Removed", "Resolved 20", "Removed —")
FILE_LINE_RE = re.compile(r"([A-Za-z0-9_./-]+\.lean):(\d+)")
FILE_RE = re.compile(r"([A-Za-z0-9_./-]+\.lean)")
DETAILED_HEADING = "## Detailed inventory"


def actual_sorry_sites(repo_root: Path) -> set[tuple[str, int]]:
    """`(relative path from repo root, 1-based line)` for every `\\bsorry\\b`
    token in `lean/PleaNP/**/*.lean`, comments and strings stripped."""
    lib = repo_root / "lean" / "PleaNP"
    sites: set[tuple[str, int]] = set()
    for path in sorted(lib.rglob("*.lean")):
        src = _strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for i, line in enumerate(src.splitlines(), start=1):
            if SORRY_RE.search(line):
                rel = path.relative_to(repo_root).as_posix()
                sites.add((rel, i))
    return sites


def _active_section(tracker_md: str) -> list[str]:
    """Lines of the `## Detailed inventory` section, or the whole document when
    that heading is absent (unit-test fixtures)."""
    lines = tracker_md.splitlines()
    start = next((i for i, ln in enumerate(lines) if ln.strip() == DETAILED_HEADING), None)
    if start is None:
        return lines
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].strip().startswith("## "):
            end = i
            break
    return lines[start:end]


def _matches_tracker_path(actual: str, cited: str) -> bool:
    """Tracker rows cite either a full path (`lean/PleaNP/.../X.lean`) or a bare
    basename (`Relativization.lean`); match on the cited path being a suffix."""
    return actual == cited or actual.endswith("/" + cited)


def tracker_open_rows(tracker_md: str) -> list[tuple[str, str, int]]:
    """`(row id, cited path, line)` for every open row in the active section."""
    rows: list[tuple[str, str, int]] = []
    for line in _active_section(tracker_md):
        line = line.strip()
        if not line.startswith("|"):
            continue
        if any(mark in line for mark in RESOLVED_MARKERS):
            continue
        m = FILE_LINE_RE.search(line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        row_id = cells[0].strip("#") if cells else "?"
        rows.append((row_id, m.group(1), int(m.group(2))))
    return rows


def summary_counts(tracker_md: str) -> tuple[dict[str, int], int | None]:
    """Parse the `## Summary` section → (per-file cited counts, declared Total)."""
    lines = tracker_md.splitlines()
    start = next((i for i, ln in enumerate(lines) if ln.strip() == "## Summary"), None)
    per_file: dict[str, int] = {}
    total: int | None = None
    if start is None:
        return per_file, total
    for i in range(start + 1, len(lines)):
        line = lines[i].strip()
        if line.startswith("## ") and i > start + 1:
            break
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if not cells:
            continue
        first = cells[0].strip("`")
        if first.startswith("**Total"):
            m = re.search(r"\*\*(\d+)\s+open", line)
            if m:
                total = int(m.group(1))
            continue
        m = FILE_RE.search(cells[0])
        if not m:
            continue
        cm = re.match(r"(\d+)", cells[1]) if len(cells) > 1 else None
        if cm:
            per_file[m.group(1)] = int(cm.group(1))
    return per_file, total


def check(repo_root: Path) -> tuple[bool, list[str]]:
    tracker_md = (repo_root / "docs" / "SORRY_TRACKER.md").read_text(encoding="utf-8")
    actual = actual_sorry_sites(repo_root)
    rows = tracker_open_rows(tracker_md)
    problems: list[str] = []

    # 1. Site equality (both directions).
    tracked: dict[tuple[str, int], str] = {}
    for row_id, cited, ln in rows:
        matches = [(a, n) for (a, n) in actual if n == ln and _matches_tracker_path(a, cited)]
        if not matches:
            problems.append(
                f"tracker row #{row_id} cites {cited}:{ln}, which is not a `sorry` site "
                f"in lean/PleaNP/")
        else:
            tracked[matches[0]] = row_id
    for site in sorted(actual):
        if site not in tracked:
            problems.append(
                f"`sorry` at {site[0]}:{site[1]} has no open row in docs/SORRY_TRACKER.md")

    # 2. Count consistency: per-file Summary rows + declared Total.
    per_file, declared_total = summary_counts(tracker_md)
    actual_by_file: dict[str, int] = {}
    for f, _ in actual:
        actual_by_file[f] = actual_by_file.get(f, 0) + 1
    for cited, claimed in sorted(per_file.items()):
        matches = {f: c for f, c in actual_by_file.items() if _matches_tracker_path(f, cited)}
        real = sum(matches.values())
        if real != claimed:
            problems.append(
                f"Summary row for {cited} claims {claimed} `sorry`, actual {real}")
    for f, n in sorted(actual_by_file.items()):
        if not any(_matches_tracker_path(f, cited) for cited in per_file):
            problems.append(f"{f} has {n} `sorry` but no Summary row")
    if declared_total is not None and declared_total != len(actual):
        problems.append(
            f"Summary Total claims {declared_total} open, actual {len(actual)}")

    return (not problems), problems


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print(__doc__, file=sys.stderr)
        return 2
    repo_root = Path(argv[1]).resolve() if len(argv) == 2 else Path(__file__).resolve().parents[2]
    if not (repo_root / "docs" / "SORRY_TRACKER.md").is_file():
        print(f"error: no docs/SORRY_TRACKER.md under {repo_root}", file=sys.stderr)
        return 2
    ok, problems = check(repo_root)
    if ok:
        print("SORRY_TRACKER scan clean: tracker matches lean/PleaNP/ (sites + counts).")
        return 0
    print("SORRY_TRACKER scan found drift between docs/SORRY_TRACKER.md and lean/PleaNP/:")
    for p in problems:
        print(f"  - {p}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
