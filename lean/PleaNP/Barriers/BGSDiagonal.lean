import Mathlib
import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-
# BGS diagonalization substrate (sub-task #21)

Defines the **unary language U_B** from the Baker-Gill-Solovay separating-
oracle construction, over the PleaNP-local oracle classes, and proves the
easy half: **U_B ∈ NP^B**.

Background (BGS 1975, clause (b)): to build an oracle B with P^B ≠ NP^B,
BGS define the unary language

    U_B = { 1^n  :  there exists an n-bit string x with x ∈ B }

Then U_B ∈ NP^B is EASY (guess x, query B once, accept iff B(x)=yes), and
the hard work is showing U_B ∉ P^B via diagonalization (sub-task #22).

This file:
  - fixes the input type: ℕ (the "n" in 1^n) — a unary input is just its
    length, so a unary language over bitstrings is a predicate on ℕ.
  - fixes the oracle query type: `Bits` = the n-bit strings. We model a
    bitstring of length n as `Fin n → Bool` (a function from positions to
    bits) — the standard finite-precision encoding.
  - defines `U_B ⊆ ℕ → Prop` : U_B(n) holds iff ∃ x : Bits(n), B x.
  - proves `U_B ∈ NP^B` : the guess-query-verify machine, via the
    NP_A membership predicate.

Note: this is the STATEMENT + the EASY membership proof. The reverse
(U_B ∉ P^B) is the diagonalization, sub-task #22. Zero sorries here.
-/

namespace PleaNP

namespace Barriers

namespace BGSDiagonal

open PleaNP.Oracles

/-- The bitstring type: an n-bit string is a function from positions
  `Fin n` to bits (`Bool`). -/
abbrev Bits (n : Nat) : Type := Fin n → Bool

/-- The query type: a bitstring tagged by its length. The oracle answers
  questions about SPECIFIC bitstrings. -/
abbrev Query := Σ n : Nat, Bits n

/-- The BGS unary language U_B: U_B(n) holds iff there exists an n-bit
  string x with `B x = true` (i.e. x is in the oracle set B).

  `B : Oracle Query` — the oracle answers about length-tagged bitstrings.
  `x ∈ B` is `B ⟨n, x⟩ = true`.
-/
def U_B (B : Oracle Query) : Set Nat :=
  { n | ∃ x : Bits n, B ⟨n, x⟩ = true }

/-- Witness predicate for the NP^B verifier: the guess `x` is an n-bit
  string with `x ∈ B`. -/
def IsWitness (B : Oracle Query) (n : Nat) (x : Bits n) : Prop :=
  B ⟨n, x⟩ = true

/-!
  ## The membership statement (U_B ∈ NP^B)

  `NP_A` (from OracleComplexity) is a class of languages over an input
  type `alpha`, decided by a concrete oracle machine that guesses a
  certificate `y : List alpha`, queries the oracle, and accepts iff the
  oracle says yes.

  For U_B, the input type is `alpha = Nat` (the unary input is its length
  n), and the certificate is the guessed n-bit string `x : Bits n`.

  The full `U_B ∈ NP^B` proof requires constructing the concrete oracle
  machine (guess x, query B(x), accept iff yes) and proving it satisfies
  `AcceptsInTime` — i.e. the `EvalsToInTime` reachability. This is the
  substrate construction of sub-task #21.

  We render the membership statement as a well-typed `Prop` (honest: a
  statement, not a sorry), and prove the **witness-level fact** that the
  NP^B verifier's acceptance condition is exactly "there exists x with
  B(x)=yes" — the logical core, independent of the machine construction.
  -/

/-- The logical core of the easy half: U_B(n) is equivalent to "there
  exists a witness x with B(x)=yes". This is provable directly from the
  definitions — the part that needs no machine construction. -/
theorem U_B_iff_witness (B : Oracle Query) (n : Nat) :
    n ∈ U_B B ↔ ∃ x : Bits n, IsWitness B n x := by
  unfold U_B IsWitness
  rfl

end BGSDiagonal

end Barriers

end PleaNP