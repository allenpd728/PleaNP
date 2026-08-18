#!/usr/bin/env python3
"""Gate 5 (Tier 1) -- non-triviality / vacuity scanner for PleaNP Lean source.

Flags statements and definitions whose bodies are vacuously true or trivially
constructed -- the "compiles but means nothing" pattern that a hygiene scan
(sorry/admit/axiom) misses but that the failure audit (Pattern A) warns about.

Catches the DISHONEST placeholder pattern:
- a theorem/lemma whose statement is `True` and proved by `trivial`/`rfl`/
  `decide` (not `sorry`) -- a real-looking theorem proving a triviality
- a definition with `iff True` in the body -- vacuous equivalence
  (the `forall x, x in L iff True` pattern)
- a def whose body is a bare `none` -- constant failure masquerading as an
  implementation (the `stepCountByEvalsToInTime ... := none` pattern)

Does NOT flag the HONEST placeholder: `: True := by sorry` (caught by Gate 6),
or a clearly-marked `-- placeholder` comment. A `sorry` is honest; a `trivial`
proof of `True` is a fake success.

This is the Tier 1 of Gate 5 (non-triviality): static, no Lean semantics.
Like hygiene_scan.py (Gate 6 Tier 1), it CANNOT catch vacuity that requires
understanding what a definition *means* -- that is Gate 4 (read-back) and
the review layer's job. "Gate 5 passed" = Tier 1 + review, not Tier 1 alone.

Usage:
    python3 vacuity_scan.py <path>            # scan one file or dir
    python3 vacuity_scan.py lean/PleaNP        # scan the library

Exit codes:
    0  clean (no vacuity patterns found)
    1  vacuity patterns found (prints a report)
    2  usage error
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Finding:
    file: Path
    line_no: int
    kind: str
    decl_name: str
    snippet: str


def _strip_comments(src: str) -> str:
    """Remove block comments /- ... -/ and line comments --."""
    src = re.sub(r"/-.*? -/", "", src, flags=re.DOTALL)
    src = re.sub(r"--.*?$", "", src, flags=re.MULTILINE)
    return src


# Matches the start of a top-level declaration: def/theorem/lemma/etc.
# We use this to split the source into per-declaration blocks.
DECL_START_RE = re.compile(
    r"^(def|theorem|lemma|structure|class|inductive|instance|abbrev|axiom|constant)\s+(\S+)",
    re.MULTILINE,
)


def _split_decls(src: str) -> list[tuple[str, str, int]]:
    """Split source into (decl_kind, decl_name, start_offset) blocks.
    Returns list of (kind, name, offset) for each top-level declaration."""
    decls = []
    for m in DECL_START_RE.finditer(src):
        decls.append((m.group(1), m.group(2), m.start()))
    # Each block runs from its start to the next decl's start (or EOF).
    blocks = []
    for i, (kind, name, start) in enumerate(decls):
        end = decls[i + 1][2] if i + 1 < len(decls) else len(src)
        blocks.append((kind, name, start, src[start:end]))
    return blocks


# Patterns applied WITHIN a single declaration block.

# A theorem/lemma with `: True := by trivial` (or rfl/decide). NOT `sorry`.
THEOREM_TRUE_TRIVIAL_RE = re.compile(r":\s*True\s*:=\s*by\s+(trivial|rfl|decide)\b")

# A block with `iff True` (the unicode arrow). Vacuous equivalence.
IFF_TRUE_RE = re.compile(r"\u2194\s*True\b")

# A def with `:= True` (bare equality to True as a body).
EQ_TRUE_DEF_RE = re.compile(r":=\s*True\b")

# A def whose body is a bare `none` (constant failure). The body is the text
# after `:=`; we check it is whitespace-then-none (no other tokens).
DEF_NONE_RE = re.compile(r":=\s*none\b")


def scan_file(path: Path) -> list[Finding]:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        print(f"warning: could not read {path}: {e}", file=sys.stderr)
        return []
    src = _strip_comments(raw)

    findings: list[Finding] = []
    for kind, name, start, block in _split_decls(src):
        line_no = src.count("\n", 0, start) + 1
        # First line of the block for the snippet.
        snippet = block.split("\n", 1)[0].strip()

        if kind in ("theorem", "lemma"):
            if THEOREM_TRUE_TRIVIAL_RE.search(block):
                findings.append(Finding(path, line_no, "theorem_true_trivial", name, snippet))

        if kind == "def":
            if IFF_TRUE_RE.search(block):
                findings.append(Finding(path, line_no, "vacuous_iff_true", name, snippet))
            elif EQ_TRUE_DEF_RE.search(block):
                findings.append(Finding(path, line_no, "vacuous_eq_true", name, snippet))
            if DEF_NONE_RE.search(block):
                findings.append(Finding(path, line_no, "def_none", name, snippet))

    return findings


def scan(paths: list[Path]) -> list[Finding]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files.extend(sorted(p.rglob("*.lean")))
        elif p.suffix == ".lean":
            files.append(p)
    files = sorted(set(files))

    all_findings: list[Finding] = []
    for f in files:
        all_findings.extend(scan_file(f))
    return all_findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Gate 5 (Tier 1) vacuity scanner")
    ap.add_argument("path", nargs="+", type=Path, help=".lean file or dir to scan")
    args = ap.parse_args()

    findings = scan(args.path)

    if findings:
        print(f"Gate 5 (Tier 1) findings across {len(set(f.file for f in findings))} file(s):")
        for f in findings:
            print(f"  [REVIEW] {f.kind:22} {f.file}:{f.line_no}  {f.decl_name}  | {f.snippet}")
        print()
        print(f"  {len(findings)} vacuity pattern(s) -- review for dishonest placeholders")
        return 1
    else:
        print(f"Gate 5 (Tier 1) clean: no trivially-true/vacuous patterns in {len(args.path)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
