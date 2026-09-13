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
    "lean/PleaNP/ProofComplexity/Resolution.lean "
    "lean/PleaNP/Barriers/RelativizationProof.lean "
    "lean/PleaNP/Barriers/Algebrization.lean "
    "lean/PleaNP/Barriers/AlgebrizationProof.lean "
    "lean/PleaNP/Circuits/Basic.lean "
    "lean/PleaNP/Circuits/AC0.lean "
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
    ("hygiene", "Basic.lean", "by decide"),  # Nat.one_le_pow discharge in univ_largeness
    ("binder", "BarrierVerdictB.lean", "abstractPVsNP_iff_verdictB"),
    ("binder", "OracleComplexity.lean", "y"),             # weak witness ∃ y
    ("binder", "OracleComplexity.lean", "UpstreamPolyTime"),  # P^∅ = P anchor RHS
    # NOTE: P_A_subset_NP_A is NOT in the register anymore — #63 Pass 3's
    # P_subset_NP_console references it, so the binder stops flagging it.
    # Rung-5 soundness lemma API (issue #65): library-level uniformity
    # lemmas, intentional public API for downstream proofs (see
    # docs/GATE_REVIEW_NOTES.md §3).
    ("binder", "Soundness.lean", "funeq_uniform"),
    ("binder", "Soundness.lean", "funne_uniform"),
    ("binder", "Soundness.lean", "relAtom_uniform"),
    # NOTE: Soundness.pA_mem_uniform is NOT in the register anymore — #73
    # Pass 1's Classification.classification_uniform references it.
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
    # Rung-4 barrier-classification method (issue #73 Pass 1): the
    # classification spine + A3 method demo — intentional public API for the
    # per-family classification instances (#72/#74/#75/#76).
    ("binder", "Classification.lean", "classification_uniform"),
    ("binder", "Classification.lean", "oneQuery_classification_uniform"),
    # BGS clause-(a) proof-work API (issues #63/#62): the console-oracle +
    # one-query-machine lemmas beyond the §3.3 barrier-consequence set above,
    # intentional public API for the A3/A5 assembly (GATE_REVIEW_NOTES.md §4).
    ("binder", "RelativizationProof.lean", "consoleOracleHead_computable"),
    ("binder", "RelativizationProof.lean", "consoleLang_mem_P_false"),
    ("binder", "RelativizationProof.lean", "P_subset_NP_console"),
    # DEC-022 §3.3 paper-statement layout (issue #66): RelativizationProof
    # holds the provable barrier-consequence lemmas, consumed onward by the
    # #37/#63 assembly work — not dead code.
    ("binder", "RelativizationProof.lean", "no_uniform_resolution_of_p_vs_np"),
    # Sibling #63 A2 console-oracle instances (issue #63 Pass 1): public
    # proof-work API, consumed onward by A3/A5 — not dead code.
    ("binder", "RelativizationProof.lean", "consoleOracleHead_computable"),
    # AW09 AZ3 barrier-consequence lemmas (issue #69 Pass 2): the
    # algebrizing-uniformity incompatibility theorems of
    # lean/PleaNP/Barriers/AlgebrizationProof.lean. The joint
    # `no_algebrizing_uniform_resolution` is the module's public API
    # (the asymmetric-access counterpart of the RelativizationProof
    # barrier-consequence set). The per-direction lemmas are the joint
    # theorem's components (the binder stops flagging them once the
    # module is in the scan set).
    ("binder", "AlgebrizationProof.lean", "no_algebrizing_uniform_resolution"),
    # Rung-4 circuit substrate API (issue #71 Pass 1): the typed
    # circuit-family foundation consumed by Pass 2/3 and all Rung-4
    # lower bounds — not dead code.
    ("binder", "Basic.lean", "size_pos"),
    ("binder", "Basic.lean", "depth_size_le"),
    ("binder", "Basic.lean", "IsPPoly"),
    ("binder", "Basic.lean", "NaturalProperty"),
    ("binder", "Basic.lean", "univ_largeness"),
    ("binder", "Basic.lean", "CircuitFamily.depthOf"),

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
    # Issue #72 Pass 1: the AC⁰ milestone's public API (AC0.lean) — the
    # frozen parity_notin_AC0 statement (consumed by Pass 2 + Gate 4
    # read-back) and the structural parity facts (parity_zero, parity_
    # nontrivial) that give the statement content. Demonstrated-intentional.
    ("binder", "AC0.lean", "parity_notin_AC0"),
    ("binder", "AC0.lean", "parity_zero"),
    ("binder", "AC0.lean", "parity_nontrivial"),
    # Issue #75 Pass 1: the resolution substrate API (Resolution.lean) —
    # `eval` is referenced internally by Clause.eval but the scanner resolves
    # only top-level name references; `Clause.empty`, `CNF.width`,
    # `ResDerivation.size/.width` are the public substrate measures;
    # `ResDerivation.sound` is the headline soundness theorem; `simp` is a
    # `@[simp]`-attribute misread (binder). All demonstrated-intentional,
    # consumed by Pass 2 (pigeonhole width bound). (`var` is no longer an
    # EXPECTED item — the rewritten Clause.eval exposes the reference, so the
    # scanner resolves it.)
    ("binder", "Resolution.lean", "simp"),
    ("binder", "Resolution.lean", "eval"),
    ("binder", "Resolution.lean", "Clause.empty"),
    ("binder", "Resolution.lean", "CNF.width"),
    ("binder", "Resolution.lean", "ResDerivation.width"),
    ("binder", "Resolution.lean", "ResDerivation.sound"),

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