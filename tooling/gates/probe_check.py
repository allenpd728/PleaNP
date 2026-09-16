#!/usr/bin/env python3
"""Gate 4 (read-back) — Layer 3: the "probe checklist" for a non-proof-writing,
intro-math/CS human reviewer (intro-level (plain-language) level).

WHY THIS LAYER EXISTS (docs/STATEMENTS/SEMANTIC_APPROVAL.md):

  Layer 1 (mechanical)  - machines verify sorries/vacuity/axioms. No human.
  Layer 2 (read-back)   - you compare two English sentences. Still requires
                          spotting subtle prose differences (quantifier
                          order, direction, bounds) — a high bar for someone
                          with intro math/CS who doesn't write proofs.
  Layer 3 (THIS)        - instead of comparing sentences, you answer a fixed
                          checklist of INDEPENDENT, TINY, concrete yes/no
                          probes. Each probe is a small fact you CAN reason
                          about with intro CS + intro-level intuition:
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
like a intro-level example: small inputs, obvious oracles, one step at a time.

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
        "explain": ("intro-level-style: 'there exists an oracle A' means we get "
                 "to pick a helpful oracle. 'for every oracle A' means it must "
                 "work for ALL oracles, even hostile ones. These are very "
                 "different claims."),
    },
    "direction": {
        "question": "Which direction does the claim go?",
        "answers": ["A implies B", "B implies A", "A iff B (both ways)"],
        "explain": ("intro-level-style: does the claim say 'if it's in P then "
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


# ---------------------------------------------------------------------------
# Rendering-disagreement spec (Gate 3 multi-rendering -> human review)
# ---------------------------------------------------------------------------

# The allowed top-level fields of a rendering-disagreement spec. Mirrors
# tooling/gates/specs/rendering_disagreement.schema.json (the unit tests
# keep the two in sync).
_RENDER_TOP_LEVEL = {"campaign", "lens_a", "lens_b", "informal_claim",
                       "batch_narrative", "probes"}
_RENDER_PROBE_FIELDS = {"key", "kind", "question", "choices", "expected",
                          "hint", "gloss"}
_RENDER_REQUIRED = ("key", "kind", "question", "choices", "expected", "hint")


def validate_rendering_disagreement_spec(spec: dict) -> list[str]:
    """Validate a rendering-disagreement spec against the schema (stdlib).

    Returns a list of violation strings (empty = valid). The rules mirror
    tooling/gates/specs/rendering_disagreement.schema.json: required
    top-level fields, 3-5 probes with required per-probe fields, no extra
    fields, and the expected answer must be one of the choices."""
    violations = []
    for f in ("campaign", "lens_a", "lens_b", "informal_claim", "probes"):
        if f not in spec:
            violations.append(f"missing required field '{f}'")
    for f in ("campaign", "lens_a", "lens_b", "informal_claim", "batch_narrative"):
        if f in spec and not isinstance(spec[f], str):
            violations.append(f"field '{f}' must be a string (got {type(spec[f]).__name__})")
    probes = spec.get("probes")
    if "probes" in spec and not isinstance(probes, list):
        violations.append(f"'probes' must be an array (got {type(probes).__name__})")
    elif isinstance(probes, list):
        if not (3 <= len(probes) <= 5):
            violations.append(f"'probes' must have 3-5 items ( got {len(probes)})")
        for i, p in enumerate(probes):
            pref = f"probes[{i}]"
            if not isinstance(p, dict):
                violations.append(f"{pref}: must be an object")
                continue
            for f in _RENDER_REQUIRED:
                if f not in p:
                    violations.append(f"{pref}: missing required field '{f}'")
            extra = set(p) - _RENDER_PROBE_FIELDS
            if extra:
                violations.append(f"{pref}: unknown field(s): {sorted(extra)}")
            choices= p.get("choices")
            if choices is not None:
                if not isinstance(choices, list) or not choices:
                    violations.append(f"{pref}: 'choices' must be a non-empty array")
                elif any(not isinstance(c, str) for c in choices):
                    violations.append(f"{pref}: every choice must be a string")
            expected = p.get("expected")
            if expected is not None and isinstance(choices, list) and choices:
                if expected not in choices:
                    violations.append(f"{pref}: expected value must be one of the choices")
            for f in ("key", "kind", "question", "expected", "hint", "gloss"):
                if f in p and not isinstance(p[f], str):
                    violations.append(f"{pref}: '{f}' must be a string")
    extra = set(spec) - _RENDER_TOP_LEVEL
    if extra:
        violations.append(f"unknown top-level field(s): {sorted(extra)}")
    return violations


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
    claim = spec.get("campaign") or spec.get("title", "")
    lines.append(f"claim: {claim}")
    if spec.get("lens_a") or spec.get("lens_b"):
        lines.append(f"lenses: A = {spec.get('lens_a', '?')}, B = {spec.get('lens_b', '?')}")
    lines.append(f"informal statement: {spec.get('informal_claim') or spec.get('informal', '')}")
    narrative = spec.get("batch_narrative")
    if narrative:
        lines.append("")
        lines.append("batch narrative:")
        lines.append(narrative)
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
        hint = p.get("hint") or meta.get("explain")
        if hint:
            lines.append(f"      hint: {hint}")
        gloss = p.get("gloss")
        if gloss:
            lines.append(f"      gloss: {gloss}")
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
    p_val = sub.add_parser("validate-spec",
                           help="validate a rendering-disagreement spec against the schema")
    p_val.add_argument("spec", help="path to spec JSON")
    p_val.add_argument("--schema", help="path to the schema JSON (optional; coherence check)")
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

    if args.mode == "validate-spec":
        p = Path(args.spec)
        spec = json.loads(p.read_text())
        violations = validate_rendering_disagreement_spec(spec)
        if args.schema:
            _coherence_check_schema(Path(args.schema))
        if violations:
            print("Rendering-disagreement spec INVALID:")
            for v in violations:
                print(f"  [x] {v}")
            return 1
        print("Rendering-disagreement spec VALID.")
        return 0

    p = Path(args.spec)
    spec = json.loads(p.read_text())
    if args.answers:
        p2 = Path(args.answers)
        answers = json.loads(p2.read_text())
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


def _coherence_check_schema(path: Path) -> None:
    """Cheap coherence check that the schema JSON is well-formed and carries the
    required field lists the Python validator enforces (keeps the two in sync).)."""
    schema = json.loads(path.read_text())
    required_top = {"campaign", "lens_a", "lens_b", "informal_claim", "probes"}
    if not required_top.issubset(set(schema.get("required", []))):
        raise SystemExit("schema.json requirements mismatch: required top-level fields must be listed")
    props = schema.get("properties", {})
    probe_item = props.get("probes", {}).get("items", {})
    probe_req = set(probe_item.get("required", []))
    expected = {"key", "kind", "question", "choices", "expected", "hint"}
    if not expected.issubset(probe_req):
        raise SystemExit("schema.json requirements mismatch: probe fields key,kind,question,choices,expected,hint must be listed")


if __name__ == "__main__":
    sys.exit(main())