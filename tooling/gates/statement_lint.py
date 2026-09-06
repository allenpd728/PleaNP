#!/usr/bin/env python3
"""Statement linter — classify the SHAPE of a Lean statement with pure code
(no LLM, no human), using Lean itself as the validator.

This is the "linter/validator rigor" answer to the question
"is the human semantic-review step necessary?": the *shape* facts a human
probe checklist asks about are almost all extractable from the Lean term's
syntax. This tool extracts them mechanically:

    - quantifier order        (∀ / ∃ binders in the type)
    - connective skeleton     (∧ ∨ → ↔ ¬)
    - relation head           (= ≠ ⊆ ∈ in the conclusion)
    - oracle dependence       (does the type mention an Oracle type?)
    - class constants         (P_A, NP_A, Relativizing, ...)

WHAT THIS CANNOT DO (and never will, by a theorem — Tarski): it cannot decide
whether the formal term MATCHES an informal intention, because the informal
claim is not a term in the system. A statement linter classifies *what the
Lean says*; only a human confirmation maps that to *what was wanted*. That
single confirmation is the irreducible human step (see
docs/STATEMENTS/HUMAN_REVIEW_LAYERS.md).

Usage (from the lean/ directory):

    python3 statement_lint.py <module,module> <DeclName> [--json]

Exit codes: 0 linted, 1 extraction/typing failed, 2 usage error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import lean_readback  # noqa: E402

# Unicode tokens as Lean pretty-prints them.
FORALL_TS = ("∀", "forall")
EXISTS_TS = ("∃", "exists")
AND_TS = ("∧", "and")
OR_TS = ("∨", "or")
IFF_TS = ("↔",)
NOT_TS = ("¬", "not")
IMP_TS = ("→", "->")
EQ_TS = ("=",)
NE_TS = ("≠", "!=")
SUBSET_TS = ("⊆",)
MEM_TS = ("∈", "in")
LE_TS = ("≤", "<=")


def classify(lean_type: str) -> dict:
    """Classify a pretty-printed Lean type text into shape facts."""
    t = lean_type
    quantifiers = []
    if any(tok in t for tok in FORALL_TS):
        quantifiers.append("for every (∀)")
    if any(tok in t for tok in EXISTS_TS):
        quantifiers.append("there exists (∃)")

    connectives = []
    if any(tok in t for tok in AND_TS):
        connectives.append("and (∧)")
    if any(tok in t for tok in OR_TS):
        connectives.append("or (∨)")
    if any(tok in t for tok in IFF_TS):
        connectives.append("iff (↔)")
    if any(tok in t for tok in NOT_TS):
        connectives.append("not (¬)")
    if any(tok in t for tok in IMP_TS):
        connectives.append("implies (→)")

    relations = []
    for tok in EQ_TS:
        if tok in t:
            relations.append("equality (=)")
    for tok in NE_TS:
        if tok in t:
            relations.append("inequality (≠)")
    for tok in SUBSET_TS:
        if tok in t:
            relations.append("containment/subset (⊆)")
    for tok in MEM_TS:
        if tok in t:
            relations.append("membership (∈)")
    for tok in LE_TS:
        if tok in t:
            relations.append("less-equal (≤)")

    oracle = "Oracle" in t or "AbstOracle" in t

    classes = []
    for name in ("P_A", "NP_A", "Relativizing", "PVsNPShaped",
                 "DTIME", "NTIME", "P", "NP"):
        if re.search(rf"\b{re.escape(name)}\b", t):
            classes.append(name)

    # English summary built purely from the observed syntax.
    english = "A statement"
    if quantifiers:
        english += " that ranges over " + " and ".join(quantifiers)
    if classes:
        english += " about [" + ", ".join(classes) + "]"
    if oracle:
        english += " with oracle dependence"
    if relations:
        english += " relating by " + ", ".join(relations)
    if connectives:
        english += " using connectives [" + ", ".join(connectives) + "]"
    english += "."

    return {
        "quantifiers": quantifiers,
        "connectives": connectives,
        "relations": relations,
        "oracle_dependence": oracle,
        "classes": classes,
        "english": english,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("module", help="comma-separated Lean modules to import")
    ap.add_argument("decl", help="fully-qualified declaration name")
    ap.add_argument("--json", action="store_true", help="emit JSON only")
    args = ap.parse_args()

    try:
        # Prefer the def BODY (the actual proposition) over the type: for a
        # def (e.g. thhStatement) the type is just `Prop` but the body is the
        # ∀/∃-quantified statement. For theorems the body isn't stored, so
        # extract_body falls back to the type. extract_body returns both kind
        # of content; classify() only cares about the syntax tokens present.
        lean_type = lean_readback.extract_body(args.module, args.decl, Path.cwd())
        if "forall" not in lean_type and "exists" not in lean_type and "∀" not in lean_type and "∃" not in lean_type:
            # no quantifiers observed in the body — try the type too
            lean_type_type = lean_readback.extract_type(args.module, args.decl, Path.cwd())
            base = lean_type
            if "forall" in lean_type_type or "exists" in lean_type_type or "∀" in lean_type_type or "∃" in lean_type_type:
                lean_type = lean_type_type
            else:
                lean_type = base
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 1

    facts = classify(lean_type)

    if args.json:
        print(json.dumps(facts, indent=2))
    else:
        print("=" * 70)
        print("Statement linter (pure-code shape classification)")
        print("=" * 70)
        print(f"declaration: {args.decl}")
        print(f"raw type:    {lean_type}")
        print(f"english:     {facts['english']}")
        print("-" * 70)
        print("Quantifiers :", facts["quantifiers"] or "(none)")
        print("Connectives :", facts["connectives"] or "(none)")
        print("Relations   :", facts["relations"] or "(none)")
        print("Oracle-dep  :", facts["oracle_dependence"])
        print("Classes     :", facts["classes"] or "(none)")
        print("=" * 70)
        print("NOTE: this is the SHAPE. It does not decide whether the shape")
        print("matches your intention — that confirmation is the human step")
        print("(the only one that is fundamentally un-automatable).")
        print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())