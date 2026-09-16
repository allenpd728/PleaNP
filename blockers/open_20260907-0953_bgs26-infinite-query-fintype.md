# Blocker: #26 — `U_B B ∈ NP_A (alpha := Nat) B` uninhabitable under current substrate

- **Task/issue attempted:** #26 (BGS #21 follow-up: construct the guess-query-verify oracle machine for U_B in NP^B), run=20260907-0935-6qnm
- **Date:** 2026-09-07

## What information is missing

A **human decision** on how to reconcile a hard type-level contradiction between
#26's DoD and the current PleaNP oracle substrate. Thisis not a mechanism the agent
can choose around: (see "what I tried" below), either interprepreting #26 as stated
is impossible, or one of several spec changes is required.

## The exact gap (with Lean-verified facts)

#26 requires proving:

```lean
theorem U_B_in_NP : U_B B ∈ NP_A (alpha := Nat)B                      -- (from the issue body)
```

Unfolding `NP_A` (lean/PleaNP/Computability/OracleComplexity.lean:57-66), this
needs a `tm' : FinTM2` and a `hΓ : tm'.Γ tm'.k₀ = Query`, where
`Query = Σ n : Nat, Bits n` is #21's frozen oracle-query type
(lean/PleaNP/Barriers/BGSDiagonal.lean:49, `Bits n = Fin n → Bool`,
`abbrev` line 45).

`FinTM2` (Mathlib `Computability/TuringMachine/Computable.lean:46-70` carries a
bundled, non-optional field:

```lean
[Γk₀Fin : Fintype (Γ k₀)]      -- the input stack alphabet is REQUIRED finite
```

So any machine witnessing #26 forces, by transport along `hΓ`,
`Fintype Query`— an instance that Lean **proves does not exist**:

- `Fintype (Bits n)` synthesizes for every fixed `n` (verified: `example (n : Nat) :
  Fintype (Bits n) := by infer_instance` compiles`..
- `Fintype Query` synthesis fails, and can never exist: `Nat` injects into `Query`
  via the all-false strings `n ↦ ⟨n, fun _ => false⟩` (pairwise-distinct length
  tags),so `Query` hosts an infinite family — `Infinite Query` (infinitude
  argument per `Data/Finite/Defs.lean` / `Data/Set/Finite/Basic.lean`;the direct
  synthesis refusal was observed in Lean v4.31.0/Mathlib v4.31.0)..

```

## What I tried

1. Built the substrate: `lake build PleaNP.Barriers.BGSDiagonal PleaNP.Computability.OracleComplexity` —
   green,. The witness-core proof from #21 (`U_B_iff_witness`) holds.
2. Read `OracleComplexity.lean` (`NP_A`, `AcceptsInTime`),`Oracle.lean`
   (Machine/step/Machine`),`OracleSmoke.lean` (a worked machine construction,
   listed in #26's Context as a model)). 
3. Probed directly in Lean (v4.31.0:
   - `example (n : Nat) : Fintype (Bits n) := by infer_instance` — **compiles**.
   - `example : Fintype Query := by infer_instance` — **fails:** 
     `failed to synthesize instance of type class Fintype ...Query`.
   - Wrote a transport argument `no_such_machine` (any `tm'` with `hΓ : tm'.Γ tm'.k₀ = Query`
     gives `False` via `Fintype Query` contradiction) — the remaining errors were only
     lemma-name/API frictions in the infinitude statement,not disagreements with the
     core finding (the refusal of `Fintype Query` synthesis is unambiguous,nd
     `tm'.Γ` field projection needs `FinTM2`-level namespace handling — irrelevant to
     the contradiction)..

 
---

## Resolution (2026-09-11, DEC-024)

**Chosen direction:** **Option Ω — word-query oracle substrate** (see `docs/decisions/LOG.md` DEC-024; work order #33, implementation #35`. The query is read from a **tape's content** (a finite word over the machine's own finite alphabet, per the spec's own "oracle tape" model — `docs/STATEMENTS/Oracle.lean.spec.md` §2.2), instead of fusing the query type into the input-alphabet slot. `Query = Σ n, Bits n` **stays unchanged**; no frozen statement changes shape; cost model (query = exactly 1 step), totality, `P^∅ = P`, andthe BGS counting all survive. Recorded options ((a) finite query family,and (c) per-length reindexing) become **unnecessary** — they solved the interface bug by bending the theorem. **Next:** #33 (v5 work-order spec,#35 (implementation,#36 (U_B-in-NP,#37 (diagonalization,#38 (campaign re-scope,#39 (audit,#40 (tests. This blocker file stays `status:blocked-needs-input` until #35 lands (the human decision is recorded;the substrate fix is agent work now).