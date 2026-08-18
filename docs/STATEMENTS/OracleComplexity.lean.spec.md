# Spec: `OracleComplexity.lean` (P^A / NP^A complexity classes)

**Rung:** 2 (local piece, the complexity layer on top of `Oracle.lean`) — defines the oracle-relative complexity classes that the relativization barrier (`docs/STATEMENTS/Relativization.md`) quantifies over.
**Status:** Spec — the frozen target for the local agent. The actual Lean rendering is the local agent's job (`lake build` validation required, per DEC-007). This document contains **no Lean code** — only the design, the constraints, the acceptance criteria, and the specific risk-points (the "traps" for *this* file, which are different from the recompose traps in `OracleTM2Recompose.spec.md`). A separate trust boundary from the proof work, per `docs/ARCHITECTURE.md`.

**Dependency:** This file builds on `Oracle.lean` v2 (DEC-010 Option B, the TM2 recompose). It cannot be rendered until `Oracle.lean` is frozen — specifically until `oracleQuery` has a real body (not `none`), `DecidesInTime` has a real body (not `iff True`), and the `StepCount` instance is concrete. Per the current review state, `oracleQuery` and `DecidesInTime` are real; `P_empty_eq_upstream_P` is `sorry`'d (honest, pending proof). This spec assumes that state or better.

---

## 1. Why this file exists and what it is *not*

`Oracle.lean` defines the *machinery* — the oracle type, the oracle machine, the step function, the `StepCount` interface, and the `DecidesInTime` bridge. `OracleComplexity.lean` defines the *complexity classes* built on top of that machinery: **`P^A`** (deterministic polynomial time relative to oracle `A`) and **`NP^A`** (nondeterministic polynomial time relative to `A`). These are the classes the relativization theorem (`∃ A, P^A = NP^A` and `∃ B, P^B ≠ NP^B`) quantifies over. Without them, the barrier statement cannot be rendered.

**What this file is *not*:** it is *not* a proof, *not* the relativization theorem, and *not* a definition of unrelativized `P`/`NP` (those are upstream, per DEC-003). It is the *oracle-relative* classes — `P^A` and `NP^A` parameterized by the oracle `A`. The unrelativized `P`/`NP` are a *special case* (the empty oracle, per Trap 4 below) and are upstream's job.

---

## 2. The four objects `OracleComplexity.lean` must define

### 2.1 `P^A` — deterministic polynomial time relative to `A`

`P^A` is the class of languages decidable by a *deterministic* oracle machine for `A` in *polynomial time*. Concretely: a language `L : Set α` is in `P^A` if there exists an oracle machine `M` (with oracle `A`) and a polynomial `p : ℕ → ℕ` such that for every input `x`, `M` decides `x ∈ L` (per `DecidesInTime` from `Oracle.lean`) within `p(|x|)` steps (per `StepCount`/`EvalsToInTime`).

**Logical shape (the local agent renders):**
- `P^A` is a *language class* — a `Set (Set α)` or equivalently a predicate on languages. The choice follows whatever convention the upstream `P`/`NP` use (Gate 2 model-consistency: match upstream, don't redefine locally).
- The polynomial bound is explicit: a `Polynomial ℕ` or a `∃ k, p(n) = n^k`-style bound, consistent with `TM2ComputableInPolyTime` (the core Mathlib substrate from DEC-010).
- The time bound applies to the *oracle machine's step count*, where each oracle query costs exactly 1 step (the `StepCount`/`EvalsToInTime` integration from `Oracle.lean` Trap 2).

**Acceptance criteria:**
- `P^A` is parameterized by the oracle `A : Oracle Q` (a `variable` or explicit parameter), not by a constructed oracle.
- The polynomial bound is explicit, not hand-waved.
- The class is extensional (a set of languages), so `P^A = NP^A` can be stated as set equality — a Gate 2 check item from `Relativization.md` §3.

### 2.2 `NP^A` — nondeterministic polynomial time relative to `A`

`NP^A` is the class of languages decidable by a *nondeterministic* oracle machine for `A` in polynomial time. This is the harder of the two to define, because **nondeterminism** has to be encoded, and the encoding choice is a risk-point (Trap 2 below).

Two standard encodings exist; the local agent picks one and records it:
- **Verifier framing:** `L ∈ NP^A` if there exists a polynomial `p` and a deterministic oracle machine `M` such that `x ∈ L ↔ ∃ y, |y| ≤ p(|x|) ∧ M(x, y) = 1` (M is a poly-time verifier with oracle access to `A`, taking input `x` and certificate `y`).
- **Nondeterministic-machine framing:** `L ∈ NP^A` if there exists a nondeterministic oracle machine (with a guess/branching step) that accepts exactly `L` in polynomial time.

The verifier framing is the more common formalization choice (it avoids needing a nondeterministic machine model — `M` is a *deterministic* oracle machine with a second input). It's also the one that composes most cleanly with `DecidesInTime` from `Oracle.lean`. **Recommended: verifier framing**, but the local agent records the choice.

**Acceptance criteria:**
- `NP^A` is a language class (extensional, same as `P^A`).
- The polynomial bound on *both* the certificate size and the verifier's running time is explicit.
- The encoding of nondeterminism (verifier vs. ND machine) is recorded in a docstring — it's a Gate 4 read-back check item.

### 2.3 The `P^A ⊆ NP^A` trivial inclusion

This is the deterministic-⊆-nondeterministic direction, relativized. It's the "trivial" direction of BGS (true for any oracle, not specific to `A`), but it's a real proof obligation and should be stated/proved here as a sanity check that the classes are well-defined.

**Acceptance criterion:** `P^A ⊆ NP^A` is provable (not `sorry`'d) from the definitions in §2.1/§2.2. If it's not provable, the class definitions are wrong relative to each other — a structural self-check.

### 2.4 The `P^∅ = P` compatibility carry-through (Trap 4)

This carries the `P_empty_eq_upstream_P` statement from `Oracle.lean` (Trap 3 of the recompose) *through* the complexity-class definitions. Once `P^A` is defined, the compatibility check becomes sharper: `P^∅` (P relative to the empty oracle) must equal upstream `P` (= `TM2ComputableInPolyTime` with no oracle queries). If `P^∅ ≠ P`, the class definition has quietly redefined P — the Gate 2 failure the whole architecture guards against.

**Acceptance criterion:** a `P_empty_eq_upstream_P`-style lemma (statement; proof may track upstream `P`), now stated at the *class* level: `P^(emptyOracle) = <upstream P>`. This is the model-consistency anchor for `OracleComplexity.lean` specifically.

---

## 3. The four traps (risk-points for *this* file)

These are different from the recompose traps (`OracleTM2Recompose.spec.md` §4). Each is a place where the class definitions can compile clean but mean something subtly wrong.

### Trap 1 — Polynomial-bound encoding (the "is it really polynomial?" trap)

The polynomial bound must be a *genuine* polynomial — `∃ k, p(n) ≤ n^k` for some constant `k` — not an arbitrary function, not an unbounded function, and not a function that's polynomial in the *wrong* parameter (e.g. polynomial in `2^n` instead of `n`). The `TM2ComputableInPolyTime` substrate (from DEC-010) uses a `Polynomial ℕ` time field; `P^A`/`NP^A` must use the same notion of "polynomial" so the empty-oracle case (`P^∅ = P`) reduces correctly (Trap 4).

**Failure mode:** a bound that's "polynomial" in a vacuous sense (e.g. `p(n) = n^n` is not polynomial; `p(n) = 2^n` is not polynomial). The class becomes trivially large or meaningless. Gate 5 (non-triviality) and Gate 2 (model-consistency) check this.

### Trap 2 — Nondeterminism encoding (the "what does NP^A mean?" trap)

The encoding of nondeterminism (verifier vs. ND machine — §2.2) determines what `NP^A` *is*. A verifier-framing `NP^A` and an ND-machine-framing `NP^A` are (under standard assumptions) extensionally equal, but they're *different definitions*, and a `P^A = NP^A` proof that works under one encoding may not transfer to the other. The choice must be recorded and kept consistent across `OracleComplexity.lean` and the eventual relativization proof.

**Failure mode:** silently switching encodings between the class definition and the theorem proof, so the theorem proves a different equivalence than the classes express. Gate 4 (read-back) and Gate 3 (independent second formalization) check this.

### Trap 3 — Extensionality (the "is P^A = NP^A set equality or predicate equivalence?" trap)

`Relativization.md` §3 requires `P^A = NP^A` to be *set extensional equality* of two language classes. If `P^A` and `NP^A` are defined as *predicates* (`Set α → Prop`) rather than *sets* (`Set (Set α)`), then `P^A = NP^A` is predicate extensionality (`∀ L, P^A L ↔ NP^A L`), not set equality — a different statement. The local agent must pick the presentation that makes the relativization statement's `=` mean what the spec says (set equality), and keep it consistent.

**Failure mode:** `P^A = NP^A` compiling but meaning "the predicates are pointwise equivalent" (which is extensionally the same but formally a different theorem). Gate 4 (read-back: "the classes are equal as sets") checks this.

### Trap 4 — `P^∅ = P` compatibility (the model-consistency anchor, carried through)

Per §2.4: with the empty oracle, `P^∅` must equal upstream `P`. This is the check that defining `P^A` didn't quietly redefine P. It carries `Oracle.lean`'s Trap 3 through the class layer.

**Failure mode:** `P^∅` comes out different from upstream `P` — meaning the polynomial-bound encoding (Trap 1) or the oracle-query step counting (recompose Trap 2) drifted, and `P^A` isn't "P with oracle A" but "a subtly different class with oracle A." Gate 2 checks this; the proof may track upstream `P`.

---

## 4. What "done" looks like for `OracleComplexity.lean`

Per `LOCAL_AGENT_WORKFLOW.md` status convention:
- **Substrate confirmed** — `Oracle.lean` v2 is frozen (all recompose traps passed; `oracleQuery` real; `DecidesInTime` real; `StepCount` concrete).
- **Rendered, type-checks** — `P^A`, `NP^A`, `P^A ⊆ NP^A`, and `P^∅ = P` (statement) compile; zero dishonest placeholders (Gate 5 clean); the `P^∅ = P` proof may be `sorry`'d honestly (Gate 6 catches it).
- **Gates 2/4/5/6 passed** — model-consistency (canonical types, no local P/NP redefinition); read-back ("P^A is the class of languages decidable in deterministic polynomial time with oracle A; NP^A is the nondeterministic analogue"); vacuity clean; hygiene clean.
- **Trap 1–4 verified** — polynomial bound genuine; nondeterminism encoding recorded; extensionality matches the relativization statement; `P^∅ = P` stated.
- **Frozen** — the class definitions are canonical; the relativization statement (`∃ A, P^A = NP^A` / `∃ B, P^B ≠ NP^B`) can now be rendered in `Relativization.lean` against real `P^A`/`NP^A` types.

At that point `docs/STATEMENTS/Relativization.md` §2's dependency "`P^A`, `NP^A` — PleaNP-local" flips from *pending* to *Done*, and the relativization *statement* is renderable (Step 1 of its workflow). The *proof* remains blocked on upstream `P`/`NP` (DEC-003) and the diagonalization (Gate 7, Rung 6+).

---

## 5. What this file does NOT do (scope honesty)

- **Does not define unrelativized `P`/`NP`.** Those are upstream (DEC-003). `P^A`/`NP^A` are *oracle-relative* classes; the empty-oracle case reduces to upstream P, but upstream P itself is not defined here.
- **Does not prove the relativization theorem.** That's Rung 3, gated by the frozen `Relativization.md` statement. This file enables the statement to be rendered; the proof waits on upstream `P`/`NP` and the diagonalization.
- **Does not define `PSPACE` or `QBF`.** Those are needed for the relativization *proof* (clause (a), the sandwich — see `Relativization.proof-strategy.md` §2), not for the *class definitions* or the *statement*. They're a separate substrate (likely PleaNP-local or tracked upstream; GAP_AUDIT §8: not present in Mathlib).
- **Does not define circuits or `P/poly`.** Those are Rung 4 (`PleaNP.Circuits`), needed for natural proofs (3b), not for relativization (3a).

---

## 6. Prior art and references

- **The substrate this builds on:** `lean/PleaNP/Computability/Oracle.lean` (v2, DEC-010 Option B) — the oracle type, oracle machine, `StepCount`/`EvalsToInTime` integration, `DecidesInTime` bridge.
- **The recompose spec:** `docs/STATEMENTS/OracleTM2Recompose.spec.md` — the three recompose traps (this file's traps are different; see §3).
- **The Mathlib API (verified in v4.31.0):** `Turing.TM2ComputableInPolyTime` (the polynomial-time variant of `TM2ComputableInTime`), `Turing.EvalsToInTime` (`.refl`/`.trans` additive step counting), `Turing.FinTM2`.
- **The barrier statement this serves:** `docs/STATEMENTS/Relativization.md` — §2 dependency table (P^A/NP^A = PleaNP-local), §3 acceptance criteria (set extensionality, recursiveness hypothesis).
- **The integrity gates the traps map to:** `docs/ARCHITECTURE.md` — Gate 2 (traps 1, 4), Gate 4 (traps 2, 3), Gate 5 (non-triviality), Gate 6 (hygiene).
- **No existing formalization of `P^A`/`NP^A`** in any proof assistant (`docs/PRIOR_ART.md` cross-assistant survey) — this file is genuinely novel substrate, like the oracle machine itself.
