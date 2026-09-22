import Mathlib
import PleaNP.Barriers.DiagonalTournament
import PleaNP.Barriers.DiagonalEnum
import PleaNP.Barriers.BGSDiagonal
import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-!
# BGS (b) assembly — the tournament over the enumeration

The final BGS clause-(b) step: assemble `∃ B, P_A B ≠ NP_A B`. The
substrate is in place (D1 counting, D5 unqueried, D4 stage,
D5-tournament flip, D3 enumeration). This module records the assembly's
shape and the one missing reduction, honestly.

Honest gap (design doc §3.2, #23): `Partrec.Code` enumerates
partial-recursive programs. A poly-time oracle machine (the `P_A`-witness
`Machine`) must be converted to a `Code` before the tournament's
`M_of i` diagonalization applies to it. The standard escape (which the
tournament uses): enumerate ALL codes; the diagonalization either
simulates a machine within its step window or punts slow/unrelated ones
to a filler input. This module fixes the pieces that ARE provable and
states the final theorem as the target.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalAssembly

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal
open PleaNP.Barriers.DiagonalEnum
open PleaNP.Barriers.DiagonalStages
open PleaNP.Barriers.DiagonalTournament

/-- The tournament's decision at index `i`: run the `i`-th program
  (M_of i) for `k` bounded steps on input `n`. This is the "simulate
  M_i for p(n) steps" step over the enumeration. -/
def Simulate (i k n : Nat) : Option Nat :=
  Nat.Partrec.Code.evaln k (M_of i) n

/-- The usable case: when the bounded simulation RETURNS a value, it is
  the program's genuine partial output (the tournament simulates M_i
  within its window and reads the decision). -/
lemma simulate_returns {i k n r} (h : Simulate i k n = some r) :
    r ∈ Nat.Partrec.Code.eval (M_of i) n :=
  evaln_mem_eval (h := h)

/-- **Window stability.** If the `i`-th program returns `r` within `k₁`
  steps, it still returns `r` within any larger window `k₂`. This is the
  fact that makes the simulate-or-punt step well defined: a decision the
  tournament reads inside its window is *stable* — it cannot be un-decided
  by extending the window, so the diagonalization's "read M_i's answer
  within p(n)" is not an artifact of the cutoff. -/
lemma simulate_mono {i k₁ k₂ n r} (h : Simulate i k₁ n = some r) (hk : k₁ ≤ k₂) :
    Simulate i k₂ n = some r := by
  unfold Simulate
  exact Option.mem_def.mp
    (Nat.Partrec.Code.evaln_mono (c := M_of i) (n := n) hk (Option.mem_def.mpr h))

/-- **The window must exceed the input length.** A program that has
  returned within `k` steps was run on an input `n < k` (Mathlib's
  `evaln_bound`). Consequence for the punting strategy: `Simulate i k n`
  can only decide inputs strictly shorter than its window, so "punt"
  (`PuntsSlow`) is the only possible outcome for `n ≥ k` — the filler-input
  side of the simulate-or-punt split. -/
lemma simulate_bound {i k n r} (h : Simulate i k n = some r) : n < k := by
  unfold Simulate at h
  exact Nat.Partrec.Code.evaln_bound (Option.mem_def.mpr h)

/-- The punting strategy made precise: a machine the tournament does NOT
  simulate to a decision within its window is "slow for this window", and
  the diagonalization is free to use a filler input for it. `evaln = none`
  is exactly "no decision within k steps". -/
def PuntsSlow (i k n : Nat) : Prop :=
  Simulate i k n = none

/-- Contrapositive form of `simulate_bound`: any input at or beyond the
  window length is necessarily punted — the tournament's filler-input case
  is forced, not chosen. -/
lemma punts_of_le_window {i k n : Nat} (hn : k ≤ n) : PuntsSlow i k n := by
  unfold PuntsSlow Simulate
  cases h : Nat.Partrec.Code.evaln k (M_of i) n with
  | none => rfl
  | some r => exact absurd (Nat.Partrec.Code.evaln_bound (Option.mem_def.mpr h)) (not_lt.mpr hn)

/-- Solved-by-substrate fact that the tournament hands off: with fewer
  than 2^n queries, an unqueried string exists and adding it flips U_B.
  (Restated here as the assembly's handle on the D5/D4 machinery.) -/
theorem stage_step_exists (n : Nat) (s : Finset (Bits n))
    (hs : s.card < 2 ^ n) (B : Oracle Query)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false) :
    ∃ x : Bits n, x ∉ s ∧ n ∉ U_B B ∧ n ∈ U_B (addPoint B ⟨n, x⟩) :=
  tournament_flip s hs B hB

/-- The final BGS clause-(b) target. Honest statement (sorry-scaffold,
  tracked in SORRY_TRACKER per repo convention): the proof needs the
  `Machine → Code` bridge (#23/#97 gap) plus the stage/tournament
  composition. Q is the BGS query type `Σ n, Bits n`. -/
theorem exists_separating_oracle_assembly :
    ∃ B : Oracle Query, P_A (alpha := Nat) B ≠ NP_A (alpha := Nat) B := by
  sorry

end DiagonalAssembly

end Barriers

end PleaNP