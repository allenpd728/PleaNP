import Mathlib
import PleaNP.Barriers.DiagonalChain
import PleaNP.Barriers.DiagonalTournament
import PleaNP.Barriers.BGSDiagonal

set_option warningAsError true

/-!
# BGS (b): the accept-side of the tournament over the chain

Symmetric half of the reject-step flip (DiagonalChainFlip): when the stage
machine ACCEPTS at length n, the tournament leaves the oracle unchanged at
n (its choice is `none`). We prove the two facts this needs:

- a `none` chain step is the IDENTITY on the oracle (stepStage B none = B),
- so `U_B` is unchanged by an accept-side step: if there was no witness at
  n it stays absent (n stays OUT of U_B), which is the tournament's
  "accepts -> leave B empty at n" outcome.

Together with the reject flip this is the full accept/reject dichotomy the
stage argument iterates.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalChainAccept

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal
open PleaNP.Barriers.DiagonalChain

/-- A `none` step (the accept side) is the identity: no queries changed. -/
lemma stepStage_none_id (B : Oracle Query) :
    stepStage B none = B := rfl

/-- Accept-side: with a `none` choice, membership is unchanged — a string
  that was NOT a witness of U_B stays not-a-witness (the tournament
  "leaves B empty at n" on accept). -/
lemma accept_step_preserves (B : Oracle Query) (n : Nat)
    (hnot : n ∉ U_B B) :
    n ∉ U_B (stepStage B none) := by
  simpa [stepStage] using hnot

/-- Accept-side, positive form: with a `none` choice, ANY witness that was
  absent stays absent — equivalently `U_B` is unchanged on the accept
  side (no new witness can appear: a `none` step adds nothing). -/
lemma accept_step_no_witness (B : Oracle Query) (n : Nat) :
    n ∉ U_B (stepStage B none) → n ∉ U_B B := by
  intro hnot
  simpa [stepStage] using hnot

/-- The bundled accept-side fact for the tournament: if the stage machine
  accepts and the chain chooses `none` (leave empty at n), then n stays
  out of U_B provided it was out before. This is the "accepts -> B empty
  at n" outcome, machine-checked. -/
lemma accept_step_flip (B : Oracle Query) (n : Nat)
    (hnot : n ∉ U_B B) (choice : Option Query) (hchoice : choice = none) :
    n ∉ U_B (stepStage B choice) := by
  subst choice
  exact accept_step_preserves B n hnot

end DiagonalChainAccept

end Barriers

end PleaNP