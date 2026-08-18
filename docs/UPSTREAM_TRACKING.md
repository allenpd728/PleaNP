# Upstream tracking: Mathlib complexity efforts

The computational-model substrate (Rung 2) is *not* PleaNP's to build — it's being actively contested by multiple efforts upstreaming into Mathlib. This document tracks them so PleaNP imports the right thing rather than reinventing or picking sides.

Last reviewed: 2026-08-18 (deepened: recorded Mathlib `RecursiveIn.lean` oracle-computability finding; added complexitylib (Schlesinger) as tracked effort #6; verified no OWF/PRF infrastructure). This is a living document — update when upstream lands.

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

### 6. complexitylib — Samuel Schlesinger

- **Repo:** https://github.com/SamuelSchlesinger/complexitylib (default branch `master`)
- **Approach:** A standalone Lean 4 / Mathlib formalization of complexity theory using concrete Arora–Barak-style multi-tape Turing machines (deterministic, nondeterministic, probabilistic) over a fixed four-symbol alphabet, with explicit time and space predicates. Concrete over abstract: machines, circuits, reductions, and encoders are concrete definitions, not bare existence claims. An `AxiomGuard` script mechanically guards headline results against hidden axioms.
- **Toolchain:** `leanprover/lean4:v4.30.0`, pinning Mathlib to `v4.30.0`. **This does NOT match PleaNP's `v4.31.0`** — a toolchain/dependency reconciliation is a prerequisite to any import. Review item.
- **License:** Apache 2.0 (compatible with PleaNP).
- **What it has:** `P`, `NP`, `BPP`, `PSPACE` (plus `DTIME`/`NTIME`/`DSPACE`/`NSPACE`, `PPoly`/`PAdvice`, `RP`/`ZPP`/`PP`/`EXP`/`NEXP`/`SC`/`FNP`/`TFNP`); multi-tape-to-single-tape simulation; universal machines; the deterministic time-hierarchy theorem; a full Cook-Levin reduction (`SAT` is NP-complete) via computation tableaux; a typed Boolean-circuit model with size/depth, CNF/DNF, Shannon bounds, gate-elimination lower bounds, Schnorr's XOR lower bound, Valiant depth reduction; a logarithmic-cost RAM model; and a Fourier-analysis-of-Boolean-functions subtheory (O'Donnell ch. 1) — the analytic foundation for small-depth lower bounds and natural proofs.
- **What it explicitly lacks:** Oracle machines (the roadmap lists "oracle access" as needing common interfaces before headline equivalences can be stated), and **all three barriers** (relativization, natural proofs, algebrization) — code search confirms zero hits for `oracle`/`relativization`/`barrier`/`algebrization`. These are exactly PleaNP's gap.
- **PleaNP stance:** Strong candidate to import P/NP/reductions/Cook-Levin/circuit-basics from, *if* the toolchain reconciles to v4.31.0 (or PleaNP adjusts). Its circuit lower bounds and Fourier-analysis subtheory are directly reusable for Rung 4. Pending review — **not yet added to `lakefile.lean`**. Proposed dependency entry:
  ```lean
  require complexitylib from git
    "https://github.com/SamuelSchlesinger/complexitylib.git" @ "main"
  ```
  (Note: the repo's default branch is `master`, not `main`; the entry above matches the requested form but should be `@ "master"` — or a tagged release — before being added.)

  **Reconciliation check (2026-08-18, attempted):** Added complexitylib (`dev` branch) to PleaNP's lakefile and built under Lean v4.31.0 / Mathlib v4.31.0. **Result: does NOT reconcile cleanly.** The build fails on ~23 of ~4033 modules with Mathlib API-drift errors (e.g. `Complexitylib.Mathlib.NatBits` — `simp made no progress`; `Complexitylib.Models.TuringMachine.Trace.Internal` — type-mismatch after simplification; failures in `Asymptotics`, `Circuits.Internal.Spira`, `Models.TuringMachine.*`, `DescriptiveComplexity.Reduction`, etc.). These are caused by `simp`-lemma and term-structure changes between Mathlib v4.30.0 (what complexitylib pins) and v4.31.0 (what PleaNP pins). complexitylib would need its proofs updated for the v4.31.0 Mathlib API before it can be imported. **Decision: build Oracle.lean against core `Turing.TM1` (partial prototype) for now; revisit complexitylib import when it bumps to v4.31.0+ or when PleaNP can pin v4.30.0.**

---

## What none of the upstream efforts provide

This is PleaNP's gap to fill, regardless of which model lands:

- **Time-bounded oracle computation.** Mathlib already has *oracle computability* — `Mathlib/Computability/RecursiveIn.lean` (Duve/Roth, 2025) defines `Nat.RecursiveIn O f` (a function partial-recursive given an oracle set `O`), the recursion-theoretic substrate. But this is *unbounded-time*. What relativization (Baker-Gill-Solovay) needs is a machine with an oracle tape answering a fixed function in one step **under a polynomial time bound** — i.e. `P^A` / `NP^A`. None of #35366, #33132, descriptive-complexity, Simas, `RecursiveIn`, or complexitylib provide this time-bounded oracle-machine layer (complexitylib's own roadmap flags oracle access as unfinished).
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
