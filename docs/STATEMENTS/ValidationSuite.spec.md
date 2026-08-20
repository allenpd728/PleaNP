# Spec: the validation suite (definitional-layer integrity)

**Status:** DRAFT (independent authoring track A, 2026-08-19). A second agent may draft this section independently; reconcile the two before adopting into the six-part template (Gate-3-style dual authoring applied to the process itself). Adoption requires a DEC entry and edits to `docs/STATEMENTS/README.md` (the template index) — deliberately not made here to avoid colliding with track B.

**Scope:** A required new section for every *definitional* spec (Oracle.lean, OracleComplexity.lean, future Circuits/ProofComplexity/PSPACE substrates) — the layer where there is no canonical upstream definition for Gate 2 to reference, because PleaNP is filling the gap itself.

---

## 1. Why this section exists

The 2026-08-19 review of the first rendered definitions found three failures that every existing gate missed:

| Flaw | Shape | Why the gates missed it |
|---|---|---|
| `DecidesInTime` never uses `t`, `ea`, `M` | definition constant in its constraining parameters | no sorry, no `:= True`, no axiom — Gates 5/6 Tier 1 look for dishonesty, not wrongness |
| `step` never consults the oracle; `oracleQuery` discards the answer and is never called | influence specified but never wired | the vacuity scanner's `:= none` pattern doesn't cover "computes and discards" |
| `NP_A`'s `∃ y` certificate binds nothing (whole-language predicate under the witness quantifier) | wrong predicate granularity | Gate 4 (read-back) is unimplemented; nothing else examines quantifier structure |

All three are **definitional** failures. The gate pipeline polices statements and proofs; it had no check that a *definition* constrains what it claims to constrain. A perfectly frozen, fidelity-checked, sorry-free theorem proved against a degenerate definition passes every gate and means nothing.

**Principle:** a definition is only as good as the strongest false thing it excludes. Every definitional module must ship with executable evidence of what it rules out, not just what it permits.

---

## 2. The three required components

Every definitional spec must include a **Validation suite** subsection with all three components (or an explicit, justified exemption). The suite is Lean code that must compile with zero `sorry` before the module's status may advance past *typed* (§4).

### 2.1 Must-prove lemmas (sanity facts)

Known facts the informal theory guarantees about the defined objects. For oracle-complexity classes, the standard "relativized sanity suite":

- `P^A ⊆ NP^A` (already spec §2.3 of OracleComplexity.lean.spec — this generalizes it)
- `P^A = coP^A` (deterministic classes are complement-closed)
- `NP^A` closed under polynomial-time many-one reductions
- `P^∅` reduces to the non-oracle class (the Trap-4 carry-through, promoted from statement to *proved* for a concrete non-oracle substrate)

The informal literature is the acceptance criterion: if a fact is textbook-true of the informal objects and unprovable of the formal ones, the formalization is wrong.

### 2.2 Must-refute lemmas (exclusion evidence)

At least one proof that something concrete is *excluded* — the component whose absence let the 2026-08-19 flaws survive:

- **Countability boilerplate (mandatory for machine-defined classes).** Poly-time machines have finite descriptions, so any class defined by quantifying over them is countable: `Countable (P_A A)`, hence `P_A A ≠ Set.univ` (languages over `List Bool` are uncountable). With the degenerate `DecidesInTime`, `P_A A = univ` and this lemma is **false** — it alone detects Flaw A.
- **Per-predicate falsifiability.** For each decision-style predicate, exhibit a concrete negative instance: e.g. a machine `M`, language `L`, and bound `t` with `¬ DecidesInTime ea oa M L t` (a machine that rejects, or runs too long). A predicate that cannot be made false is not a definition of decision.

### 2.3 Executable smoke tests (when the substrate is computable)

FinTM2 machines are executable; `EvalsToInTime` over a computable step function is decidable for concrete instances. Where this holds, the suite must include:

- **≥3 concrete machines** with `decide`d accept/reject behavior on concrete inputs (committed as `example`s closed by `decide` or `native_decide`, so CI runs them).
- **Oracle-sensitivity test (mandatory for oracle machines).** One concrete machine `M`, two oracles `A₁ ≠ A₂`, one input `x`: `Accepts M A₁ x ∧ ¬ Accepts M A₂ x`, closed by `decide`. With the inert `step`/`oracleQuery`, this is unprovable — it detects Flaw B directly.

Where the substrate is not computable (classes quantify over all machines), smoke tests are replaced by additional must-prove/must-refute lemmas; the exemption must be justified in the spec.

---

## 3. The granularity rule (spec-authoring rule)

Never reuse a whole-language predicate where a per-input predicate is needed (the Flaw C shape). If a definition needs "M accepts input `u` within `t` steps" (`AcceptsInTime M u t : Prop`), that predicate is a **separate required deliverable** of the spec; the whole-language version (`DecidesInTime M L t`) is derived from it, not the other way around. The verifier framing of `NP^A` must be built on the per-input predicate so the certificate quantifier has something to constrain.

---

## 4. The status ladder (replaces the single "rendered" state)

| Status | Meaning | May be called a Gate-1 anchor? |
|---|---|---|
| **Typed** | the module compiles; placeholders honest (Gate 6) | No |
| **Validated** | the validation suite (§2) compiles, zero `sorry`; the Tier 1b binder-usage scan (`tooling/gates/binder_usage_scan.py`) is clean of violations | No |
| **Frozen** | validated + Gates 2/3/4 passed (model-consistency, independent second formalization, read-back) | Yes |

Rules:

1. **Dependency-ordered freezing.** A statement may reach *frozen* only when every definition it references is *validated*. The BGS statement was declared "a valid Gate-1 frozen anchor" while its class definitions were unvalidated — exactly the conflation this ladder forbids.
2. **Honest-sorry rule.** `docs/SORRY_TRACKER.md` may record a `sorry` as "honest pending proof" only if the definitions it references are validated. A `sorry` over an unvalidated definition is not "honest" — it may be resting on a false statement (three of the first seven were).
3. **Suite regressions block status.** If a later edit breaks a suite lemma, the module drops to *typed* until the suite compiles again. Suites are CI artifacts, not documentation.

---

## 5. The red-team pass (Gate 3, generalized to definitions)

Before a definition is *validated*, an agent or human **independent of the definition's author** must attempt to prove the degenerate forms the definition exists to exclude:

- `∀ L t, DecidesInTime ea oa M L t` (is the predicate trivially true?)
- `∀ A₁ A₂, Behavior M A₁ = Behavior M A₂` (is the oracle inert?)
- `NP_A A ⊆ P_A A` (does the certificate collapse the classes?)

A successful degenerate proof means the definition is broken — file it as a spec violation, not a result. This is Gate 3's independence principle applied one layer down: for self-built substrate there is no upstream reference, so independence must come from an adversarial second party, not from import.

---

## 6. Gate mapping

| Gate | Relationship |
|---|---|
| 2 (model-consistency) | For self-built substrate there is no canonical model to match; the validation suite *is* the substitute reference |
| 3 (statement-fidelity) | Generalized to definitions via the red-team pass (§5) |
| 4 (read-back) | Read-back remains required at freeze; the suite catches what read-back misses between render and freeze |
| 5 (non-triviality) | This spec is Gate 5's definitional layer: Tier 1b scanner (`binder_usage_scan.py`) + the suite's must-refute lemmas |
| 6 (hygiene) | Unchanged; the suite itself must be `sorry`-free at prove-stage |

---

## 7. What this spec does NOT do

- Does not replace Gates 1–4; it closes the gap *below* them (definitions) that the 2026-08-19 review exposed.
- Does not require the suite at statement-render time — only before *validated* status. Rendering with honest placeholders remains allowed.
- Does not prescribe the suite for the three barrier *statement* specs (Relativization.md etc.) — those quantify over definitions; the suite applies to the definitional specs those statements import.
- Does not wire CI. CI wiring (Tier 1b scan + suite build) is a separate change, to be reconciled with track B and recorded in a DEC entry.

---

## 8. Worked example: the suite that would have caught the 2026-08-19 flaws

| Flaw | Suite component that detects it |
|---|---|
| `DecidesInTime` constant in `t`/`ea`/`M` | §2.2 countability (`P_A A ≠ univ` is false under the degenerate definition) + §2.2 negative instance + Tier 1b `unused_param` |
| Oracle inert in `step`; `oracleQuery` discards answer | §2.3 oracle-sensitivity smoke test + Tier 1b `discarded_let` / `unreferenced_decl` |
| `NP_A` certificate vacuous | §3 granularity rule (spec would have required `AcceptsInTime` per-input) + §5 red-team (`NP_A ⊆ P_A` provable) + Tier 1b `weakly_constrained_witness` |
| `P_A`/`NP_A` never constrain `M.oracle = A` | §2.1 (`P^∅ = P` carry-through provable for the wrong reason / sensitivity suite) + Tier 1b `unused_param` on `A` |
