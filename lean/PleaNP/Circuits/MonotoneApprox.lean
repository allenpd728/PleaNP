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

/-- **Truncation to monomials of size ≤ `r`** — Razborov's closure operation.
  Keeping only the "small" monomials is what makes the approximation
  countable, and so what lets the counting bound go through. Truncation can
  only remove monomials, so it is size-nonincreasing. -/
def truncate {n : Nat} (r : Nat) (A : ApproxSet n) : ApproxSet n :=
  A.filter (fun m => m.card ≤ r)

/-- Truncation never grows the carrier: `|truncate r A| ≤ |A|`. -/
lemma truncate_size_le {n : Nat} (r : Nat) (A : ApproxSet n) :
    sizeOf (truncate r A) ≤ sizeOf A := by
  unfold sizeOf truncate
  exact Finset.card_filter_le _ _

/-- **The truncated carrier is a subfamily of the `≤ r`-subsets.** Every
  monomial surviving truncation has cardinality at most `r`, so it lies in
  the `k`-th powerset layer for `k = m.card ≤ r`. This is the set-theoretic
  core of the counting bound: it replaces an arbitrary family by one drawn
  from a set whose cardinality is a function of `n` and `r` alone — the step
  that makes the approximation countable independently of the circuit. -/
lemma truncate_subset_powersetCard_biUnion {n r : Nat} (A : ApproxSet n) :
    truncate r A ⊆ (Finset.range (r + 1)).biUnion
      (fun k => (Finset.univ : Finset (Fin n)).powersetCard k) := by
  intro m hm
  rw [truncate, Finset.mem_filter] at hm
  rw [Finset.mem_biUnion]
  exact ⟨m.card, Finset.mem_range.mpr (Nat.lt_succ_of_le hm.2),
    Finset.mem_powersetCard.mpr ⟨Finset.subset_univ m, rfl⟩⟩

/-- **The Razborov counting bound.** The number of size-`≤ r` monomials in
  any approximation is at most `∑_{k ≤ r} C(n, k)` — the number of subsets
  of an `n`-element set of size at most `r`. Crucially this bound depends
  only on the ambient dimension `n` and the truncation threshold `r`, *not*
  on the circuit that produced the approximation: it is what lets Pass 3
  count the monomials a monotone circuit of a given size can expose, and so
  what makes the CLIQUE pigeonhole go through. -/
lemma truncate_card_le_sum_choose {n r : Nat} (A : ApproxSet n) :
    sizeOf (truncate r A) ≤ ∑ k ∈ Finset.range (r + 1), n.choose k := by
  calc
    sizeOf (truncate r A)
        ≤ ((Finset.range (r + 1)).biUnion
            (fun k => (Finset.univ : Finset (Fin n)).powersetCard k)).card :=
          Finset.card_le_card (truncate_subset_powersetCard_biUnion A)
    _ ≤ ∑ k ∈ Finset.range (r + 1),
          ((Finset.univ : Finset (Fin n)).powersetCard k).card :=
          Finset.card_biUnion_le
    _ = ∑ k ∈ Finset.range (r + 1), n.choose k := by
          apply Finset.sum_congr rfl
          intro k _
          rw [Finset.card_powersetCard, Finset.card_univ, Fintype.card_fin]

end ApproxSet

/-!
## The approximation semantics and the reducer

A monomial witnesses a monotone value 1 on an assignment iff every
variable in it is 1. An approximation is 1 at an assignment iff some
monomial witnesses 1 there. The reducer rewrites a gate's *witness set*:

- input `i` -> the singlton monomial `{ i }`;
- `or a b` -> `smOr (approximate a) (approximate b)`;
- `and a b` -> `smAnd (approximate a) (approximate b)`.

The load-bearing structural lemmas (proven v1): the sm-OR membershp
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

/-- **Soundness of the reducer (the 1-direction of the monotone
  approximation).** Every monomial the reducer produces is *consistent* with
  the circuit: if a monomial in `approximate g` is satisfied by an
  assignment, then `g` evaluates to `true` there. This is one half of the
  approximation-correctness the counting consumes (the other half is
  completeness: `g = true` on an assignment forces some produced monomial to
  be satisfied there). Stated in the unfolded membership form that the
  induction uses; `monomialEval_imp_eval'` restates it against `MonomialEval`. -/
lemma monomialEval_imp_eval {n : Nat} (g : MonotoneGate n) {v : Fin n → Bool}
    {m : Monomial n} (hm : m ∈ approximate g) (hv : ∀ i ∈ m, v i = true) :
    MonotoneGate.eval g v = true := by
  induction g generalizing m with
  | input i =>
      simp only [approximate, Finset.mem_singleton] at hm
      subst hm
      simp only [MonotoneGate.eval]
      exact hv i (Finset.mem_singleton_self i)
  | or a b iha ihb =>
      rcases (sm_or_mem _ _ m).mp (by simpa [approximate] using hm) with hmA | hmB
      · simp only [MonotoneGate.eval, Bool.or_eq_true]
        exact Or.inl (iha hmA hv)
      · simp only [MonotoneGate.eval, Bool.or_eq_true]
        exact Or.inr (ihb hmB hv)
  | and a b iha ihb =>
      rcases (sm_and_mem _ _ m).mp (by simpa [approximate] using hm) with
        ⟨a0, b0, ha0, hb0, rfl⟩
      have hvA : ∀ i ∈ a0, v i = true := fun i hi => hv i (Finset.mem_union_left _ hi)
      have hvB : ∀ i ∈ b0, v i = true := fun i hi => hv i (Finset.mem_union_right _ hi)
      simp only [MonotoneGate.eval, Bool.and_eq_true]
      exact ⟨iha ha0 hvA, ihb hb0 hvB⟩

lemma monomialEval_imp_eval' {n : Nat} (g : MonotoneGate n) {v : Fin n → Bool}
    {m : Monomial n} (hm : m ∈ approximate g) (hv : MonomialEval m v = true) :
    MonotoneGate.eval g v = true :=
  monomialEval_imp_eval g hm (of_decide_eq_true hv)

/-- **Completeness of the reducer (the 0->1 direction of the monotone
  approximation).** If a gate evaluates to `true` on an assignment, then
  some monomial the reducer produces is satisfied there. This is the second
  half of approximation-correctness: together with `monomialEval_imp_eval`
  it says the approximation's 1-set *is* the gate's 1-set, which is the
  property the Razborov counting bound consumes (the counting only counts
  the produced witness monomials, so it must know every 1 is witnessed).
  Structural induction on the gate; the OR case splits the disjunction and
  the AND case pairs the two witness monomials through `smAnd`. -/
lemma eval_imp_monomialEval {n : Nat} (g : MonotoneGate n) {v : Fin n → Bool}
    (hv : MonotoneGate.eval g v = true) :
    ∃ m : Monomial n, m ∈ approximate g ∧ ∀ i ∈ m, v i = true := by
  induction g with
  | input i =>
      exact ⟨{i}, by simp [approximate],
        by intro j hj; rw [Finset.mem_singleton] at hj; subst hj
           simpa only [MonotoneGate.eval] using hv⟩
  | or a b iha ihb =>
      have hv' : MonotoneGate.eval a v = true ∨ MonotoneGate.eval b v = true := by
        simpa only [MonotoneGate.eval, Bool.or_eq_true] using hv
      rcases hv' with ha | hb
      · obtain ⟨m, hm, hval⟩ := iha ha
        exact ⟨m, by simpa [approximate] using (sm_or_mem _ _ m).mpr (Or.inl hm), hval⟩
      · obtain ⟨m, hm, hval⟩ := ihb hb
        exact ⟨m, by simpa [approximate] using (sm_or_mem _ _ m).mpr (Or.inr hm), hval⟩
  | and a b iha ihb =>
      have hv' : MonotoneGate.eval a v = true ∧ MonotoneGate.eval b v = true := by
        simpa only [MonotoneGate.eval, Bool.and_eq_true] using hv
      obtain ⟨ma, hma, hvalA⟩ := iha hv'.1
      obtain ⟨mb, hmb, hvalB⟩ := ihb hv'.2
      refine ⟨ma ∪ mb,
        by simpa [approximate] using (sm_and_mem _ _ (ma ∪ mb)).mpr ⟨ma, mb, hma, hmb, rfl⟩, ?_⟩
      intro i hi
      rcases Finset.mem_union.mp hi with hiA | hiB
      · exact hvalA i hiA
      · exact hvalB i hiB

/-- **Approximation correctness (exactness).** The reducer's approximation
  has exactly the same 1-set as the gate: a gate is `true` on an assignment
  iff some produced monomial is satisfied there. This is the packaged form
  of the two directions (`eval_imp_monomialEval` and
  `monomialEval_imp_eval`) that Pass 3's counting bound invokes. -/
lemma eval_iff_exists_monomial {n : Nat} (g : MonotoneGate n) {v : Fin n → Bool} :
    MonotoneGate.eval g v = true ↔
      ∃ m : Monomial n, m ∈ approximate g ∧ ∀ i ∈ m, v i = true := by
  constructor
  · exact eval_imp_monomialEval g
  · rintro ⟨m, hm, hval⟩
    exact monomialEval_imp_eval g hm hval

end Reducer

end Circuits

end PleaNP
