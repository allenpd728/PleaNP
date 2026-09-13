#!/usr/bin/env python3
"""Machine-check the gate-REVIEW register on the clean modules (issue #92).

Runs the four Tier-1 gate scans against the CI scan set and asserts:
  1. every scan exits 0 (0 violations),
  2. the REVIEW items exactly match `docs/GATE_REVIEW_NOTES.md`'s expected
     set, keyed on *provenance* (module + declaration/token), tolerant of
     line-number drift,
  3. an unexpected REVIEW item fails the check with its text, so a new scan
     finding cannot silently appear once the register is established.

Stdlib-only, no Lean, no secrets — mirrors the ci.yml invocations exactly, so
it is a runnable local oracle for the register.

Usage:
    python3 gate_review_register_check.py            # run the check (exit 0/1)
    python3 gate_review_register_check.py --verbose  # print matched items
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCAN_SET = (
    "lean/PleaNP/Calculus lean/PleaNP/Basic.lean "
    "lean/PleaNP/Benchmark/Closure.lean "
    "lean/PleaNP/Barriers/RelativizationProof.lean "
    "lean/PleaNP/Barriers/Algebrization.lean "
    "lean/PleaNP/Challenges/Relativization.lean "
    "lean/PleaNP/Computability/Oracle.lean "
    "lean/PleaNP/Computability/OracleComplexity.lean "
    "lean/PleaNP/Computability/OracleSmoke.lean "
    "lean/PleaNP/Computability/OracleV5Tests.lean"
).split()
BINDER_ALLOW = (
    r"^(exists_equalizing_oracle|exists_separating_oracle|"
    r"smoke_accepts_true|smoke_rejects_false|"
    r"v5_smoke_accepts_true|v5_smoke_rejects_false)$"
)

# Expected REVIEW items from docs/GATE_REVIEW_NOTES.md ("the register table"),
# keyed on provenance: (scanner, module-leaf, declaration/token).
# Tolerant of line drift: only the module + token must match.
EXPECTED = {
    ("hygiene", "OracleSmoke.lean", "by decide"),
    ("hygiene", "OracleV5Tests.lean", "by decide"),
    ("binder", "BarrierVerdictB.lean", "abstractPVsNP_iff_verdictB"),
    ("binder", "OracleComplexity.lean", "y"),             # weak witness ∃ y
    ("binder", "OracleComplexity.lean", "P_A_subset_NP_A"),
    ("binder", "OracleComplexity.lean", "UpstreamPolyTime"),  # P^∅ = P anchor RHS
    # Rung-5 soundness lemma API (issue #65): library-level uniformity
    # lemmas, intentional public API for downstream proofs (see
    # docs/GATE_REVIEW_NOTES.md §3).
    ("binder", "Soundness.lean", "funeq_uniform"),
    ("binder", "Soundness.lean", "funne_uniform"),
    ("binder", "Soundness.lean", "pA_mem_uniform"),
    ("binder", "Soundness.lean", "relAtom_uniform"),
    ("binder", "Soundness.lean", "sound_verdict_abstract_rev"),
    ("binder", "Soundness.lean", "transfer_under_ext"),
    ("binder", "Soundness.lean", "uniform_and"),
    ("binder", "Soundness.lean", "uniform_exists"),
    ("binder", "Soundness.lean", "uniform_forall"),
    ("binder", "Soundness.lean", "uniform_iff"),
    ("binder", "Soundness.lean", "uniform_imp"),
    ("binder", "Soundness.lean", "uniform_not"),
    ("binder", "Soundness.lean", "uniform_or"),
    # DEC-022 comparator statement references (issue #64): consumed by the
    # comparator JSON pin lean/ComparatorChallenges/Relativization.json,
    # not dead code.
    ("binder", "Relativization.lean", "equalizing_oracle_statement"),
    ("binder", "Relativization.lean", "separating_oracle_statement"),
    # DEC-022 §3.3 paper-statement layout (issue #66): RelativizationProof
    # holds the provable barrier-consequence lemmas, consumed onward by the
    # #37/#63 assembly work — not dead code.
    ("binder", "RelativizationProof.lean", "uniform_collapse_contradicted_by_separating"),
    ("binder", "RelativizationProof.lean", "uniform_separation_contradicted_by_equalizing"),
    ("binder", "RelativizationProof.lean", "no_uniform_resolution_of_p_vs_np"),
    # Sibling #63 A2 console-oracle instances (issue #63 Pass 1): public
    # proof-work API, consumed onward by A3/A5 — not dead code.
    ("binder", "RelativizationProof.lean", "consoleOracleHead_computable"),
    # AW09 v1 statement references (issue #69 Pass 1): consumed by AZ5's
    # proof assembly — not dead code.
    ("binder", "Algebrization.lean", "algebrizing_separation_statement"),
    ("binder", "Algebrization.lean", "algebrizing_equalization_statement"),

    # Issue #41 marker-funeq campaign rendering targets: registered in
    # churn/marker-funeq/renderings/*.json (multi_render slots) and machine-
    # checked by dual_render/multi_render check; the binder scanner sees only
    # Lean declarations, not the campaign workspace.
    ("binder", "MarkerFuneqAtom.lean", "atomEqOrNe"),
    ("binder", "MarkerFuneqPointwise.lean", "pointwiseEqOrNe"),
    # Issue #81 Rung-7 Tier-1 benchmark baseline: the public membership
    # theorems of lean/PleaNP/Benchmark/Closure.lean, consumed by the
    # benchmark docs (docs/BENCHMARK.md baseline run), not dead code.
    ("binder", "Closure.lean", "emptyLang_in_UpstreamPolyTime"),
    ("binder", "Closure.lean", "univLang_in_UpstreamPolyTime"),

}
# NOTE (2026-09-13): `emptyOracle` is no longer an EXPECTED item — the
# word-query test module (OracleV5Tests.lean, issue #40) references it, so
# the binder scanner no longer reports it as unreferenced.
# `UpstreamPolyTime` (OracleComplexity.lean) is the P^∅ = P compatibility
# RHS (the function→language bridge per OracleTM2Recompose Trap 1); it is
# the anchor for #4/#40 upstream-P work, not dead code.


def _run(cmd: list[str]) -> tuple[int, str]:
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr)


def _parse_review_items(scan: str, out: str) -> list[tuple[str, str, str]]:
    """Parse [REVIEW] lines into (scanner, module-leaf, token)."""
    items = []
    for line in out.splitlines():
        m = re.search(r"\[REVIEW\]\s+\S+\s+(\S+\.lean):\d+(?::\d+)?\s+['\"]([^'\"]+)['\"]", line)
        if not m:
            m = re.search(r"\[REVIEW\]\s+(\S+)\s+\S+\.lean:\d+.*?['\"]([^'\"]+)['\"]", line)
        if m:
            module = m.group(1).split("/")[-1]
            token = m.group(2)
            items.append((scan, module, token))
    return items


def check(verbose: bool = False) -> int:
    """Run all four scans, compare REVIEW items to the register. Returns exit code."""
    scan_cmds = {
        "hygiene": [sys.executable, "tooling/gates/hygiene_scan.py", "--prove-stage", *SCAN_SET],
        "vacuity": [sys.executable, "tooling/gates/vacuity_scan.py", *SCAN_SET],
        "model": [sys.executable, "tooling/gates/model_consistency_scan.py", *SCAN_SET],
        "binder": [sys.executable, "tooling/gates/binder_usage_scan.py",
                   "--allow-unreferenced", BINDER_ALLOW, *SCAN_SET],
    }

    # 1. exit 0 (0 violations) on all four.
    for name, cmd in scan_cmds.items():
        code, out = _run(cmd)
        if code != 0:
            print(f"FAIL: scan '{name}' exit {code} (expected 0).\n{out}")
            return 1
        if verbose:
            print(f"ok: {name} scan exit 0")

    # 2. REVIEW-item set equality with the register (provenance-keyed).
    actual: set[tuple[str, str, str]] = set()
    for name in ("hygiene", "binder"):
        _, out = _run(scan_cmds[name])
        actual.update(_parse_review_items(name, out))

    # vacuity + model must not produce REVIEW items.
    for name in ("vacuity", "model"):
        _, out = _run(scan_cmds[name])
        if "[REVIEW]" in out:
            print(f"FAIL: scan '{name}' unexpectedly produced REVIEW items:\n{out}")
            return 1

    missing = EXPECTED - actual
    extra = actual - EXPECTED
    problems = False
    if missing:
        print("FAIL: register items no longer fire:")
        for m in sorted(missing):
            print(f"  {m[0]}: {m[1]} `{m[2]}`")
        problems = True
    if extra:
        print("FAIL: unexpected REVIEW items (not in the register):")
        for e in sorted(extra):
            print(f"  {e[0]}: {e[1]} `{e[2]}`")
        problems = True
    if problems:
        return 1

    if verbose:
        for item in sorted(actual):
            print(f"  register match: {item[0]} {item[1]} `{item[2]}`")
    print("gate-REVIEW register check: ok (0 violations; REVIEW set matches "
          "docs/GATE_REVIEW_NOTES.md)")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args(argv)
    return check(args.verbose)


if __name__ == "__main__":
    raise SystemExit(main())