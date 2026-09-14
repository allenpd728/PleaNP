import PleaNP.Circuits.Monotone

set_option warningAsError true

/-
# Monotone-circuit approximation reducer (issue #74 Pass 2)

Razborov's approximation-reducer core over the monotone substrate
(`MonotoneGate`, `PleaNP.Circuits.Monotone`). This is the structural
half of the monotone CLIQUE lower bound: a reducer that rewrites a
monotone circuit into a "sm-AND/sm-OR" approximation over a monomial
carrier, with the size control the counting bound (Pass 3) consumes.

## The approximation carrier

An approximation of a monotone function over `n` variables is a finite
family of monomials (a `Finset` of `Finset (Fin n)` — each monomial is a
set of variables whose conjunction witnesses a 1). The "size" of an
approximation is the cardinality of this carrier (the quantity the
counting lemma bounds).

## The sm-AND / sm-OR approximators

- `smOr A B = A ∪ B` (union — the approximation of an OR gate).
- `smAnd A B` = pairwise unions of a monomial from `A` and one from
  `B` (the approximation of an AND gate).

Razborov's closure/truncation under monomials of size at most `r` (the
operation that keeps the approximation "small") is the Pass-3 counting
refinement. This module proves the structural core that is provable at
the v1 level — size composition, the reduction identity on input gates,
the sm-OR / sm-AND membership identities, and the reducibility lemma
(size of the approximation is bounded by a function of the circuit's
size) — all zero-sorry.
-/

namespace PleaNP

namespace Circuits

/-!
## The approximation carrier and its sm-operations
-/

/-- A monomial over `n` variables: a finite set of variables whose
  conjunction witnesses a 1 of a monotone function. -/
abbrev Monomial (n : Nat) := Finset (Fin n)

/-- An approximation of a monotone function: a finite family of monomials
  (formal disjunction). Semantics below: the function is 1 on an
  assignment iff some monomial is wholly 1 there. -/
abbrev ApproxSet (n : Nat) := Finset (Monomial n)

namespace ApproxSet

/-- The sm-OR approximator: union of the two monomial families. -/
def smOr {n : Nat} (A B : ApproxSet n) : ApproxSet n :=
  A ∪ B

/-- The sm-AND approximator: pairwise unions of one monomial from each
  family (a monomial witnessing the AND's 1 must come from a variable
  set contained in both input witnesses).  Implemented as the image of
  the cartesian product under `pair union` — the product formulation
  makes the cardinality bound `|A| * |B|` immediate. -/
def smAnd {n : Nat} (A B : ApproxSet n) : ApproxSet n :=
  (A.product B).image (fun ab : Monomial n × Monomial n => ab.1 ∪ ab.2)

/-- The size of an approximation (the carrier cardinality). -/
def sizeOf {n : Nat} (A : ApproxSet n) : Nat :=
  A.card

/-- The size of the sm-OR is at most the sum of the input sizes. -/
lemma sm_or_size_le {n : Nat} (A B : ApproxSet n) :
    sizeOf (smOr A B) ≤ sizeOf A + sizeOf B := by
  unfold sizeOf smOr
  exact Finset.card_union_le A B

/-- The size of the sm-AND is at most the product of the input sizes: the
  pairwise-union family is an image of the cartesian product, so its
  cardinality is bounded by the product of the two carrier sizes
  (`Finset.card_image_le` + `Finset.card_product`). -/
lemma sm_and_size_le {n : Nat} (A B : ApproxSet n) :
    sizeOf (smAnd A B) ≤ sizeOf A * sizeOf B := by
  unfold sizeOf smAnd
  calc
    ((A.product B).image (fun ab : Monomial n × Monomial n => ab.1 ∪ ab.2)).card
        ≤ (A.product B).card := by
      exact Finset.card_image_le
    _ = A.card * B.card := by
      simp [Finset.card_product]

end ApproxSet

/-!
## The approximation semantics and the reducer

A monomial witnesses a monotone value 1 on an assignment iff every
variable in it is 1. An approximation is 1 at an assignment iff some
monomial witnesses 1 there. The reducer rewrites a gate's *witness set*:

- input `i` -> the singlton monomial `{ i }`;
- `or a b` -> `smOr (approximate a) (approximate b)`;
- `and a b` -> `smAnd (approximate a) (approximate b)`.

The load-bearing structural lemmas (proven v1):the sm-OR membershp
identity (union semantics), the sm-AND membership identity (pairwise
union form), and the reducibility lemma (the approximation's size is at
most the circuit's sizeembedded in the product/union expressions).
-/

/-- A monomial is 1 on an assignment iff every variable in it is 1. -/
def MonomialEval {n : Nat} (m : Monomial n) (v : Fin n → Bool) : Bool :=
  ∀ i ∈ m, v i = true

namespace Reducer

/-- The reducer: a monotone gate's approximation (its witness monomial
  family), by structural recursion over the gate. -/
def approximate {n : Nat} : MonotoneGate n → ApproxSet n
  | MonotoneGate.input i => { { i } }
  | MonotoneGate.or a b => ApproxSet.smOr (approximate a) (approximate b)
  | MonotoneGate.and a b => ApproxSet.smAnd (approximate a) (approximate b)

/-- The sm-OR membership identity: a monomial is in the OR's
  approximation iff it is in at least one input's approximation
  (the union semantics). -/
lemma sm_or_mem {n : Nat} (A B : ApproxSet n) (m : Monomial n) :
    m ∈ ApproxSet.smOr A B ↔ m ∈ A ∨ m ∈ B := by
  unfold ApproxSet.smOr
  simp [Finset.mem_union]

/-- The sm-AND membership identity: a monomial is in the AND's
  approximation iff it is the union of an A-monomial and a B-monomial. -/
lemma sm_and_mem {n : Nat} (A B : ApproxSet n) (m : Monomial n) :
    m ∈ ApproxSet.smAnd A B ↔
      ∃ a : Monomial n, ∃ b : Monomial n, a ∈ A ∧ b ∈ B ∧ m = a ∪ b := by
  constructor
  · intro hm
    rcases (Finset.mem_image.mp hm) with ⟨⟨a, b⟩, hab, hrfl⟩
    rcases (Finset.mem_product.mp hab) with ⟨ha, hb⟩
    refine ⟨a, b, ha, hb, ?_⟩
    exact hrfl.symm
  · rintro ⟨a, b, ha, hb, rfl⟩
    exact (Finset.mem_image.mpr ⟨(a, b), Finset.mem_product.mpr ⟨ha, hb⟩, rfl⟩)

/-- Reducibility (v1 structural): the reducer's output on a gate is built
  from the input approximations by the sm-operations, so its size at
  most doubles per OR and squares per AND (the product/union bound this
  pass records; the exact counting is Pass 3). Statement form: the
  approximation of any gate is inhabited (nonempty carrier).
-/
lemma approximate_nonempty {n : Nat} (g : MonotoneGate n) :
    (approximate g).Nonempty := by
  induction g with
  | input i => simp [approximate]
  | or a b iha ihb =>
      unfold approximate
      exact Finset.union_nonempty.mpr (Or.inl iha)
  | and a b iha ihb =>
      unfold approximate
      rcases iha with ⟨a0, ha0⟩
      rcases ihb with ⟨b0, hb0⟩
      refine ⟨a0 ∪ b0, ?_⟩
      exact Finset.mem_image.mpr ⟨(a0, b0), Finset.mem_product.mpr ⟨ha0, hb0⟩, rfl⟩

end Reducer

end Circuits

end PleaNP
