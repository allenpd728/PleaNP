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
- `∀ L, DecidesInTime . L .` (everything is decidable — Flaw A)
- Oracle-independence of behavior (Flaw B)
- `NP_A A ⊆ P_A A` (Flaw C — nondeterminism is trivial)

Success = the definition is broken. This is Gate 3's independence principle generalized from statements to definitions.

---

## Load-bearing-choice audit (creativity-honesty gate, DEC-023)

**Purpose.** A proof can compile,pass the vacuity scan,and still be *creatively dishonest* if a *choice*(a parameter,a hypothesis,an encoding,an oracle,a force-like datum)carries the conclusion rather than an *internal mechanism*. This extends the binder-lethality discipline( `binder_usage_scan.py`: every parameter,binder,and declaration must be load-bearing)** from *definitions* to *proofs*. It is the "chosen-to-work" detector -- the authority mechanism the no-sorry/no-vacuity gates cannot see(see `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §3/§4,and the template `docs/STATEMENTS/ProofIntuition.template.md` §3.



**Requirement.** Every claimed barrier/lower-bound proof whose construction involves substantive *choices*(oracles, machine-enumeration orderings, encodings, perturbation scales, viscosity-like parameters, force-like data — anything the theorem's conclusion is sensitive to)must ship,with its proof-intuition record,an audit of which choices do the work;

- For each choice:what it is,which clause of the conclusion it carries,**internal mechanism or choice-bought?**,and the **perturbation test**(if you perturb this choice slightly,does the construction surviveand the claim with it)?
- The standard to meet(find the calibration:**"internal mechanism, externally-perturbable"** —the vortex/cascade phenomenon was robust even though the exact theorem needed fine tuning).A construction whose conclusion is *bought* by an exact,un-perturbable choice has thee same geometry as a post-hoc-selected Navier–Stokes force:it is non-vacuous-in-shape but not authoritative — and must be flagged,and reviewed harder,not silently accepted.



**Success / failure:**
- **Pass:** every load-bearing choice is backed by an internal mechanism that survives perturbation(test it;record the results inthe intuition record).
- **Fail:** a load-bearing choice with no mechanism(conclusion sensitive to an exact choice),or the flight-to-cheap-outs pattern(any §4-class move of `docs/STATEMENTS/ProofIntuition.template.md` actually doing work in disguise).Then the claim is**not authoritative-ready** — it stays "formally checked but not yet human-legible"until they mechanism is found or the construction is redesigned.



## Granularity rule

Never reuse a whole-language predicate where a per-input predicate is needed. The NP^A definition must use a per-input `AcceptsInTime M (x, y) t` — not `DecidesInTime` (which ∀-quantifies over all inputs) inside `∃ y`. This is the Flaw C shape; the spec template must flag it.

---

## CI staging

- **Render-stage scanning**: during development, `sorry`s are tracked (Gate 6 flags them) but don't fail the build. The hygiene scanner runs without `--prove-stage`.
- **Prove-stage scanning**: on freeze PRs (when a definition moves to "frozen" status), `sorry`s are violations — `--prove-stage` is used, and the build must be green.

This prevents the self-defeating pattern where `warningAsError` + `sorry` = CI always red.
