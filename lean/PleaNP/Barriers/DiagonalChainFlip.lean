import Mathlib
import PleaNP.Barriers.DiagonalChain
import PleaNP.Barriers.DiagonalTournament
import PleaNP.Barriers.DiagonalStages

set_option warningAsError true

/-!
# BGS (b): the reject-side flip over the stage chain

Composes the inductive stage chain (DiagonalChain) with the tournament
flip (DiagonalTournament): when the stage machine at length n has an
all-false stage oracle (every length-n string answered 'no') and the
stage's choice is `some ⟨n, x⟩` for an unqueried x, then the chain's
U_B flips from false to true at stage k+1 (and stays true, by
monotonicity, at every later stage).

This is the tournament's reject-side evolution, made precise over the
concrete stageChain.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalChainFlip

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal
open PleaNP.Barriers.DiagonalChain
open PleaNP.Barriers.DiagonalTournament

/-- The reject-side step lemma: if `B` is all-false at length n (the
  strong all-'no' stage state) and the chain's next choice is
  `some ⟨n, x⟩`, then the chain adds x and U_B flips: n was not in
  U_B B, and is now in U_B (B' = addPoint B ⟨n,x⟩). -/
lemma flip_at_step (B : Oracle Query) (n : Nat) (x : Bits n)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false)
    (choice : Option Query) (hchoice : choice = some ⟨n, x⟩) :
    n ∉ U_B B ∧ n ∈ U_B (stepStage B choice) := by
  subst choice
  have hflip := U_B_flip_on_add B n x hB
  constructor
  · exact hflip.1
  · simpa [stepStage] using hflip.2

/-- The permanent consequence: once a length-n witness exists (at stage
  k+1), it remains a witness at every later stage (monotonicity of the
  chain — "diagonalization not undone"). Stated for the one-step
  extension: adding x to B keeps n ∈ U_B (B') at the next stage. -/
lemma witness_permanent (B : Oracle Query) (n : Nat) (x : Bits n)
    (choice : Option Query) (hchoice : choice = some ⟨n, x⟩) :
    n ∈ U_B (addPoint B ⟨n, x⟩) → n ∈ U_B (stepStage B choice) := by
  subst choice
  intro h
  simpa [stepStage] using h

/-- The two-sided flip over a chain step, bundled: the reject-side
  machinery. If B is all-false at n and the choice adds an unqueried x,
  then (i) the machine's stage oracle is unchanged on every other query
  (agreement — the machine can't tell), and (ii) U_B flips to true at n.
  This is the load-bearing step the diagonalization iterates. -/
lemma reject_step_flip (B : Oracle Query) (n : Nat) (x : Bits n)
    (q : Query) (hneq : q ≠ ⟨n, x⟩) :
    stepStage B (some ⟨n, x⟩) q = B q := by
  simpa [stepStage] using addPoint_agree_other B n x q hneq

end DiagonalChainFlip

end Barriers

end PleaNP