# Validation suite requirements (spec template section)

**Purpose.** A definition is only as good as the strongest false thing it excludes. Every definitional module must ship with executable evidence of what it rules out, not just what it permits. This document specifies the validation requirements that must be met before any definition reaches "frozen" status.

**Status:** Active (adopted 2026-08-18, per the harsh review).

---

## The three validation requirements

Every definition file (e.g., `Oracle.lean`, `OracleComplexity.lean`) must ship a validation suite with three categories of evidence before it can be frozen:

### 1. Must-prove lemmas

Known facts the informal theory guarantees. For oracle-machine classes:

- **P^A ⊆ NP^A** — the trivial inclusion (a decider is a verifier with empty certificate)
- **P^A = coP^A** — closure under complement (for deterministic classes)
- **P^∅ reduces to non-oracle poly-time** — the model-consistency anchor
- **Closure of NP^A under poly reductions** — if L reduces to L' and L' ∈ NP^A, then L ∈ NP^A
- **Robustness to encoding tweaks** — the class doesn't change under reasonable encoding variations

These are the structural self-checks. If any can't be proven from the definitions, the definitions are wrong. This is how TCS validates relativized definitions in the literature.

### 2. Must-refute lemmas

At least one proof that something concrete is excluded. The killer instance for machine-defined classes is **countability**: poly-time oracle machines have finite descriptions, so `P_A A` is countable, while `Set (List Bool)` is uncountable — hence `P_A A ≠ univ`. That single lemma would have killed Flaw A outright (the degenerate `P_A` equals `univ`).

Standard must-refute boilerplate for every machine-based class:
- **The class is countable / non-universal** — `P_A A ≠ Set α` (there exist undecidable languages)
- **The class depends on the oracle** — `∃ A B, P_A A ≠ P_A B` (different oracles give different classes — this would have killed Flaw B)

### 3. Smoke tests by evaluation

Concrete machines with decided accept/reject behaviors. `FinTM2` machines are executable. A two-state machine that queries the oracle and halts with the answer can be tested in CI against `fun _ => true` vs `fun _ => false` and must produce different outputs. That catches Flaw B in minutes.

Every machine-model module should ship ≥3 concrete machines with decided accept/reject behaviors:
- A machine that queries the oracle and accepts iff the oracle says true
- A machine that never queries (plain poly-time — P^∅ member)
- A machine that queries twice and accepts iff both answers agree

---

## Status ladder (dependency-ordered freezing)

Definitions progress through an explicit status ladder:

1. **Typed** — the file compiles (`lake build` succeeds). Parameters may be unused; bodies may be sorry'd.
2. **Validated** — the validation suite compiles: must-prove lemmas are proven (not sorry'd), must-refute lemmas are proven, smoke tests pass. Every parameter is load-bearing (binder_usage_scan.py clean).
3. **Frozen** — the definition is the canonical anchor. Proof search may run against it. Requires: validated + Gates 2/4/5/6 passed + human review.

**The word "anchor" is forbidden for anything below frozen.** A typed-but-unvalidated definition is scaffolding, not an anchor.

---

## Red-team pass on definitions

Before proving theorems from a new definition, a separate agent or human must try to prove the absurdities it must exclude:
- `∀ L, DecidesInTime ... L ...` (everything is decidable — Flaw A)
- Oracle-independence of behavior (Flaw B)
- `NP_A A ⊆ P_A A` (Flaw C — nondeterminism is trivial)

Success = the definition is broken. This is Gate 3's independence principle generalized from statements to definitions.

---

## Granularity rule

Never reuse a whole-language predicate where a per-input predicate is needed. The NP^A definition must use a per-input `AcceptsInTime M (x, y) t` — not `DecidesInTime` (which ∀-quantifies over all inputs) inside `∃ y`. This is the Flaw C shape; the spec template must flag it.

---

## CI staging

- **Render-stage scanning**: during development, `sorry`s are tracked (Gate 6 flags them) but don't fail the build. The hygiene scanner runs without `--prove-stage`.
- **Prove-stage scanning**: on freeze PRs (when a definition moves to "frozen" status), `sorry`s are violations — `--prove-stage` is used, and the build must be green.

This prevents the self-defeating pattern where `warningAsError` + `sorry` = CI always red.
