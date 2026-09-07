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

 
## What is needed to unblockow

A human decision among (at least):

- **(a)** Change the oracle query type in #21's frozen `BGSDiagonal.lean` to a
  **finite** family,e.g. `Query := Fin N → Bool` for a fixed bound `N`, or a
  bounded union `Σ n : Fin N, Bits n`— but then the unary language `U_B` and
  `Bits n` per-input typing must be reworked,and the boundedness must be BGS-faithful.

- **(b)** Generalize the oracle substrate (`Oracle.lean`/`OracleComplexity.lean`)
  to allow **infinite input/query alphabets** (weaken/removed the `[Γk₀Fin : Fintype (Γ k₀)]`
  requirement, or add a non-finite variant of the machine model) — a substrate-
  level design change touching the v4 repair's invariants.

- **(c)** Rephrase the membership target not via `NP_A (alpha := Nat)B` but via a
  per-length finite-reindexed oracle (e.g. hangthe finiteness off the
  length-n input, making alpha = `Bits n` per a fixed n, with the query type the
  same per-length finite alphabet — changes the shape of the claimed language/
  DoD theorem,i.e. a new spec)...

Per the workflow's blocker quality bar, this is a **decision**, not a mechanism:
the contradiction is rigorous and Lean-verified, and I cite the exact definitions
involved — it cannot be resolved by agent guessing.Per `docs/MULTI_AGENT_WORKFLOW.md` §Blockers, I file this and move on, leaving #26 at
`status:blocked-needs-input`.