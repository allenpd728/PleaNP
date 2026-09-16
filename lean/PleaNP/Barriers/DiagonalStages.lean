import Mathlib
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# BGS diagonalization D4: monotone stage construction

The separating oracle `B` is built in stages `B_0 ⊆ B_1 ⊆ ...` so that
diagonalization at stage `k` is never undone by a later stage: once a
string is added to `B`, it stays. This module captures that invariant for
the PleaNP oracle-as-set presentation (`q ∈ B` iff `B q = true`), in the
same substrate-free spirit as `DiagonalCounting` / `DiagonalBits`.

The stage index is `Nat` (the machine index); the monotonicity invariant
is the load-bearing property the tournament needs: `B (k+1)` extends
`B k`. Membership is monotone in the stage — nothing is ever removed.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalStages

open PleaNP.Oracles

/-- `q` belongs to oracle `B` (as a set) iff `B` answers true. -/
def Mem (B : Oracle Q) (q : Q) : Prop := B q = true

/-- A stage chain is monotone: each stage extends the previous (the
  "diagonalization not undone" invariant). -/
def MonotoneChain {Q : Type} (B : Nat → Oracle Q) : Prop :=
  ∀ (k : Nat) (q : Q), Mem (B k) q → Mem (B (k+1)) q

/-- `Mem` on a chain is stable under taking a later stage. -/
lemma mem_mono_of {Q : Type} {B : Nat → Oracle Q} (hmono : MonotoneChain B)
    {k j : Nat} (hkj : k ≤ j) {q : Q} :
    Mem (B k) q → Mem (B j) q := by
  intro hq
  induction hkj with
  | refl => exact hq
  | step hkj ih =>
      exact hmono _ _ ih

/-- Membership is preserved from every stage into the limit: if `q ∈ B k`
  then `q` is in every later stage (in particular the maximal one). -/
lemma mem_preserved {Q : Type} {B : Nat → Oracle Q} (hmono : MonotoneChain B)
    (k : Nat) {j : Nat} (hkj : k ≤ j) (q : Q) :
    Mem (B k) q → Mem (B j) q := by
    intro hq
    exact mem_mono_of hmono hkj hq

/-- A stage chain is a chain of oracle *sets*: `B k ⊆ B (k+1)` pointwise.
  This is the set-extension form the design doc's `B_k ⊆ B_{k+1}` names. -/
lemma subset_chain {Q : Type} {B : Nat → Oracle Q} (hmono : MonotoneChain B)
    (k : Nat) : ∀ q : Q, Mem (B k) q → Mem (B (k+1)) q :=
  hmono k

/-- The empty oracle begins any chain (the `B_0 = ∅` starting stage). -/
def emptyChain (Q : Type) : Nat → Oracle Q := fun _ => emptyOracle Q

/-- `emptyChain` is monotone (trivially: nothing is ever in it). -/
lemma emptyChain_monotone (Q : Type) : MonotoneChain (emptyChain Q) := by
  intro k q hq
  simp [emptyChain, Mem, emptyOracle] at hq

/-- Building a chain one stage at a time: if `B` is monotone and `B' k`
  extends `B k` for every `k` compatibly, the union is monotone. Here we
  record the simplest form that the tournament will use: a stage function
  that only *adds* queries is monotone. `add : Q → Bool` marks the set of
  strings newly added at stage 1 (`add q = true`); anything added is true
  from then on (no Decidable instance needed on a bare Prop). -/
lemma add_stage_monotone {Q : Type} (add : Q → Bool) (B : Oracle Q) :
    MonotoneChain (fun k => if k = 0 then B else fun q => if add q then true else B q) := by
  intro k q hq
  by_cases hk0 : k = 0
  · -- B 0 -> B 1: adding `add` keeps `q` (it was in B)
    -- hk0: k = 0, so B k = B 0 = B (the un-extended oracle)
    have hB : B q = true := by
      simpa [hk0, Mem] using hq
    have hq1 : Mem (fun q => if add q = true then true else B q) q := by
      unfold Mem
      by_cases ha : add q = true <;> simp [ha, hB]
    simpa [hk0, Mem] using hq1
  · -- k > 0: B k is the or-extension; B (k+1) is the same extension
    simpa [hk0, Mem] using hq

end DiagonalStages

end Barriers

end PleaNP