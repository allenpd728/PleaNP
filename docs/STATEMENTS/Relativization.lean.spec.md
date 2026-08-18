# Spec: `Relativization.lean` (the BGS statement rendering)

**Rung:** 3a — the Lean rendering of the Baker–Gill–Solovay theorem statement into `lean/PleaNP/Barriers/Relativization.lean`. This is the Gate-1 frozen statement (the formal Lean anchor), rendered against `P^A`/`NP^A` from `OracleComplexity.lean`.
**Status:** Spec — the frozen target for the local agent. The actual Lean rendering is the local agent's job (`lake build` validation required, per DEC-007). This document contains **no Lean code** — only the logical shape, the acceptance criteria, and the traps specific to rendering *this* statement. A separate trust boundary from the proof work, per `docs/ARCHITECTURE.md`.

**Dependency:** This file renders the *statement* (not the proof). It depends on `OracleComplexity.lean` being frozen (i.e. `P^A`/`NP^A` defined as real types). It does NOT depend on upstream `P`/`NP` for the *statement* — the statement quantifies over oracle-relative classes, which are PleaNP-local. (The *proof* depends on upstream `P`/`NP` + PSPACE, but that's Rung 3 proof work, gated behind this statement being frozen.)

**What this spec is *not*:** it is not the informal statement (`Relativization.md` — the human-verified informal spec), not the proof strategy (`Relativization.proof-strategy.md` — the informal proof outline), and not the proof (Rung 3, Step 6). It is the *rendering* spec — the design doc that tells the local agent how to write the Lean `theorem` declarations, what to watch out for, and what the gates check.

---

## 1. The two theorems to render

Per `Relativization.md` §3 (the frozen informal statement), the BGS theorem has two existence clauses. Each becomes a `theorem` (or `example`/`def`-witness) in `Relativization.lean`:

### Clause (a) — the equalizing oracle
**Logical shape:** There exists a total, computable oracle `A` such that `P^A = NP^A`.

### Clause (b) — the separating oracle
**Logical shape:** There exists a total, computable oracle `B` such that `P^B ≠ NP^B`.

**At the rendering stage (Step 1 of the workflow):** each theorem is rendered with `:= by sorry` as the proof placeholder. The *statement* is what's being frozen; the proof is Rung 3 work (Step 6). Gate 6 allows the `sorry` in render-stage; it becomes a violation only when the proof is claimed complete.

---

## 2. The acceptance criteria (what the rendering must encode)

These are the constraints from `Relativization.md` §3, translated into rendering-level acceptance criteria:

1. **The oracle is existential and total.** The `A`/`B` is `∃ A : Oracle Q, ...` — the oracle type from `Oracle.lean` (`Oracle Q := Q → Bool`), which is total by construction. The rendering must NOT quantify over partial oracles (e.g. `Part Bool`-valued) — that's a different (and in clause (a)'s case trivial) theorem. Gate 2 checks the oracle type is `PleaNP.Oracles.Oracle`.

2. **The oracle is recursive (computable).** Both witnesses must be computable — `∃ A : Oracle Q, (hA : Computable A) ∧ ...` or equivalent. The recursiveness is a *hypothesis on the witness*, not a constraint on the oracle type (per `Oracle.lean.spec.md` §2.1 — the oracle type allows noncomputable oracles; BGS requires computable witnesses specifically). A statement that drops the computability hypothesis is a *different* (and in clause (a)'s case, trivial) theorem — Gate 5 (non-triviality) checks this.

3. **`P^A = NP^A` is set extensional equality.** The `=` must be set equality of two language classes (per `OracleComplexity.lean.spec.md` Trap 3). If `P^A`/`NP^A` are predicates (`Set α → Prop`), the rendering must use `∀ L, P^A L ↔ NP^A L` (predicate extensionality), not bare `=`. The choice follows whatever `OracleComplexity.lean` decides (Trap 3 of that spec) — the rendering must be *consistent* with it.

4. **Namespace:** `PleaNP.Barriers.Relativization` (per DEC-002, not `Complexity.*`).

---

## 3. The three rendering traps (specific to this statement)

These are the risk-points for rendering the BGS statement against `P^A`/`NP^A` — different from the recompose traps and the complexity-class traps.

### Trap 1 — The computability hypothesis (the "is the oracle recursive?" trap)

The recursiveness of the oracle witness is *load-bearing* for the theorem's meaning. A statement `∃ A : Oracle Q, P^A = NP^A` (no computability hypothesis) is *trivially true* — take A to be a PSPACE-complete oracle (which is computable), but also take A to be any noncomputable oracle that collapses the classes (which exists but isn't what BGS means). The spec requires the witness to be *recursive* — `∃ A, A_is_computable ∧ P^A = NP^A`. Omitting the computability hypothesis is a Gate 5 (non-triviality) failure: the statement becomes vacuously or trivially true.

**Acceptance criterion:** the rendering includes an explicit `Computable A` (or `Turing.Computable`-equivalent) hypothesis on the existentially-quantified oracle, in both clauses. Gate 5's vacuity scanner won't catch this (it's a semantic omission, not a syntactic pattern) — it's a review-layer check.

### Trap 2 — The equality encoding (the "set vs predicate" trap)

If `P^A` and `NP^A` are `Set (Set α)`, then `P^A = NP^A` is set extensional equality (the spec's intended meaning). If they're `Set α → Prop` (predicates), then `P^A = NP^A` as written is *propositional equality* (which is stronger than extensional equivalence and may not be what's meant). The rendering must match the `OracleComplexity.lean` choice (Trap 3 of that spec) and use the correct equality form.

**Acceptance criterion:** the rendering's `P^A = NP^A` (or `P^A L ↔ NP^A L`) matches the presentation in `OracleComplexity.lean`. If `OracleComplexity.lean` defines `P^A : Set (Set α)`, use `=`; if it defines `P^A : Set α → Prop`, use `∀ L, P^A L ↔ NP^A L`. Gate 4 (read-back) checks this: the read-back must say "the classes are equal as sets."

### Trap 3 — The oracle-query-type parameter (the "what is Q?" trap)

`P^A` is parameterized by the oracle `A : Oracle Q`, where `Q` is the query type. The BGS theorem's oracles A and B are *specific* oracles over a specific query type (e.g. `Q = List Bool` or `Q = ℕ`). The rendering must fix `Q` (or existentially quantify over it) consistently — a statement `∃ A : Oracle Q, ...` with `Q` as an unresolved universe variable is ambiguous. The spec requires `Q` to be concretely instantiated (e.g. `Q = List Bool`) or existentially quantified (`∃ Q, ∃ A : Oracle Q, ...`).

**Acceptance criterion:** the query type `Q` is either concretely instantiated (and recorded) or existentially quantified. It is not left as an open universe variable. Gate 4 (read-back) checks this.

---

## 4. What "done" looks like for `Relativization.lean` (the statement)

Per `LOCAL_AGENT_WORKFLOW.md` Steps 1–5:
- **Substrate confirmed** — `OracleComplexity.lean` is frozen (`P^A`/`NP^A` exist as real types).
- **Rendered, type-checks** — both `theorem` clauses compile with `:= by sorry` proof placeholders; zero dishonest placeholders (Gate 5 clean); the `sorry` is honest (Gate 6 catches it in render-stage, allowed).
- **Gates 1–5 passed** — statement-frozen (Gate 1: the file is version-controlled, read-only to proof search); model-consistency (Gate 2: oracle is `PleaNP.Oracles.Oracle`, no local P/NP redefinition); statement-fidelity (Gate 3: a second, independent formalization of BGS is checked for equivalence — this is the strong gate, and it's a *separate agent's* job per the architecture); read-back (Gate 4: the auto-generated English matches `Relativization.md` §5); non-triviality (Gate 5: the computability hypothesis is present, no vacuous variants).
- **Frozen** — the statement is the Gate-1 anchor. Proof search (Step 6) may now run against it, but only under Gates 1–5.

At that point `docs/STATEMENTS/Relativization.md`'s status flips from "Draft — scaffold" to "Frozen (statement); proof pending (Rung 3 Step 6, blocked on upstream P/NP + PSPACE)."

---

## 5. What this file does NOT do (scope honesty)

- **Does not prove the theorem.** The proof is Rung 3 Step 6, gated behind this frozen statement. The proof depends on: upstream `P`/`NP` (DEC-003, blocked), PSPACE/QBF formalization (clause (a) sandwich — see `Relativization.proof-strategy.md` §2), and the diagonalization construction (clause (b)). None of that is in this rendering spec.
- **Does not define `P^A`/`NP^A`.** Those are in `OracleComplexity.lean`. This file *uses* them.
- **Does not define `PSPACE` or `QBF`.** Those are proof-strategy dependencies (clause (a)), not statement dependencies. They're a separate substrate (GAP_AUDIT §8: not in Mathlib; PleaNP-local or tracked upstream).
- **Does not render the *barrier consequence*** (relativizing proofs can't separate P from NP). Per `Relativization.md` §3, the v1 target is clauses (a) and (b); the consequence is a derived corollary, rendered later.

---

## 6. Prior art and references

- **The informal statement:** `docs/STATEMENTS/Relativization.md` — the frozen informal spec (§1 theorem, §3 acceptance criteria, §5 read-back).
- **The proof strategy:** `docs/STATEMENTS/Relativization.proof-strategy.md` — informal outline (clause (a) sandwich, clause (b) diagonalization). NOT a frozen proof spec; informs the future proof work.
- **The class definitions:** `docs/STATEMENTS/OracleComplexity.lean.spec.md` — `P^A`/`NP^A` (the types this statement quantifies over).
- **The substrate:** `lean/PleaNP/Computability/Oracle.lean` (v2, frozen) + the future `OracleComplexity.lean`.
- **The integrity gates the traps map to:** `docs/ARCHITECTURE.md` — Gate 1 (freeze), Gate 2 (trap 1: oracle type), Gate 3 (independent second formalization — the strong gate), Gate 4 (traps 2, 3: read-back), Gate 5 (trap 1: computability hypothesis / non-triviality).
- **No existing formalization** of BGS in any proof assistant (`docs/PRIOR_ART.md` cross-assistant survey) — this statement is genuinely novel.
