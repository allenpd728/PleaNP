# Upstream tracking: Mathlib complexity efforts

The computational-model substrate (Rung 2) is *not* PleaNP's to build — it's being actively contested by multiple efforts upstreaming into Mathlib. This document tracks them so PleaNP imports the right thing rather than reinventing or picking sides.

Last reviewed: 2026-08-18 (deepened: recorded Mathlib `RecursiveIn.lean` oracle-computability finding; verified no OWF/PRF infrastructure). This is a living document — update when upstream lands.

---

## The active efforts

### 1. Mathlib #35366 — `Turing.TM1` with fuel-based step counting

- **Author:** KrystianYCSilva (Feb 2026)
- **Approach:** Extends Mathlib's existing `Turing.TM1` (from `PostTuringMachine.lean`, Carneiro 2018) with `runN` (fuel-based) step counting, then defines P, NP, and proves `p_sub_np`.
- **Status:** Working, zero `sorry`, compiles against Mathlib v4.28.0-rc1. Seeking maintainer feedback on PR sequencing. Proposes a 3-PR sequence: `step_none_iff` lemma → `TM1Complexity.lean` with `runN` → complexity classes + `p_sub_np`.
- **Builds on:** existing, merged Mathlib infrastructure (`Turing.TM1`).
- **PleaNP stance:** Strong candidate to import from. Uses existing infrastructure, lowest-risk path. Pending maintainer feedback on `runN` vs relational approach.

### 2. PR #33132 — `FinTM0` bundled type

- **Author:** BoltonBailey
- **Approach:** A *new* `FinTM0` bundled type with `EvalsTo`/`EvalsToInTime`, rather than extending existing `TM1`.
- **Status:** Open PR. Complementary to #35366 — builds new TM definitions rather than extending existing ones.
- **PleaNP stance:** Watch. If this lands instead of #35366, import `FinTM0`-based definitions. The relational (`EvalsTo`) approach may be cleaner for stating time bounds.

### 3. `descriptive-complexity` (separate repo)

- **Author:** PierreSenellart
- **Approach:** Machine-free — defines NP-completeness via logical definability on top of Mathlib's `ModelTheory` (Immerman-style descriptive complexity). No Turing machines. Covers all 21 Karp problems, Cook-Levin without a machine model.
- **Status:** Released (v1.2.0 against Mathlib v4.33.0). Not part of Mathlib core.
- **PleaNP stance:** This is a *different strategic axis*. It avoids the computational-model pain entirely but defines complexity classes logically, which may not give us the oracle-machine substrate relativization needs. Track as a possible source for NP-completeness results, but the barriers likely need a machine model with oracles.

### 4. Simas (2026, arXiv:2601.15571)

- **Approach:** Polynomial-time reductions in Lean 4, but deliberately does *not* use Mathlib's TMs and does *not* define P/NP.
- **Status:** Paper, not a Mathlib PR.
- **PleaNP stance:** Reference for reduction-formalization technique, but not importable (defines its own substrate).

### 5. The Coq precedent (not Lean, but methodological)

- **Gäher & Kunze, ITP 2021.** Cook-Levin in Coq using the call-by-value λ-calculus L as model. Required Forster-Kunze-Wuttke-Smolka (L ↔ TMs, polynomial overhead) first.
- **Methodological lesson:** The λ-calculus route was chosen *because* TMs were too painful ("19K lines, inherently infeasible" — Forster). If Lean's `Turing.TM1` route proves equally painful, the λ-calculus or synthetic approach is the fallback.

---

## What none of the upstream efforts provide

This is PleaNP's gap to fill, regardless of which model lands:

- **Time-bounded oracle computation.** Mathlib already has *oracle computability* — `Mathlib/Computability/RecursiveIn.lean` (Duve/Roth, 2025) defines `Nat.RecursiveIn O f` (a function partial-recursive given an oracle set `O`), the recursion-theoretic substrate. But this is *unbounded-time*. What relativization (Baker-Gill-Solovay) needs is a machine with an oracle tape answering a fixed function in one step **under a polynomial time bound** — i.e. `P^A` / `NP^A`. None of #35366, #33132, descriptive-complexity, Simas, or `RecursiveIn` provide this time-bounded oracle-machine layer.
- **Oracle complexity classes** (P^A, NP^A) and oracle-separation results (Baker-Gill-Solovay).
- **The barrier theorems themselves** (natural proofs, algebrization) — none of these efforts touch them.
- **Circuit complexity** (AC⁰, TC⁰, NC) and **proof complexity** (resolution, Frege).
- **Cryptographic primitives for natural proofs** (one-way functions, pseudorandom function families) — code search of Mathlib master confirms none exist (see `docs/GAP_AUDIT.md` §6, open question 1).

---

## Decision rules for PleaNP

1. **Do not define P, NP, or reductions locally.** Import from whichever upstream effort lands first in Mathlib core.
2. **Do define oracle machines locally** (under `PleaNP.Barriers.Relativization` or a dedicated `PleaNP.Oracles` namespace), since no upstream effort provides them.
3. **Track the computational-model choice.** When P/NP lands in Mathlib, record the chosen model in `docs/decisions/LOG.md` and update this document.
4. **If the chosen model makes oracle-machine definition painful**, evaluate the synthetic approach (Church's Thesis as axiom) as a fallback — per the Coq precedent, it dramatically lowers overhead.

---

## Naming

PleaNP uses the `PleaNP.*` namespace for all project-specific declarations, *not* `Complexity.*`. The `Complexity` namespace is being actively designed by the Mathlib community; claiming it would conflict with upstream and misrepresent PleaNP's role (we formalize barriers, not complexity classes).
