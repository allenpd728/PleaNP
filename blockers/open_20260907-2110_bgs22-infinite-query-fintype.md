# Blocker: #22 — BGS diagonalization inherits the infinite-Query Fintype wall from #26/#27

- **Task/issue attempted:** #22 (BGS (b) sub-task 2: diagonalization — construct oracle
  B and prove M_i^B fails U_B), run=20260907-2107-59bc.

- **Date:** 2026-09-07. Rule: agents must block on spec-level ambiguity that only the human
  can resolve, not on implementation choices. This is such a case: the
  diagonalization as stated is uninhabitable against the current substrate,
  and the resolution is a *decision* among documented options, not a mechanism.


## What information is missing

A **human decision** on the oracle-query alphabet (the same decision #26/#27
already await): #22's separating oracle B lives over `Query = Sigma n : Nat,
Bits n` (from the frozen `BGSDiagonal.lean`),but every deterministic
poly-time oracle machine in `P_A (alpha := Nat) B` quantifies via
`tm' : FinTM2` with the bundled field `[Γk₀Fin : Fintype (Γ k₀)]`
(Mathlib `Computability/TuringMachine/Computable.lean`),which must be
transportably equal to `Query`. `Fintype Query` is Lean-proved
uninhabitable ( `Nat` injects via all-false length-tagged strings)and
`Fintype (Bits n)` synthesizes for every fixed n, so the dichotomy is
exact (see `blockers/open_20260907-0953_bgs26-infinite-query-fintype.md`
for the full verified argument).. The diagonalization's *tournament*
(∃ n per machine with an unqueried-string choice) cannot run against
machines that cannot exist — and the class-inequality target
`P_A B != NP_A B` collapses (both classes are empty/inhabited identically
under the wall,so no separation..



## What I tried

1. Built the clean substrate (`lake build PleaNP.Barriers.BGSDiagonal
   PleaNP.Computability.OracleComplexity PleaNP.Computability.Oracle` —
   green)and re-verified the witness-core (#21) holds.
2. Read `Relativization.proof-strategy.md` §2 (the stage construction;if
   accepts leave empty for length-n;if rejects add an unqueried n-bit
   string),§5 open questions (machine enumeration, 2^n > p_i(n) counting,
   monotonicity).
3. Investigated the Mathlib hooks for the counting lemma and machine enumeration
   (`Algebra/Order/Archimedean/Basic.lean:158` pow_unbounded_of_one_lt;
   `Data/Nat/Choose/Bounds.lean:91` choose_lt_two_pow;
   `Computability/PartrecCode.lean` Code/evaln/evaln_complete/primrec_evaln
   — partial-recursive codes, not poly-time oracle machines,and no
   FinTM2-oracle machine encoding exists upstream)..
4. Wrote the decomposition design note
   `docs/STATEMENTS/Relativization.diagonalization-design.md` (committed
   56a58cc): D1-D6 (counting lemma, query reindex, machine enumeration,
   stage construction, tournament lemma, assembly),the substrate-wall
   recording,and the recommendation that D1 (pure Nat/Polynomial counting
   lemma) can start immediately,u naffected by the human decision.



## What is needed to unblock

The same human decision as #26/#27 (see that blocker file for options (a/b/c)):
- **(a)** Finite reindexed query family (e.g. `Bits (Fin N)` bounded, or
  per-length bounded `Bits n` with reworked unary language typing). BGS-faithfulness
  of the boundedness must be reviewed.
- **(b)** Generalize the oracle substrate to allow infinite alphabets (weaken/
  remove the bundled `[Fintype (Γ k₀)]` or add a non-finite machine variant) —
  a substrate-level design change touching the v4 repair's invariants.
- **(c)** Rephrase the class target per-length(alpha = `Bits n` per a fixed
  n, finite query alphabet per-length) — changes the shape of the claimed
  language/DoD theorem,needs its own Gate-1 review if chosen.



Per the workflow's blocker quality bar this is a **decision**, not a mechanism:
the contradiction is rigorous and Lean-verified,and I cite the exact bundled
field and the frozen Query type. Any query-family change (a/b/c) routes
through the design doc's decomposition (D2 reindexes, D3 enumerates,

the combinatorial core D1-D5 survives each option).. I file this and
move on, leaving #22 at`status:blocked-needs-input` (with this file linked
in the claim comment;the design doc records the recommendation scope for the
next session: D1 first, then D2-D6 in dependency order after #27 lands).