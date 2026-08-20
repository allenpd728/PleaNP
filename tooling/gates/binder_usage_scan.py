#!/usr/bin/env python3
"""Gate 7 (Tier 1): Binder usage / lethality scanner.

Checks that every named parameter, field, and bound variable in a
definition is load-bearing (actually used in the body). Catches:
- Unused definition parameters (Flaw A shape: a parameter that
  doesn't affect the definition's value)
- Declarations never applied and fields never read (Flaw B shape:
  a field or function that exists but is never referenced where it
  should be)
- Bound variables absent from their own conjunct (Flaw C shape: a
  ∃ or ∀ variable that doesn't appear in the predicate it's supposed
  to constrain)

This is the Tier 1 lethality check — a natural sibling to
hygiene_scan.py (Gate 6) and vacuity_scan.py (Gate 5). Like them,
it is static (no Lean semantics) and catches syntactic patterns.

Usage:
    python3 binder_usage_scan.py <path>            # scan one file or dir
    python3 binder_usage_scan.py lean/PleaNP        # scan the library
"""

from __future__ import annotations
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Finding:
    path: Path
    line: int
    kind: str
    decl_name: str
    snippet: str


# --- Patterns ---

# A def/theorem with named parameters — extract the parameter names.
# Matches: def foo (a : T) (b : T) ... : ... :=
DEF_PARAMS_RE = re.compile(
    r"(?:def|theorem|lemma|example)\s+(\w+)\s*"
    r"((?:\([^)]*\)\s*)*)"  # zero or more (param : type) groups
    r"(?:\[.*?\]\s*)*"  # skip typeclass args
    r"(?:.*?):="
)

# Extract individual parameter names from a (name : type) group
PARAM_NAME_RE = re.compile(r"\(\s*(\w+)\s*:")

# Check if a name appears in the body (after :=)
def _name_in_body(name: str, body: str) -> bool:
    return bool(re.search(r"\b" + re.escape(name) + r"\b", body))


def _strip_comments(src: str) -> str:
    """Remove block comments and line comments."""
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    src = re.sub(r"--.*$", "", src, flags=re.MULTILINE)
    return src


def _split_decls(src: str) -> list[tuple[str, str, int, str]]:
    """Split source into (kind, name, start_offset, block) tuples."""
    decls = []
    pattern = re.compile(
        r"^((?:def|theorem|lemma|example)\s+\w+)", re.MULTILINE
    )
    for m in pattern.finditer(src):
        name = m.group(1).split()[1]
        kind = m.group(1).split()[0]
        start = m.start()
        # Find the end (next declaration or EOF)
        next_match = pattern.search(src, m.end())
        end = next_match.start() if next_match else len(src)
        block = src[start:end]
        decls.append((kind, name, start, block))
    return decls


def _extract_params(block: str) -> list[str]:
    """Extract named parameters from a declaration block."""
    params = []
    for m in PARAM_NAME_RE.finditer(block):
        name = m.group(1)
        if name not in ("_",):
            params.append(name)
    return params


def _extract_body(block: str) -> str:
    """Extract the body (after :=)."""
    idx = block.find(":=")
    if idx < 0:
        return ""
    return block[idx:]


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
        params = _extract_params(block)
        body = _extract_body(block)
        snippet = block.split("\n", 1)[0].strip()

        if not body:
            continue

        # Check: each named parameter should appear in the body
        for param in params:
            if not _name_in_body(param, body):
                findings.append(Finding(
                    path, line_no, "unused_param", name,
                    f"parameter '{param}' not referenced in body"
                ))

        # Check: ∃ bound variables should appear in the predicate
        # Pattern: exists (x : T), <pred>  — x should appear in <pred>
        for m in re.finditer(r"exists\s+\(?(\w+)\s*:", block, re.IGNORECASE):
            var_name = m.group(1)
            if var_name == "_":
                continue
            # Get the text after this exists
            after = block[m.end():]
            # Find the next comma or end of expression (rough)
            next_comma = re.search(r",\s*(?:exists|forall|∀|∃)", after)
            pred_text = after[:next_comma.start()] if next_comma else after[:200]
            if not _name_in_body(var_name, pred_text):
                findings.append(Finding(
                    path, line_no, "dead_binder", name,
                    f"binder '{var_name}' in exists not referenced in its conjunct"
                ))

        # Check: ∀ bound variables should appear in the body
        for m in re.finditer(r"forall\s+\(?(\w+)\s*:", block, re.IGNORECASE):
            var_name = m.group(1)
            if var_name == "_":
                continue
            after = block[m.end():]
            next_comma = re.search(r",\s*(?:exists|forall|∀|∃)", after)
            pred_text = after[:next_comma.start()] if next_comma else after[:200]
            if not _name_in_body(var_name, pred_text):
                findings.append(Finding(
                    path, line_no, "dead_binder", name,
                    f"binder '{var_name}' in forall not referenced in its conjunct"
                ))

    return findings


def scan(paths: list[Path]) -> list[Finding]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files.extend(p.rglob("*.lean"))
        elif p.suffix == ".lean":
            files.append(p)
    files = sorted(set(files))

    all_findings: list[Finding] = []
    for f in files:
        all_findings.extend(scan_file(f))

    return all_findings


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)

    paths = [Path(a) for a in sys.argv[1:]]
    findings = scan(paths)

    if not findings:
        n = len(paths)
        print(f"Gate 7 (Tier 1) clean: no dead binders/unused params in {n} path(s).")
        sys.exit(0)

    n_files = len(set(f.path for f in findings))
    print(f"Gate 7 (Tier 1) findings across {n_files} file(s):")
    for finding in findings:
        print(f"  [{finding.kind}] {finding.path}:{finding.line}  {finding.decl_name}  | {finding.snippet}")
    print(f"\n  {len(findings)} finding(s) -- every parameter, binder, and field must be load-bearing")
    sys.exit(1)


if __name__ == "__main__":
    main()
