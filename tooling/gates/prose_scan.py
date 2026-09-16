#!/usr/bin/env python3
"""Gate: prose-corruption scan (the #101 signature).

Why this exists (PleaNP #101 / #110). A repeated text-corruption signature was
found across the tree: words fused where punctuation absorbed the following
space, and punctuation doubled. Real examples from the committed blobs:

    "queries to yes/no(one step,,and step-counting"      (paren fused; comma doubled)
    "Prop-carrying marker:the construction relativizes"  (colon ate the space)
    "constrains A),not vacuous;;and uniform in the oracle" (semicolon doubled)
    "below for the full rationale.. Issue #1 requested"   (period doubled)
    "the functions themselves,not on any oracle query"   (comma ate the space)

It was cosmetic in the Rung-5 comments, but the SAME join-across-a-boundary
signature reached `.github/workflows/ci.yml` where three step boundaries were
swallowed into the previous scalar (repaired in `1037101`); `workflow_scan.py`
covers the YAML case. The unicode scanner does NOT catch these — the
corruptions are plain ASCII. This is the general guard for the prose case.

Scope discipline (why this is not a false-positive machine):
  * It scans COMMENTS ONLY (Lean) / prose (markdown); code is never flagged.
  * Before matching it blanks (a) inline code spans `` `...` `` and (b)
    space-free bracketed groups — so legitimate Lean tuple notation such as
    `⟨n,x⟩`, `(true,true)`, `(n,y)` is not mistaken for a fused comma.
  * It looks for a small, high-signal set of ASCII join/double patterns.
  * `--allow-file <path>` accepts an audited exception, matching the
    `unicode_scan.py` escape-hatch convention.

Usage:
    python3 tooling/gates/prose_scan.py [paths...] [--allow-file <path>...]

Exit codes: 0 clean, 1 violations, 2 usage error.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def _blank_match(m: re.Match) -> str:
    return "".join("\n" if c == "\n" else " " for c in m.group(0))


def _comment_only_lines(raw: str) -> list[tuple[int, str]]:
    """Lean: (line_number, comment-only text) with code and non-comment blanked."""
    marked = [" "] * len(raw)
    for m in re.finditer(r"/-.*?-/", raw, flags=re.DOTALL):
        for i in range(m.start(), m.end()):
            marked[i] = "C"
    for m in re.finditer(r"--[^\n]*", raw):
        if all(marked[i] == " " for i in range(m.start(), m.end())):
            for i in range(m.start(), m.end()):
                marked[i] = "C"

    out: list[tuple[int, str]] = []
    pos = 0
    for lineno, line in enumerate(raw.splitlines(), start=1):
        marks = marked[pos:pos + len(line)]
        pos += len(line) + 1
        text = "".join(c if mk == "C" else " " for c, mk in zip(line, marks))
        if text.strip():
            out.append((lineno, text))
    return out


def comment_lines(path: Path) -> list[tuple[int, str]]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix == ".lean":
        return _comment_only_lines(raw)
    return [(i + 1, ln) for i, ln in enumerate(raw.splitlines())]


# Blank inline code spans and space-free bracketed groups (code-like tuples).
_CODE_SPAN_RE = re.compile(r"`[^`]*`")
_SPACELESS_GROUP_RE = re.compile(r"⟨[^⟩\s]*⟩|<[^>\s]*>|\([^)\s]*\)")


def _decorate(text: str) -> str:
    return _SPACELESS_GROUP_RE.sub(
        _blank_match, _CODE_SPAN_RE.sub(_blank_match, text))


CORRUPTION_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("doubled comma", re.compile(r",,")),
    ("doubled semicolon", re.compile(r";;")),
    # `..` is corruption when a letter/paren precedes it (a sentence-ending
    # period doubled), it is not part of `...` (ellipsis), and it is not a path
    # or numeric/hex range: `../foo`, `Pass 1..n`, `U+200E..U+200F`. A leading
    # `/`, digit, or `+` rules those out. Issue #101's canonical example,
    # "rationale.. Issue #1", has a letter before the `..` and is caught.
    ("doubled period", re.compile(r"(?<=[A-Za-z)\"`])\.\.(?!\.)")),
    ("colon absorbed space", re.compile(r"[A-Za-z)]:[A-Za-z]")),
    ("semicolon absorbed space", re.compile(r"[a-z];[A-Za-z]")),
    ("paren fused to word", re.compile(r"[A-Za-z]\),?[A-Za-z]")),
    ("comma fused to word", re.compile(r"[a-z],[A-Za-z]")),
]


def _string_literal_lines(raw: str) -> list[tuple[int, str]]:
    """Lean: (line_number, text) for string-literal *contents*.

    The #101 corruption is not confined to comments — the `#barrier_check`
    verdict templates in `BarrierCalculus.lean` are machine-authored prose
    inside `m!"..."` literals, and they carried the same fused punctuation.
    A source scan that skipped them would have missed real instances.
    """
    out: list[tuple[int, str]] = []
    i = 0
    n = len(raw)
    while i < n:
        c = raw[i]
        if c == '"':
            j = i + 1
            buf = []
            while j < n:
                if raw[j] == "\\" and j + 1 < n:
                    buf.append(raw[j:j + 2])
                    j += 2
                    continue
                if raw[j] == '"':
                    break
                buf.append(raw[j])
                j += 1
            text = "".join(buf)
            lineno = raw.count("\n", 0, i) + 1
            out.append((lineno, text))
            i = j + 1
        else:
            i += 1
    return out


def scan_file(path: Path, allowed: bool) -> list[str]:
    if allowed:
        return []
    findings: list[str] = []
    if path.suffix == ".lean":
        raw = path.read_text(encoding="utf-8", errors="replace")
        spans = comment_lines(path) + _string_literal_lines(raw)
    else:
        spans = comment_lines(path)
    for lineno, text in spans:
        clean = _decorate(text)
        for name, pat in CORRUPTION_PATTERNS:
            m = pat.search(clean)
            if m:
                s = max(0, m.start() - 22)
                e = min(len(clean), m.end() + 22)
                findings.append(
                    f"{path}:{lineno}: {name}: {m.group(0)!r} in "
                    f"{clean[s:e].strip()!r} (the #101 prose-corruption signature)"
                )
                break
    return findings


def scan(paths: list[Path], allow_files: set[str]) -> list[str]:
    findings: list[str] = []
    for p in paths:
        files = sorted(list(p.rglob("*.lean")) + list(p.rglob("*.md"))) if p.is_dir() else [p]
        for f in files:
            if ".lake" in f.parts:
                continue
            findings.extend(scan_file(f, str(f) in allow_files))
    return findings


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="prose-corruption scan (#101 signature)")
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--allow-file", action="append", default=[])
    args = ap.parse_args(argv[1:])

    root = Path.cwd()
    paths = [Path(p) for p in args.paths] if args.paths else [root / "lean" / "PleaNP"]
    findings = scan(paths, set(args.allow_file))
    if findings:
        print(f"Gate: prose integrity — {len(findings)} violation(s):")
        for f in findings:
            print(f"  [VIOLATION] {f}")
        return 1
    print(f"Gate: prose integrity clean: no #101 signature in {len(paths)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))