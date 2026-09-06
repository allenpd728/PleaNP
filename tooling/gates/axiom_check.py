#!/usr/bin/env python3
"""Gate 6 (Tier 2) — axiom-tracking hygiene for PleaNP Lean proofs.

Catches what hygiene_scan.py (Tier 1 grep) cannot: `sorry` smuggled via a
meta-program, or a proof depending on a non-Mathlib axiom. Generates a checker
`<tmp>.lean` that imports the clean modules and `#print axioms <Theorem>`
for each named theorem, then asserts the axiom set contains NO `sorryAx` and
only Mathlib/Lean-standard axioms.

This is the LOCAL AGENT'S job per DEC-007: it requires the Lean toolchain
(`lake` + `lake env lean`). Intended for CI — after `lake build` of the clean
modules, run this so "no smuggled sorries" is a continuous machine guarantee
(see docs/STATEMENTS/SEMANTIC_APPROVAL.md and docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md).

Usage (from the lean/ directory — the lake root):

    python3 ../tooling/gates/axiom_check.py <import-spec> <Theorem1> <Theorem2> ...

where <import-spec> is a comma-separated list of Lean modules to import, e.g.:

    python3 ../tooling/gates/axiom_check.py PleaNP.Computability.Oracle,PleaNP.Computability.OracleComplexity \
        PleaNP.Oracles.evalsTo_unique_result PleaNP.Oracles.P_A_subset_NP_A

Exit codes: 0 clean, 1 violations, 2 usage error.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

# Axioms that are acceptable: the standard Mathlib/Lean set.
# Anything else (notably 'sorryAx') is a violation.
KNOWN_STANDARD = {
    "propext",
    "Classical.choice",
    "Quot.sound",
    "funext",
    "Quot.ind",
}


def run_check(imports: list[str], theorems: list[str], lean_dir: Path) -> list[str]:
    """Write a checker .lean (imports + #print axioms for each theorem), run it
    via `lake env lean`, and parse the axiom reports. Returns violations."""
    lines = [f"import {m}" for m in imports]
    lines.append("")
    for t in theorems:
        lines.append(f"#print axioms {t}")
    src = "\n".join(lines) + "\n"

    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(src)
        checker = Path(f.name)

    violations: list[str] = []
    try:
        cmd = ["lake", "env", "lean", str(checker)]
        try:
            proc = subprocess.run(cmd, cwd=str(lean_dir), capture_output=True,
                                  text=True, timeout=420)
        except subprocess.TimeoutExpired:
            return [f"TIMEOUT running lean on {checker.name}"]
        out = (proc.stdout or "") + (proc.stderr or "")

        if "sorryAx" in out:
            violations.append("sorryAx found in axiom report — a sorry was smuggled via a meta-program!")

        for t in theorems:
            marker = f"'{t}' depends on axioms:"
            found_line = None
            for line in out.splitlines():
                if marker in line:
                    found_line = line
                    break
            if found_line is None:
                # The 'depends on axioms' line may be absent if there was an
                # error (e.g. unknown constant) — surface that.
                if f"Unknown constant `{t}`" in out or f"unknownIdentifier" in out:
                    violations.append(f"{t}: not found (unknown constant — wrong namespace?)")
                else:
                    violations.append(f"{t}: no axiom report found")
                continue
            start = found_line.index("[")
            end = found_line.index("]", start)
            axioms = [a.strip() for a in found_line[start + 1:end].split(",") if a.strip()]
            bad = [a for a in axioms if a not in KNOWN_STANDARD]
            if bad:
                violations.append(f"{t} depends on NON-STANDARD axioms: {bad}")
    finally:
        checker.unlink(missing_ok=True)
    return violations


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    imports = [s.strip() for s in sys.argv[1].split(",") if s.strip()]
    theorems = sys.argv[2:]
    lean_dir = Path.cwd()
    violations = run_check(imports, theorems, lean_dir)
    if violations:
        print("Gate 6 Tier 2 violations:")
        for v in violations:
            print(f"  [VIOLATION] {v}")
        return 1
    print(f"Gate 6 (Tier 2) clean: {len(theorems)} theorem(s) use only standard axioms; no sorryAx.")
    return 0


if __name__ == "__main__":
    sys.exit(main())