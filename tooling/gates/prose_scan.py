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

# Markdown structure that legitimately contains `word:word` and therefore must
# be masked before the colon/fusion rules run. Each of these was an observed
# false positive class on docs/ (the reason the scanner was originally scoped
# to lean/ only):
#   - markdown links and images: [text](url), ![alt](url)
#   - autolinks and URLs:        https://... , ghcr.io/owner/image:tag
#   - fenced code blocks:        ``` ... ```
_MD_LINK_RE = re.compile(r"!?\[[^\]]*\]\([^)]*\)")
_MD_URL_RE = re.compile(r"(?:https?://|ghcr\.io/)\S+")
# Label/value and path contexts observed as LEGITIMATE `word:word` in docs/:
#   status:available, priority:high, review:pending, File:Line, file:line:col
# Kept deliberately narrow: anything broader risks masking genuine corruption
# (the scanner's whole job), and the residue is inspected by hand.
_LABEL_TOKEN_RE = re.compile(
    r"\b(?:status|priority|review|File|file|line|col):[A-Za-z0-9]+")


def _decorate(text: str) -> str:
    return _SPACELESS_GROUP_RE.sub(
        _blank_match, _CODE_SPAN_RE.sub(_blank_match, text))


def _decorate_md(text: str) -> str:
    """Lean decoration plus markdown-structure masking (see the REs above).
    Fenced code blocks are excluded at the file level, not here."""
    text = _MD_LINK_RE.sub(_blank_match, text)
    text = _MD_URL_RE.sub(_blank_match, text)
    text = _LABEL_TOKEN_RE.sub(_blank_match, text)
    return _decorate(text)


_MD_MASK_RES = (
    _MD_LINK_RE, _MD_URL_RE, _LABEL_TOKEN_RE,
    _CODE_SPAN_RE, _SPACELESS_GROUP_RE,
)
_LEAN_MASK_RES = (_CODE_SPAN_RE, _SPACELESS_GROUP_RE)


def excluded_spans(text: str, kind: str) -> list[tuple[int, int]]:
    """Character spans that must NOT be rewritten (code, links, labels, tuples).

    Shared by the scanner and the fixer so the two can never drift: what the
    scanner ignores is exactly what the fixer leaves alone. Fenced code blocks
    span multiple lines, so they are excluded at the FILE level (see
    `fenced_lines`), not here.
    """
    res = _MD_MASK_RES if kind == "md" else _LEAN_MASK_RES
    spans: list[tuple[int, int]] = []
    for r in res:
        spans += [(m.start(), m.end()) for m in r.finditer(text)]
    return spans


def fenced_lines(text: str) -> set[int]:
    """1-based line numbers inside ``` fenced code blocks (markdown).

    Fences span lines, so this cannot be done per line — which is exactly the
    bug that let a `"../PleaNP"` path inside a fenced `lean` example get
    "fixed" to `"./PleaNP"`.
    """
    inside: set[int] = set()
    in_fence = False
    for i, ln in enumerate(text.split("\n"), start=1):
        if ln.lstrip().startswith("```"):
            in_fence = not in_fence
            inside.add(i)
            continue
        if in_fence:
            inside.add(i)
    return inside


CORRUPTION_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("doubled comma", re.compile(r",,")),
    ("doubled semicolon", re.compile(r";;")),
    # `..` is corruption when a letter/paren precedes it AND whitespace or the line
    # end follows (a sentence period was doubled). That excludes the legitimate
    # `..` in paths (`../x`, `"../PleaNP"` — space/quote before), hex/numeric
    # ranges (`U+200E..U+200F`, `Pass 1..n` — a letter/digit follows), and
    # ellipsis (`...`). Issue #101's canonical "rationale.. Issue #1" is caught.
    ("doubled period", re.compile(r"(?<=[A-Za-z)])\.\.(?=\s|$)")),
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
        decorate = _decorate
        skip: set[int] = set()
    else:
        raw = path.read_text(encoding="utf-8", errors="replace")
        spans = comment_lines(path)
        decorate = _decorate_md
        skip = fenced_lines(raw)
    for lineno, text in spans:
        if lineno in skip:
            continue
        clean = decorate(text)
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
            if ".lake" in f.parts or ".git" in f.parts or ".pytest_cache" in f.parts:
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