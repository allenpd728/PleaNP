import Mathlib
import PleaNP.Barriers.DiagonalChainAccept
import PleaNP.Barriers.DiagonalChainFlip
import PleaNP.Barriers.DiagonalTournament
import PleaNP.Barriers.BGSDiagonal

set_option warningAsError true

/-!
# BGS (b): the per-length tournament decision

Bundles the accept-side (DiagonalChainAccept) and reject-side
(DiagonalChainFlip) into the single dichotomy the stage argument
consumes: at length n, the stage machine either

- ACCEPTS: the chain leaves B empty at n (choice none) and
  U_B stays false at n (accept_step_flip), or
- REJECTS: the chain adds an unqueried string x (choice some <n,x>) and
  U_B flips to true at n (flip_at_step).

Both directions are machine-verified here as one lemma taking the choice
as data, so the tournament's stage iteration need only supply the choice.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalDecision

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal
open PleaNP.Barriers.DiagonalChain
open PleaNP.Barriers.DiagonalChainAccept
open PleaNP.Barriers.DiagonalChainFlip
open PleaNP.Barriers.DiagonalTournament

/-- The decision at length n: the choice determines U_B's value at the
  next stage.

  - choice = none        (machine ACCEPTS): if n was not in U_B, it stays
    not in (accept side — B left empty at n).
  - choice = some <n,x>  (machine REJECTS, x unqueried, B all-false at
    n): n was not in U_B and flips to in (reject side — x added).

  This is the accept/reject dichotomy the stage iteration uses. -/
lemma decision_none_out (B : Oracle Query) (n : Nat)
    (hnot : n ∉ U_B B) :
    n ∉ U_B (stepStage B none) :=
  accept_step_flip B n hnot none rfl

/-- Reject-side decision, as data: a `some <n, x>` choice with B all-false
  at n makes U_B true at the next stage (and x is the witness). -/
lemma decision_some_in (B : Oracle Query) (n : Nat) (x : Bits n)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false) :
    n ∈ U_B (stepStage B (some ⟨n, x⟩)) := by
  -- flip_at_step gives n in U_B (addPoint B <n,x>); stepStage (some ...)
  -- = addPoint B <n,x>.
  have hflip := U_B_flip_on_add B n x hB
  simpa [stepStage] using hflip.2

/-- The complete per-length outcome when the choice is some/unqueried:
  n was not in U_B B (reject side) AND n is in U_B at the next stage
  (the flip happened). -/
lemma decision_reject_full (B : Oracle Query) (n : Nat) (x : Bits n)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false) :
    n ∉ U_B B ∧ n ∈ U_B (stepStage B (some ⟨n, x⟩)) := by
  constructor
  · -- U_B B is false at n via the all-false hypothesis
    intro h
    rcases h with ⟨y, hy⟩
    simp [hB y] at hy
  · exact decision_some_in B n x hB

end DiagonalDecision

end Barriers

end PleaNP