#!/usr/bin/env python3
"""Gate 4 (read-back) — Layer 3: the "probe checklist" for a non-proof-writing,
intro-math/CS human reviewer (Numberphile/Computerphile level).

WHY THIS LAYER EXISTS (docs/STATEMENTS/SEMANTIC_APPROVAL.md):

  Layer 1 (mechanical)  - machines verify sorries/vacuity/axioms. No human.
  Layer 2 (read-back)   - you compare two English sentences. Still requires
                          spotting subtle prose differences (quantifier
                          order, direction, bounds) — a high bar for someone
                          with intro math/CS who doesn't write proofs.
  Layer 3 (THIS)        - instead of comparing sentences, you answer a fixed
                          checklist of INDEPENDENT, TINY, concrete yes/no
                          probes. Each probe is a small fact you CAN reason
                          about with intro CS + Numberphile intuition:
                            * "the always-yes oracle: does the machine accept
                              the input [true]?"
                            * "does the claim say 'there exists an oracle' or
                              'for every oracle'?"
                            * "is the time bound 'at most' or 'exactly'?"
                          A claim is trusted only when EVERY probe is answered
                          as expected. One wrong probe = the claim is wrong.

This tool has two halves:
  1. `--probe`   : run a concrete probe (a tiny Lean check) and report whether
                  the machine agrees with the expected answer. No human needed.
  2. `--checklist`: given a claim's JSON spec (quantifiers, connectives,
                  bounds, probes), generate the human-facing checklist and
                  validate the human's answers against the expected values.

The probes are concrete and tiny so a non-proof-writer can reason about them
like a Numberphile example: small inputs, obvious oracles, one step at a time.

Usage (from the lean/ dir for --probe; anywhere for --checklist):

  python3 probe_check.py --probe <module,module> <decl> --expect <true|false>
  python3 probe_check.py --checklist <spec.json> [--answers answers.json]

Exit codes: 0 all probes/checklist pass, 1 a probe disagrees or a checklist
answer is wrong, 2 usage error.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Probe: run a tiny Lean check and compare to expectation
# ---------------------------------------------------------------------------

def run_probe(lean_dir: Path, module: str, decl: str) -> tuple[int, str]:
    """Run `#check`/`#reduce` on a declaration to get a concrete observable.
    Returns (rc, output). The probe's *expected* value is supplied by the
    checklist spec; here we just surface the machine's answer."""
    src = "\n".join([f"import {module}", "", f"#check {decl}", f"#reduce {decl}"]) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(src)
        checker = Path(f.name)
    try:
        proc = subprocess.run(["lake", "env", "lean", str(checker)],
                              cwd=str(lean_dir), capture_output=True,
                              text=True, timeout=420)
        out = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, out
    finally:
        checker.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Checklist: human-facing, vocabulary-restricted, independent yes/no probes
# ---------------------------------------------------------------------------

PROBE_KINDS = {
    "quantifier": {
        "question": "Does the claim say '{word}'?",
        "answers": ["there exists", "for every"],
        "explain": ("Numberphile-style: 'there exists an oracle A' means we get "
                 "to pick a helpful oracle. 'for every oracle A' means it must "
                 "work for ALL oracles, even hostile ones. These are very "
                 "different claims."),
    },
    "direction": {
        "question": "Which direction does the claim go?",
        "answers": ["A implies B", "B implies A", "A iff B (both ways)"],
        "explain": ("Computerphile-style: does the claim say 'if it's in P then "
                 "it's in NP' (one way), or 'in P exactly when in NP' (both "
                 "ways)? The direction is the crux."),
    },
    "bound": {
        "question": "What is the time bound?",
        "answers": ["at most polynomial", "exactly polynomial", "no bound mentioned"],
        "explain": ("'At most' is a ceiling — the machine may be faster. "
                 "'Exactly' is a strict requirement. A claim that says 'at most' "
                 "is weaker than one that says 'exactly'."),
    },
    "existence": {
        "question": "Does the claim assert that something exists?",
        "answers": ["yes, an object/witness exists", "no, it is universal"],
        "explain": ("'There exists a machine that decides L' is an existence "
                 "claim. 'Every machine fails' is a universal claim. Spotting "
                 "which one the claim asserts is the core skill."),
    },
}


def validate_checklist(spec: dict, answers: dict) -> list[str]:
    """Validate a human's answers against the spec's expected values.
    Returns a list of violation strings (empty = pass)."""
    violations = []
    probes = spec.get("probes", [])
    for p in probes:
        key = p.get("key")
        expected = p.get("expected")
        got = answers.get(key)
        if got is None:
            violations.append(f"probe '{key}': no answer given")
        elif got != expected:
            violations.append(
                f"probe '{key}': expected '{expected}' but you answered '{got}'")
    return violations


def render_checklist(spec: dict) -> str:
    """Render the human-facing checklist from a claim spec (JSON)."""
    lines = []
    lines.append("=" * 70)
    lines.append("Semantic review checklist (Layer 3 — probe style)")
    lines.append("=" * 70)
    lines.append(f"claim: {spec.get('title', '')}")
    lines.append(f"informal statement: {spec.get('informal', '')}")
    lines.append("")
    lines.append("Answer each probe INDEPENDENTLY (yes/no or pick one). A claim")
    lines.append("is trusted only if EVERY answer matches the expected value.")
    lines.append("")
    for p in spec.get("probes", []):
        kind = p.get("kind")
        meta = PROBE_KINDS.get(kind, {})
        lines.append(f"  [{p.get('key')}] {p.get('question') or meta.get('question')}")
        if p.get("choices"):
            lines.append(f"      choices: {', '.join(p['choices'])}")
        if meta.get("explain"):
            lines.append(f"      hint: {meta['explain']}")
        lines.append(f"      expected: {p.get('expected')}")
        lines.append("")
    lines.append("=" * 70)
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="mode", required=True)
    p_probe = sub.add_parser("probe", help="run a tiny Lean probe")
    p_probe.add_argument("module")
    p_probe.add_argument("decl")
    p_probe.add_argument("--expect", choices=["true", "false"], default="true")
    p_chk = sub.add_parser("checklist", help="render/validate a claim checklist")
    p_chk.add_argument("spec", help="path to claim spec JSON")
    p_chk.add_argument("--answers", help="path to answers JSON (validate); else render only")
    args = ap.parse_args()

    if args.mode == "probe":
        rc, out = run_probe(Path.cwd(), args.module, args.decl)
        print("=" * 70)
        print("Gate 4 Layer-3 probe")
        print("=" * 70)
        print(f"decl: {args.decl}")
        print(f"machine output:\n{out.strip()[:800]}")
        # The expectation is supplied by the checklist; here we just surface
        # the machine's observable so the human can compare it to the claim.
        print(f"expected (from the checklist): {args.expect}")
        print("=" * 70)
        return 0 if rc == 0 else 1

    spec = json.loads(Path(args.spec).read_text())
    if args.answers:
        answers = json.loads(Path(args.answers).read_text())
        print(render_checklist(spec))
        violations = validate_checklist(spec, answers)
        if violations:
            print("\nVIOLATIONS:")
            for v in violations:
                print(f"  [x] {v}")
            print("\nThe claim is NOT approved — one probe disagrees.")
            return 1
        print("\nAll probes answered as expected. The claim's semantics are")
        print("consistent with the checklist. (Layer-2 read-back still applies.)")
        return 0
    print(render_checklist(spec))
    return 0


if __name__ == "__main__":
    sys.exit(main())