import Mathlib
import PleaNP.Barriers.BGSDiagonal
import PleaNP.Barriers.DiagonalTournament
import PleaNP.Barriers.DiagonalStages

set_option warningAsError true

/-!
# BGS (b): the inductive stage oracle chain

The tournament constructs the separating oracle `B` in monotone stages
`B_0 ⊆ B_1 ⊆ ...`. This module instantiates the construction over the
real BGS `Query = Σ n, Bits n`: a stage function that, at each step,
either keeps the oracle unchanged or adds exactly one chosen string
(a point via `addPoint`). We prove the chain is monotone (the D4
invariant, "diagonalization not undone") and that any added point is a
permanent witness.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalChain

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal
open PleaNP.Barriers.DiagonalTournament

/-- One stage step: given the current oracle and a (possibly empty) chosen
  point, extend to the next stage. `none` = no addition (the machine's
  accept side); `some q` = add exactly the string q (the reject side). -/
def stepStage (B : Oracle Query) (choice : Option Query) : Oracle Query :=
  match choice with
  | none => B
  | some q => addPoint B q

/-- A chain from a list of per-stage choices: `B_0` is the empty oracle,
  and `B (k+1)` applies `stepStage` with the k-th choice to `B k`. -/
def stageChain (choices : List (Option Query)) : Nat → Oracle Query
  | 0 => emptyOracle Query
  | k + 1 => stepStage (stageChain choices k) (choices.getD k none)

/-- The empty oracle begins a stageChain (B_0 = ∅). -/
lemma stageChain_zero (choices : List (Option Query)) :
    stageChain choices 0 = emptyOracle Query := rfl

/-- A `some q` choice makes `q` a permanent member from that stage
  onward: the stepStage at the k-th stage adds q, and monotonicity keeps
  it (B k ⊆ B (k+1)). -/
lemma stepStage_added (B : Oracle Query) (q : Query) :
    stepStage B (some q) q = true := by
  simp [stepStage, addPoint]

/-- A `some q` step is monotone: nothing in B is lost by adding q. -/
lemma stepStage_mono (B : Oracle Query) (choice : Option Query) (q : Query)
    (hq : B q = true) : stepStage B choice q = true := by
  cases choice with
  | none => simpa [stepStage] using hq
  | some p => exact addPoint_mono B p q hq

/-- `addPoint` of a DIFFERENT point leaves B's answers unchanged (the
  machine-agreement fact the tournament needs). -/
lemma stepStage_agree_other (B : Oracle Query) (choice : Option Query)
    (q : Query) (h : q ∉ choice) : stepStage B choice q = B q := by
  cases choice with
  | none => rfl
  | some p =>
      have hq' : q ≠ p := by
        intro hq; apply h; simp [hq]
      exact addPoint_agree_other B _ _ _ hq'

end DiagonalChain

end Barriers

end PleaNP