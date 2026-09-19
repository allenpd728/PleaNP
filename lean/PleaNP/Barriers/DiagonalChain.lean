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
open PleaNP.Barriers.DiagonalStages

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

/-! ## The D4 invariant over the concrete chain (issue #37, D4 close-out)

`DiagonalStages` defines `MonotoneChain` (the "diagonalization not undone"
invariant) abstractly and proves it is preserved by an add-step. What was
missing is that the *concrete* `stageChain` built from a per-stage choice
list actually satisfies it: every stage is monotone in the next, so a
witness added at stage `k` is permanent from `k` onward. These lemmas
connect the two — the load-bearing D4 property the tournament iterates —
and are what `DiagonalChainFlip`'s per-step results lift to the whole
chain. -/

/-- **One-step monotonicity of the concrete chain.** Any query answered
  `true` at stage `k` is still `true` at stage `k+1`: the step either
  keeps the oracle (`none`) or adds a point (`some`), and neither removes
  a membership. -/
lemma stageChain_step_mono (choices : List (Option Query)) (k : Nat) (q : Query)
    (hq : stageChain choices k q = true) :
    stageChain choices (k + 1) q = true := by
  have hstep : stageChain choices (k + 1)
      = stepStage (stageChain choices k) (choices.getD k none) := rfl
  rw [hstep]
  exact stepStage_mono (stageChain choices k) _ q hq

/-- **The concrete chain is a `MonotoneChain`** (the D4 invariant, for the
  actual `B_k ⊆ B_{k+1}` construction rather than the abstract stage
  function). This is the bridge from the `DiagonalStages` abstraction to
  the `DiagonalChain` construction the tournament walks. -/
theorem stageChain_monotone (choices : List (Option Query)) :
    MonotoneChain (stageChain choices) := by
  intro k q hq
  exact stageChain_step_mono choices k q hq

/-- **Permanence over the chain.** A query answered `true` at stage `k`
  stays `true` at every later stage `j ≥ k` — the "nothing is undone"
  guarantee lifted from one step to the whole tail. This is what makes an
  added witness permanent for the rest of the diagonalization. Derived
  from the abstract `DiagonalStages.mem_mono_of` at the concrete chain's
  monotonicity instance, so the abstraction and the construction are tied
  together rather than proved twice. -/
lemma stageChain_mem_persist (choices : List (Option Query)) {k j : Nat}
    (hkj : k ≤ j) (q : Query) (hq : stageChain choices k q = true) :
    stageChain choices j q = true :=
  mem_mono_of (stageChain_monotone choices) hkj hq

/-- **A `some` choice is permanent from its stage onward.** If the `k`-th
  choice adds a point `q`, then `q` is answered `true` from stage `k+1`
  through every later stage — the chain-flavoured form of
  `DiagonalChainFlip`'s permanence, tying the choice list to membership. -/
lemma stageChain_added_persist (choices : List (Option Query)) {k j : Nat}
    (q : Query) (hk : choices.getD k none = some q) (hkj : k + 1 ≤ j) :
    stageChain choices j q = true := by
  have hk1 : stageChain choices (k + 1) q = true := by
    have hstep : stageChain choices (k + 1)
        = stepStage (stageChain choices k) (choices.getD k none) := rfl
    rw [hstep, hk]
    exact stepStage_added (stageChain choices k) q
  exact stageChain_mem_persist choices hkj q hk1

/-! ### Agreement: a machine that never queried the added point cannot tell

The tournament's soundness leans on the stage machine seeing the same
answers before and after a stage that adds a point the machine did not
query. `DiagonalChainFlip.reject_step_flip` gives this for one step; here
we give the tail version over the concrete chain: if the machine's query
`q` is *never* chosen by any stage from `k` on, its answer at every later
stage equals its answer at `k`. -/

/-- **Tail agreement.** If no stage from `k` onward chooses `q`, then
  `q`'s answer never changes over the tail: `stageChain (j+1) q` equals
  `stageChain j q` for every stage `j` at or beyond `k`. Composing this
  gives the machine-agreement fact the tournament's "unchanged behaviour"
  claim rests on. -/
lemma stageChain_tail_agree (choices : List (Option Query)) (k : Nat)
    (q : Query) (hnone : ∀ i, k ≤ i → choices.getD i none ≠ some q) :
    ∀ j, k ≤ j → stageChain choices (j + 1) q = stageChain choices j q := by
  intro j hj
  have hstep : stageChain choices (j + 1)
      = stepStage (stageChain choices j) (choices.getD j none) := rfl
  rw [hstep]
  -- The step's choice is not `some q`, so either `none` (identity) or
  -- `some p` with `p ≠ q` (addPoint leaves q alone).
  cases hc : choices.getD j none with
  | none => rfl
  | some p =>
      have hpq : p ≠ q := by
        intro hpq
        exact hnone j hj (by rw [hc, hpq])
      exact stepStage_agree_other (stageChain choices j) (some p) q (by simpa using hpq)

end DiagonalChain

end Barriers

end PleaNP