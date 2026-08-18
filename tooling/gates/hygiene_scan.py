#!/usr/bin/env python3
"""Gate 6 (Tier 1) — hygiene scanner for PleaNP Lean source.

Flags proof-shortcut tokens that would make a "proof" compile without being
a real proof: sorry, admit, custom axioms, and heuristic abuse of decision/
suggester tactics. See ../README.md and docs/ARCHITECTURE.md (Gate 6).

This is Tier 1 only — a text scanner with no Lean toolchain. It CANNOT catch
sorry smuggled in via meta-programs (custom tactics that internally call sorry).
Tier 2 (the local agent's job, needs `lake build`) closes that gap via
`#print axioms`. Do not treat a Tier-1-only pass as "Gate 6 complete."

Usage:
    python3 hygiene_scan.py <path>            # scan one file or dir
    python3 hygiene_scan.py lean/PleaNP        # scan the library
    python3 hygiene_scan.py --prove-stage      # treat as frozen/proven: any sorry is a violation

Exit codes:
    0  clean (no violations)
    1  violations found (prints a report)
    2  usage error

The --prove-stage flag matters: during statement rendering (LOCAL_AGENT_WORKFLOW
Step 1) a single `:= by sorry` placeholder is EXPECTED and allowed; once a
statement is frozen and a proof is claimed complete, any sorry is a violation.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Tokens that are always shortcuts (sorry/admit) and tokens that are smells.
SHORTCUT_TOKENS = ("sorry", "admit")
# `axiom`/`constant` as a declaration. We match the keyword at a statement start,
# not occurrences inside comments or strings — see _strip_comments.
AXIOM_RE = re.compile(r"^\s*(namespace\s+\S+\s+)?(axiom|constant)\s+", re.MULTILINE)
# Legit tactics whose heavy use is a smell, not a violation. Counted, reported.
SMELL_TOKENS = ("by decide", "by exact?", "by exact ?", "by suggests")
# `irreducible` can hide a sorry behind a def — worth flagging for review.
IRREDUCIBLE_RE = re.compile(r"^\s*(private\s+)?irreducible\b", re.MULTILINE)


@dataclass
class Finding:
    file: Path
    line_no: int
    col: int
    kind: str          # "shortcut", "axiom", "smell", "irreducible"
    token: str
    line: str


def _strip_comments(src: str) -> str:
    """Remove block comments /- ... -/ (which can span lines and wrap tokens)
    and line comments -- so tokens inside comments aren't flagged.

    Lean block comments nest; a non-greedy single-level strip is a reasonable
    first cut for a hygiene scanner (Tier 1 is heuristic by design)."""
    # Block comments (non-nested strip; nested is rare in practice for hygiene)
    src = re.sub(r"/-.*? -/", "", src, flags=re.DOTALL)
    # Line comments
    src = re.sub(r"--.*?$", "", src, flags=re.MULTILINE)
    return src


def _find_token_lines(src: str, token: str) -> list[tuple[int, int, str]]:
    """Return (line_no, col, line) for each occurrence of token (as a word
    boundary match, so 'sorry' doesn't match inside 'sorrry' etc.)."""
    out: list[tuple[int, int, str]] = []
    # Word-boundary match, case-sensitive (Lean keywords are lowercase).
    pat = re.compile(r"\b" + re.escape(token) + r"\b")
    for m in pat.finditer(src):
        line_no = src.count("\n", 0, m.start()) + 1
        col = m.start() - src.rfind("\n", 0, m.start())
        line = src[src.rfind("\n", 0, m.start()) + 1 : src.find("\n", m.start())]
        out.append((line_no, col, line.strip()))
    return out


def scan_file(path: Path, prove_stage: bool) -> list[Finding]:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:  # unreadable file — report but don't crash
        print(f"warning: could not read {path}: {e}", file=sys.stderr)
        return []
    src = _strip_comments(raw)

    findings: list[Finding] = []

    # Shortcuts: always flag; in prove_stage they're violations, in render
    # stage a single `:= by sorry` placeholder is allowed (handled by caller).
    for tok in SHORTCUT_TOKENS:
        for ln, col, line in _find_token_lines(src, tok):
            findings.append(Finding(path, ln, col, "shortcut", tok, line))

    # Custom axioms
    for m in AXIOM_RE.finditer(src):
        line_no = src.count("\n", 0, m.start()) + 1
        col = m.start() - src.rfind("\n", 0, m.start())
        line = src[src.rfind("\n", 0, m.start()) + 1 : src.find("\n", m.start())]
        findings.append(Finding(path, line_no, col, "axiom", m.group(0).strip(), line.strip()))

    # Smells (counted, not violations)
    for tok in SMELL_TOKENS:
        for ln, col, line in _find_token_lines(src, tok):
            findings.append(Finding(path, ln, col, "smell", tok, line))

    # irreducible (flag for review)
    for m in IRREDUCIBLE_RE.finditer(src):
        line_no = src.count("\n", 0, m.start()) + 1
        col = m.start() - src.rfind("\n", 0, m.start())
        line = src[src.rfind("\n", 0, m.start()) + 1 : src.find("\n", m.end())]
        findings.append(Finding(path, line_no, col, "irreducible", "irreducible", line.strip()))

    return findings


def is_placeholder_sorry(f: Finding) -> bool:
    """A render-stage placeholder is `:= by sorry` (the whole proof is sorry).
    Heuristic: line contains 'sorry' and the line or its immediate context is
    a theorem/lemma statement ending in `by sorry`. We treat a sorry on a line
    that also contains 'by' (and ideally ':=') as the placeholder."""
    return (":=" in f.line or "by" in f.line) and "sorry" in f.token


def scan(paths: list[Path], prove_stage: bool) -> list[Finding]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files.extend(sorted(p.rglob("*.lean")))
        elif p.suffix == ".lean":
            files.append(p)
    files = sorted(set(files))

    all_findings: list[Finding] = []
    for f in files:
        fs = scan_file(f, prove_stage)
        if not prove_stage:
            # Render stage: drop the single allowed `:= by sorry` placeholder.
            # Keep *all other* sorry/admit (e.g. a sorry inside a proof body).
            fs = [x for x in fs if not (x.kind == "shortcut" and is_placeholder_sorry(x))]
        all_findings.extend(fs)
    return all_findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Gate 6 (Tier 1) hygiene scanner")
    ap.add_argument("path", nargs="+", type=Path, help=".lean file or dir to scan")
    ap.add_argument(
        "--prove-stage",
        action="store_true",
        help="Treat as frozen/proven: ANY sorry/admit is a violation "
        "(default: render-stage, where `:= by sorry` placeholder is allowed)",
    )
    args = ap.parse_args()

    findings = scan(args.path, args.prove_stage)

    violations = [f for f in findings if f.kind in ("shortcut", "axiom")]
    smells = [f for f in findings if f.kind in ("smell", "irreducible")]

    if findings:
        print(f"Gate 6 (Tier 1) findings across {len(set(f.file for f in findings))} file(s):")
        for f in findings:
            tag = "VIOLATION" if f.kind in ("shortcut", "axiom") else "REVIEW"
            print(f"  [{tag}] {f.kind:11} {f.file}:{f.line_no}:{f.col}  {f.token!r}  | {f.line}")
        print()
        print(f"  {len(violations)} violation(s), {len(smells)} review item(s)")
        if violations:
            return 1
    else:
        print(f"Gate 6 (Tier 1) clean: no sorry/admit/axiom in {len(args.path)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
