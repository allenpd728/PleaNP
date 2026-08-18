#!/usr/bin/env python3
"""Gate 2 (Tier 1) -- model-consistency scanner for PleaNP Lean source.

Flags local redefinitions of canonical types and forbidden namespace usage --
the "redefine NP weaker and prove the redefined thing" failure mode
(docs/FAILURE_AUDIT.md Pattern A, Gate 2 in docs/ARCHITECTURE.md).

Checks:
- Local `def`/`abbrev`/`notation` of complexity-class names (P, NP, PSPACE, etc.)
  outside the PleaNP namespace -- these should be imported from upstream
  (DEC-003) or defined under PleaNP.*, not as bare top-level names.
- Usage of the `Complexity.*` namespace -- forbidden per DEC-002.
- Local redefinition of `Oracle` outside `PleaNP.Oracles`.

Tracks namespace context so defs inside `namespace PleaNP.Oracles` (which are
qualified PleaNP.Oracles.*) are NOT false-flagged.

This is the Tier 1 of Gate 2: static, no Lean semantics. It CANNOT catch a
subtly-weaker redefinition using a different name (e.g. `def MyNP`) -- that is
a semantic check (Gate 4 read-back + review). "Gate 2 passed" = Tier 1 + review.

Usage:
    python3 model_consistency_scan.py <path>
    python3 model_consistency_scan.py lean/PleaNP

Exit codes: 0 clean, 1 violations, 2 usage error.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Canonical names that must not be locally (re)defined outside PleaNP.
CANONICAL_NAMES = {
    "P", "NP", "PSPACE", "EXP", "NEXP", "BPP", "RP", "ZPP", "PP",
    "P_poly", "Ppoly", "NP_complete", "NP_hard", "NPcomplete", "NPhard",
    "DTIME", "NTIME", "DSPACE", "NSPACE",
    "Oracle", "OracleMachine", "StepCount",
}

PLEANP_NS = "PleaNP"


@dataclass
class Finding:
    file: Path
    line_no: int
    kind: str
    detail: str
    line: str


def _strip_comments(src: str) -> str:
    src = re.sub(r"/-.*? -/", "", src, flags=re.DOTALL)
    src = re.sub(r"--.*?$", "", src, flags=re.MULTILINE)
    return src


def _namespace_stack_at(src: str, offset: int) -> list[str]:
    """Return the stack of open namespaces at `offset` (innermost last)."""
    ns_stack: list[str] = []
    for m in re.finditer(r"^\s*(namespace\s+(\S+)|end\s+(\S+)?)\s*$", src[:offset], re.MULTILINE):
        if m.group(2):  # namespace X
            ns_stack.append(m.group(2))
        elif m.group(3):  # end X
            if ns_stack and ns_stack[-1] == m.group(3):
                ns_stack.pop()
            elif ns_stack:
                ns_stack.pop()
    return ns_stack


def _in_pleanp(ns_stack: list[str]) -> bool:
    return any(ns == PLEANP_NS or ns.startswith(PLEANP_NS + ".") for ns in ns_stack)


LOCAL_DEF_RE = re.compile(r"^\s*(def|abbrev|notation|instance)\s+(\w+)", re.MULTILINE)
FORBIDDEN_NS_RE = re.compile(r"\bComplexity\.(\w+)")


def scan_file(path: Path) -> list[Finding]:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        print(f"warning: could not read {path}: {e}", file=sys.stderr)
        return []
    # Work on RAW source throughout, so namespace tracking offsets align with
    # def-matching offsets. We skip defs inside comments by checking if the
    # match position falls within a stripped region.
    src = _strip_comments(raw)
    # Build a mask of which character positions are "live" (not stripped).
    # We do this by comparing stripped vs raw -- positions that survive in
    # the stripped source are live. A simpler approach: just check whether
    # the raw line at the match position starts with `def` (comment-stripped
    # lines that were inside comments are now empty or removed, so a `def`
    # match on raw that's actually inside a comment would be on a line that
    # also contains `/-` or `--`). We check the raw line for comment markers.
    findings: list[Finding] = []

    # Forbidden Complexity.* namespace usage.
    for m in FORBIDDEN_NS_RE.finditer(raw):
        line_no = raw.count("\n", 0, m.start()) + 1
        ls = raw.rfind("\n", 0, m.start()) + 1
        le = raw.find("\n", m.start())
        if le == -1:
            le = len(raw)
        line = raw[ls:le]
        # Skip if inside a comment line.
        stripped_line = re.sub(r"--.*$", "", re.sub(r"/-.*? -/", "", line))
        if m.group(0) not in stripped_line:
            continue
        findings.append(Finding(path, line_no, "forbidden_namespace",
                                f"Complexity.{m.group(1)}", line.strip()))

    # Local definitions of canonical names -- but only OUTSIDE PleaNP.*.
    for m in LOCAL_DEF_RE.finditer(raw):
        name = m.group(2)
        if name not in CANONICAL_NAMES:
            continue
        # Skip if this match is inside a comment (check the raw line).
        ls = raw.rfind("\n", 0, m.start()) + 1
        le = raw.find("\n", m.start())
        if le == -1:
            le = len(raw)
        line = raw[ls:le]
        stripped_line = re.sub(r"--.*$", "", re.sub(r"/-.*? -/", "", line))
        if m.group(0) not in stripped_line:
            continue  # Inside a comment -- skip.
        ns_stack = _namespace_stack_at(raw, m.start())
        if _in_pleanp(ns_stack):
            continue  # Qualified PleaNP.* def -- not a shadow.
        line_no = raw.count("\n", 0, m.start()) + 1
        findings.append(Finding(path, line_no, "local_redefinition",
                                f"{m.group(1)} {name}", line.strip()))

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
    ap = argparse.ArgumentParser(description="Gate 2 (Tier 1) model-consistency scanner")
    ap.add_argument("path", nargs="+", type=Path, help=".lean file or dir to scan")
    args = ap.parse_args()
    findings = scan(args.path)
    if findings:
        print(f"Gate 2 (Tier 1) findings across {len(set(f.file for f in findings))} file(s):")
        for f in findings:
            print(f"  [VIOLATION] {f.kind:25} {f.file}:{f.line_no}  {f.detail}  | {f.line}")
        print(f"\n  {len(findings)} model-consistency violation(s)")
        return 1
    else:
        print(f"Gate 2 (Tier 1) clean: no local redefinitions or forbidden namespaces in {len(args.path)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
