# Recomposition spec: `Oracle.lean` v2 (against core `TM2ComputableInTime`)

**Rung:** 2 (local piece) — the recomposition mandated by DEC-010 (Option B chosen: stay on core Mathlib v4.31.0, recompose against `TM2ComputableInTime`'s step-counting machinery, no external dependency, no toolchain change).
**Status:** Recomposed (v2 against TM2ComputableInTime). Steps 0-2 passed (build green, hygiene clean). Steps 3-5 (model-consistency, read-back, freeze) pending review. See lean/PleaNP/Computability/Oracle.lean.

This spec *supersedes* the TM1-specific composition guidance in `Oracle.lean.spec.md` §4. The oracle-type and totality-discipline requirements of that spec are **unchanged** (see §3 below); only the machine substrate and step-counting instantiation change.

---

## 1. Why this recomposition and what changes vs. what stays

The v1 `Oracle.lean` (commit `8d56795`, DEC-008) is built against `Turing.TM1` (core, `PostTuringMachine.lean`), which has **no step counting**. The `StepCount` typeclass is declared but has **no instance** — so `P^A`/`NP^A` cannot be defined, and the relativization statement cannot be rendered. DEC-010 chose Option B: recompose against `Turing.TM2ComputableInTime` (core, `Mathlib/Computability/TuringMachine/Computable.lean`), which *has* step-counting machinery. This unblocks `P^A`/`NP^A` without a toolchain change or external dependency.

**What changes (the surgical swap the `StepCount` interface was built for):**
- The underlying machine model: `TM1` → `TM2` (multi-tape). `Cfg` and `Machine` reference `TM2` types instead of `TM1`.
- The `step` function delegates to `TM2.step` instead of `TM1.step`.
- The `StepCount` typeclass gets a **concrete instance** against `TM2`'s step-counting relation, instead of being an empty interface.

**What stays unchanged (the whole point of the interface isolation):**
- The oracle type: `Oracle Q := Q → Bool` (total, codomain `Bool`). **Must not be re-rendered.**
- The totality discipline (§3).
- `Oracle.toSet`, `Oracle.query` (the single-step, stipulated query).
- The `StepCount` *interface signature* (other PleaNP code depending on `StepCount.runN` doesn't break; only the instance changes).
- The namespace (`PleaNP.Oracles`) and file location.

---

## 2. The Mathlib substrate being composed with (verified API)

The recomposition composes with these core Mathlib definitions (in `Mathlib/Computability/TuringMachine/Computable.lean` and `StateTransition.lean` — confirmed present in v4.31.0):

- **`Turing.FinTM2`** — a bundled TM2 (multi-tape) with finiteness conditions, the underlying machine.
- **`Turing.TM2OutputsInTime tm l l' m`** — a proof that `tm` outputs `l'` when given `l` in at most `m` steps. Defined as `Turing.EvalsToInTime tm.step (initList tm l) (Option.map (haltList tm) l') m`.
- **`Turing.EvalsToInTime f a c m`** — the step-counted evaluation relation: state `a` reaches `c` in at most `m` steps of `f : σ → Option σ`. Has `.refl` (0 steps) and `.trans` (**additive**: `m₂ + m₁` steps). This is the relation the `StepCount` instance bridges to.
- **`Turing.TM2ComputableInTime ea eb f`** — a bundled TM2 + a `time : ℕ → ℕ` field + a proof it outputs `f : α → β` in at most `time(input.length)` steps. The polynomial variant is `TM2ComputableInPolyTime` (`time` is a polynomial).
- **`Turing.TM2Outputs tm l l'`** — the unbounded-time version (forgetful of the step bound).

The crucial structural fact: `EvalsToInTime` counts steps of the *base* `tm.step` function. So an oracle query must appear in `tm.step`'s step count as **exactly one step** — see §4 trap 2.

---

## 3. Totality discipline (unchanged from v1 spec §3 — repeated because it must not be lost in the swap)

PleaNP's oracle is *total* by construction. It must **not** reuse Mathlib's `RecursiveIn` / `TuringReducible` types as-is (the partial / enumeration-degree notion — `docs/PRIOR_ART.md` §1). Totality is enforced at the *type level*: the oracle's codomain is `Bool`, not `Part Bool` or `Option Bool`.

**This is the single acceptance criterion that the recomposition must not violate.** The swap from TM1 to TM2 touches the *machine*, not the *oracle* — the oracle type `Oracle Q := Q → Bool` is identical in v1 and v2. If the recomposition re-renders the oracle type (e.g. to "match" a TM2 convention), that's a scope violation; the totality discipline is model-independent.

**Gate mapping (unchanged):** Gate 2 (model-consistency: `Oracle` is `PleaNP.Oracles.Oracle`, not a `RecursiveIn` alias), Gate 4 (read-back: "a total function from strings to yes/no"), Gate 6 (hygiene: zero `sorry` — run `python3 tooling/gates/hygiene_scan.py --prove-stage lean/PleaNP/Computability/`).

---

## 4. The three traps the recomposition must get right

### Trap 1 — The function-to-language bridge (the framing change)

`TM2ComputableInTime` is a **function-computability** framing: it computes `f : α → β` within time. `P^A`/`NP^A` need **language-decision**: "decides whether `x ∈ L`" for `L : Set α`, within time. These are *not* the same shape; the recomposition must bridge them.

**Logical shape of the bridge:**
- A language `L : Set α` is decided by deciding its **characteristic function** `χ_L : α → Bool` (χ_L x = true ↔ x ∈ L), within time. So `P^A` = languages whose characteristic function is computable in polynomial time by an oracle machine for `A`.
- **The convention must be pinned:** which output encoding means "yes"? The spec requires: the machine outputs `χ_L(x) ∈ Bool` (or an equivalent fixed yes/no encoding in the output alphabet `Γ₁`), and **the convention is recorded** (e.g. `true`/a designated symbol = accept). A recomposition that leaves the yes/no convention ambiguous is a Gate 4 (read-back) failure — the read-back must say "decides L by outputting its characteristic function in time."

**Acceptance criterion:** the recomposition defines a `DecidesInTime`-style bridge (or reuses Mathlib's convention if one exists — the local agent checks) that fixes, for a language `L` and time bound `t`, what it means for an oracle machine to decide `L` in `t` steps. The convention is explicit, not implicit.

### Trap 2 — The oracle query as exactly one step in `EvalsToInTime`

This is the crux and the most likely integrity failure. `EvalsToInTime` counts steps of `tm.step`. An oracle query must consume **exactly 1 step** in that count — not be simulated (running `A`'s decider and counting those steps), not be free (0 steps), not be amortized.

- **If the query is simulated:** `P^A` depends on `A`'s actual complexity → the barrier collapses (an oracle for a hard language makes `P^A` slow, which trivializes or distorts the relativization theorem). This is the "build it wrong → fake success" failure mode for the recomposition.
- **If the query is 0 steps:** the oracle is free, which can make `P^A` trivially contain things it shouldn't.
- **Correct:** the query transition appears in `tm.step` as one application, and `EvalsToInTime` counts it as one step (via `.trans` adding 1).

**Acceptance criterion:** there is a proof/argument that an oracle query contributes exactly 1 to the `EvalsToInTime` step count. The local agent should verify this by construction (the query is a single `tm.step` transition that stipulates `A(q)` and does not recurse into `A`), and note in the file how the 1-step property is preserved. This is the property Gate 2 (model-consistency) checks for the recomposition specifically.

### Trap 3 — `P^∅ = P` compatibility (the model-consistency anchor)

With the **empty oracle** (`A := fun _ => false`, or however the empty language is represented), PleaNP's `P^∅` must equal upstream `P`. If it doesn't, the recomposition has quietly redefined `P`, which is the Gate 2 failure the whole architecture guards against (`STATEMENTS/Relativization.md` §3, the "redefine NP weaker" trap, applied to P).

- This is the cleanest check that the recomposition didn't drift: a non-oracle machine (one that never queries) under PleaNP's `P^∅` should agree with upstream `P` (= `TM2ComputableInPolyTime` with no oracle).
- Note: upstream `P` itself isn't *in* Mathlib core yet (that's the Rung-2 block), but `TM2ComputableInPolyTime` *is* the substrate it'll be defined on. So the compatibility check is: `P^∅` reduces to "poly-time `TM2ComputableInPolyTime` with no oracle queries" — i.e., a non-oracle machine's `P^∅`-membership is exactly `TM2ComputableInPolyTime` membership. The local agent states this relationship; proving it may wait on upstream `P`, but the *statement* of compatibility should be renderable now.

**Acceptance criterion:** the recomposition includes a (possibly-`sorry`-free-statement, proof-pending) lemma `P_empty_eq_upstream_P` or equivalent, expressing that the empty-oracle case reduces to non-oracle `TM2ComputableInPolyTime`. The *statement* existing is the acceptance bar; the *proof* may track upstream `P`.

---

## 5. What "done" looks like for the recomposition

Per `LOCAL_AGENT_WORKFLOW.md` status convention, v2 progresses:
- **Substrate confirmed** — `TM2ComputableInTime` / `EvalsToInTime` present in v4.31.0 (verified for this spec; local agent re-confirms with `lake build` of a Mathlib import).
- **Recomposed, type-checks** — `Oracle.lean` v2 compiles against TM2; `Cfg`/`Machine` reference TM2 types; `StepCount` has a concrete instance against `EvalsToInTime`; zero `sorry` in the recomposition (hygiene scan clean in `--prove-stage`).
- **Gates 2/4/6 passed** — totality verified (oracle type unchanged, codomain `Bool`); read-back of `Oracle` + the `DecidesInTime` bridge matches §3/§4 trap 1; hygiene clean.
- **Trap 2 verified** — oracle query = 1 step in `EvalsToInTime` (by construction; documented in-file).
- **Trap 3 stated** — `P^∅ = P` compatibility lemma rendered (proof may track upstream `P`).
- **Frozen** — v2 is the canonical `Oracle.lean`; v1 is reachable via the `pre-oracle-prototype` git tag if rollback is needed.

At that point `P^A`/`NP^A` become definable (in `OracleComplexity.lean` or the same file), and `docs/STATEMENTS/Relativization.md` §2's dependency "Oracle machines — PleaNP-local" flips from *Partial* to *Done*, unblocking the relativization *statement* (Step 1 of its workflow). The *proof* of BGS remains blocked on upstream `P`/`NP` (DEC-003) — the recomposition unblocks the *vocabulary*, not the theorem.

---

## 6. What this recomposition does NOT do (scope honesty)

- **Does not define upstream `P`/`NP`.** Those are still upstream's job (DEC-003). The recomposition defines `P^A`/`NP^A` *relative to* the oracle machine and the `TM2ComputableInPolyTime` substrate; it does not define unrelativized `P`/`NP`.
- **Does not prove the relativization theorem.** That's Rung 3, gated by the frozen `Relativization.md` statement. The recomposition enables the *statement* to be rendered; the *proof* waits on upstream `P`/`NP` and the diagonalization (Gate 7, Rung 6+).
- **Does not remove the v1 file or its tag.** `pre-oracle-prototype` stays as the rollback point. v2 edits `Oracle.lean` in place (same namespace, same path); the tag points at v1 for recovery.

---

## 7. Prior art and references

- **DEC-010** — the decision record for Option B (this recomposition).
- **DEC-008** — v1 (TM1 prototype) and the `StepCount` interface isolation that makes this swap surgical.
- **`docs/STATEMENTS/Oracle.lean.spec.md`** — the original design spec; §2 (the four objects) and §3 (totality) still govern; §4 (composition) is superseded by this document for the TM2 path.
- **Mathlib API (verified in v4.31.0):** `Turing.TM2OutputsInTime`, `Turing.EvalsToInTime` (with `.refl`/`.trans` additive step counting), `Turing.TM2ComputableInTime` / `TM2ComputableInPolyTime`, `Turing.FinTM2` — in `Mathlib/Computability/TuringMachine/Computable.lean` and `StateTransition.lean`.
- **The BGS statement this substrate serves:** `docs/STATEMENTS/Relativization.md`.
- **The integrity gates the traps map to:** `docs/ARCHITECTURE.md` — Gate 2 (trap 2, trap 3), Gate 4 (trap 1 read-back), Gate 6 (hygiene).
