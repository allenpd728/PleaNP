import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec
set_option warningAsError true

/-!
# Relativization (Baker-Gill-Solovay, 1975)

This file renders the **frozen statement** of the Baker-Gill-Solovay
relativization theorem — the Gate-1 anchor for Rung 3a. The statement
is rendered against `P^A`/`NP^A` from `OracleComplexity.lean`. The
*proof* is Rung 3 Step 6 work (blocked on upstream P/NP + PSPACE).

See `docs/STATEMENTS/Relativization.md` (the informal frozen spec) and
`docs/STATEMENTS/Relativization.lean.spec.md` (the rendering spec).

Status: Rendered (statement only; proof = `sorry` placeholders).
Both clauses type-check. The `sorry` is honest (Gate 6 catches it in
render-stage; allowed per the workflow).

Three rendering traps (per the rendering spec):
- Trap 1 (computability hypothesis): both witnesses carry an explicit
  `Computable` hypothesis (non-triviality — without it the statement
  is trivially true).
- Trap 2 (set equality): P^A/NP^A are `Set (Set α)`, so `=` is set
  extensional equality (consistent with OracleComplexity.lean Trap 3).
- Trap 3 (query type): Q = `List Bool` (concretely instantiated and
  recorded — the standard bitstring query space).
-/

namespace PleaNP

namespace Barriers

namespace Relativization

open Oracles

/-!
## The query type and input type

Per rendering spec Trap 3: the query type Q is concretely instantiated
as `List Bool` (bitstrings) — the standard query space for complexity
theory. The input type α is also `List Bool` (languages are over
bitstrings). Both are recorded here for Gate 4 read-back consistency.
-/

/-- The query type: bitstrings. The oracle answers questions about
  bitstrings. -/
abbrev QueryType := List Bool

/-- The input type: bitstrings. Languages are sets of bitstrings. -/
abbrev InputType := List Bool

/-!
## Clause (a) — the equalizing oracle

There exists a total, computable oracle A such that P^A = NP^A.

Per Relativization.md §3:
- The oracle is existential and total (Oracle Q := Q → Bool).
- The oracle is recursive (Computable hypothesis — Trap 1).
- P^A = NP^A is set extensional equality (Trap 2).
-/

/-- **Baker-Gill-Solovay clause (a):** there exists a total, computable
  oracle A such that P^A = NP^A (the classes are equal as sets).

  The oracle is `Oracle QueryType` (= `List Bool → Bool`), which is
  total by construction. The `Computable` hypothesis ensures the
  witness is recursive (Trap 1: without it, the statement is trivially
  true — a noncomputable oracle can collapse the classes).

  The equality `P_A A = NP_A A` is set extensional equality of two
  `Set (Set InputType)` values (Trap 2: consistent with
  OracleComplexity.lean's presentation). -/
theorem exists_equalizing_oracle :
    ∃ (A : Oracle QueryType),
      Computable (α := QueryType) A ∧
      P_A (α := InputType) A = NP_A (α := InputType) A := by
  sorry

/-!
## Clause (b) — the separating oracle

There exists a total, computable oracle B such that P^B ≠ NP^B.

Same constraints as clause (a): total oracle, computable witness,
set extensional inequality.
-/

/-- **Baker-Gill-Solovay clause (b):** there exists a total, computable
  oracle B such that P^B ≠ NP^B (the classes are unequal as sets).

  Same structural constraints as clause (a): the oracle is total
  (`Oracle QueryType`), the witness is computable (`Computable`
  hypothesis), and the inequality is set extensional. -/
theorem exists_separating_oracle :
    ∃ (B : Oracle QueryType),
      Computable (α := QueryType) B ∧
      P_A (α := InputType) B ≠ NP_A (α := InputType) B := by
  sorry

/-!
## What is NOT defined here (and why)

- The *proof* of BGS: that's Rung 3 Step 6, blocked on upstream P/NP
  (DEC-003) and PSPACE/QBF (clause (a) sandwich).
- The *barrier consequence* (relativizing proofs can't separate P
  from NP): a derived corollary, rendered later per Relativization.md §3.
- PSPACE, QBF: proof-strategy dependencies, not statement dependencies.
-/

end Relativization

end Barriers

end PleaNP
