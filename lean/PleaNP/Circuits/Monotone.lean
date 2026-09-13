import PleaNP.Circuits.Basic

set_option warningAsError true

/-!
# Monotone circuits (issue #74 Pass 1)

The monotone-circuit model for the Rung-4 Razborov CLIQUE lower bound and
its #73 classification. A **monotone circuit** uses only `AND`/`OR` gates —
no `NOT` — which makes the computed Boolean functions order-preserving on
the `false < true` lattice. That order-preservation is the defining
structural property Razborov's bound exploits (a monotone circuit computing
CLIQUE must be large).

Pass 1 (this module): the monotone gate basis with its semantics, the
structural size/depth measures, the **monotonicity theorem** (evaluation
preserves the assignment order — the model's defining content), and the
family shape. Pass 2 is the approximation-reducer lemma; Pass 3 assembles
the CLIQUE bound.
-/

namespace PleaNP

namespace Circuits

/-- A **monotone Boolean gate** over `n` inputs: an input bit or an AND/OR
  gate over sub-terms. Crucially there is NO `not` constructor — negation is
  structurally inexpressible, which is exactly what "monotone" means here
  (the type is the guarantee, not a side condition). -/
inductive MonotoneGate (n : Nat) where
  | input (i : Fin n)
  | and (a b : MonotoneGate n)
  | or (a b : MonotoneGate n)
  deriving DecidableEq

namespace MonotoneGate

/-- **Evaluation** of a monotone gate on an assignment: input reads its
  variable, AND/OR apply the Boolean operation. -/
def eval : {n : Nat} → MonotoneGate n → (Fin n → Bool) → Bool
  | _, input i, v => v i
  | _, and a b, v => eval a v && eval b v
  | _, or a b, v => eval a v || eval b v

/-- **Size** (gate count) by structural recursion — the quantity Razborov's
  lower bound says must be exponential for CLIQUE. -/
def size : {n : Nat} → MonotoneGate n → Nat
  | _, input _ => 1
  | _, and a b => 1 + size a + size b
  | _, or a b => 1 + size a + size b

/-- **Depth** by structural recursion. -/
def depth : {n : Nat} → MonotoneGate n → Nat
  | _, input _ => 0
  | _, and a b => 1 + max (depth a) (depth b)
  | _, or a b => 1 + max (depth a) (depth b)

lemma size_pos {n : Nat} (g : MonotoneGate n) : 0 < size g := by
  cases g <;> simp [size]

end MonotoneGate

/-- The `false < true` order on `Bool` (the monotonicity lattice). -/
def BoolBoolLe (a b : Bool) : Prop :=
  a = false ∨ b = true

/-- AND preserves the `false < true` order. -/
lemma and_preserves_order (a₁ a₂ b₁ b₂ : Bool)
    (h₁ : BoolBoolLe a₁ a₂) (h₂ : BoolBoolLe b₁ b₂) :
    BoolBoolLe (a₁ && b₁) (a₂ && b₂) := by
  unfold BoolBoolLe at h₁ h₂ ⊢
  cases a₁ <;> cases b₁ <;> simp_all

/-- OR preserves the `false < true` order. -/
lemma or_preserves_order (a₁ a₂ b₁ b₂ : Bool)
    (h₁ : BoolBoolLe a₁ a₂) (h₂ : BoolBoolLe b₁ b₂) :
    BoolBoolLe (a₁ || b₁) (a₂ || b₂) := by
  unfold BoolBoolLe at h₁ h₂ ⊢
  cases b₁ <;> cases a₁ <;> simp_all

/-- **Monotonicity (the model's defining theorem):** evaluating a monotone
  gate on a pointwise-ordered assignment preserves the order — a monotone
  circuit computes an order-preserving (monotone) Boolean function.  This
  is the structural property Razborov's CLIQUE bound exploits: no monotone
  circuit can "detect" a missing edge by negation, forcing exponential
  size. -/
theorem monotone_eval_preserves_order {n : Nat} (g : MonotoneGate n)
    {v v' : Fin n → Bool} (hv : ∀ i : Fin n, BoolBoolLe (v i) (v' i)) :
    BoolBoolLe (MonotoneGate.eval g v) (MonotoneGate.eval g v') := by
  induction g with
  | input i => simpa [MonotoneGate.eval] using (hv i)
  | and a b iha ihb =>
      simpa [MonotoneGate.eval] using
        (and_preserves_order (MonotoneGate.eval a v) (MonotoneGate.eval a v')
          (MonotoneGate.eval b v) (MonotoneGate.eval b v') iha ihb)
  | or a b iha ihb =>
      simpa [MonotoneGate.eval] using
        (or_preserves_order (MonotoneGate.eval a v) (MonotoneGate.eval a v')
          (MonotoneGate.eval b v) (MonotoneGate.eval b v') iha ihb)

/-- A **monotone circuit family** (P/poly-shaped): one monotone circuit per
  input length. -/
abbrev MonotoneFamily := ∀ n : Nat, MonotoneGate n

/-- The family size at length n. -/
def MonotoneFamily.sizeOf (C : MonotoneFamily) (n : Nat) : Nat :=
  MonotoneGate.size (C n)

/-! ## Concrete sanity (substrate self-exercise) -/

/-- The `x0 ∧ x1` monotone gate (size 3: AND + 2 inputs). -/
def monAnd2 : MonotoneGate 2 :=
  MonotoneGate.and (MonotoneGate.input 0) (MonotoneGate.input 1)

example : MonotoneGate.size monAnd2 = 3 := by
  simp [monAnd2, MonotoneGate.size]

example : MonotoneGate.eval monAnd2 (fun _ : Fin 2 => true) = true := by
  simp [monAnd2, MonotoneGate.eval]

end Circuits

end PleaNP
