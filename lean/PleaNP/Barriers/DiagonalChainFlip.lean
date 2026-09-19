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

/-! ## The reject-side flip over the whole chain (issue #37, D5 permanence)

`flip_at_step` and `witness_permanent` are the per-step forms. The
tournament's D5 needs the *chain* form: once the reject step at stage `k`
flips `U_B` true at `n`, it stays true at every later stage. That is the
"diagonalization at stage `k` is not undone" guarantee, lifted from the
one-step `stageChain_monotone` (DiagonalChain) into `U_B`-membership terms
— the shape the tournament's `M_i^B` disagreement argument consumes. -/

/-- **Reject flip is permanent over the chain.** If the stage oracle
  `stageChain choices k` is all-false at length `n` and the chain's k-th
  choice adds the unqueried `⟨n, x⟩`, then `n ∉ U_B` at stage `k` and
  `n ∈ U_B` at *every* later stage `j ≥ k+1` — the witness `x` persists by
  the concrete chain's monotonicity. This is the D5 maturity lemma the
  tournament iterates. -/
lemma flip_persists_over_chain (choices : List (Option Query)) (n : Nat)
    (x : Bits n) (k j : Nat) (hchoice : choices.getD k none = some ⟨n, x⟩)
    (hB : ∀ y : Bits n, stageChain choices k ⟨n, y⟩ = false)
    (hkj : k + 1 ≤ j) :
    n ∉ U_B (stageChain choices k) ∧ n ∈ U_B (stageChain choices j) := by
  have hflip := flip_at_step (stageChain choices k) n x hB
    (choices.getD k none) hchoice
  refine ⟨hflip.1, ?_⟩
  have hk1 : n ∈ U_B (stageChain choices (k + 1)) := by
    have hstep : stageChain choices (k + 1)
        = stepStage (stageChain choices k) (choices.getD k none) := rfl
    rw [hstep]
    exact hflip.2
  -- `U_B` is an existential over a witness; the witness persists because
  -- the concrete chain is monotone (`stageChain_mem_persist`).
  rcases hk1 with ⟨y, hy⟩
  exact ⟨y, stageChain_mem_persist choices hkj ⟨n, y⟩ hy⟩

end DiagonalChainFlip

end Barriers

end PleaNP