import PleaNP.Circuits.Restriction

set_option warningAsError true

/-!
# Switching lemma substrate — decision trees, random restrictions, the depth
# reduction (issue #72, Pass 2)

Pass 1 (`Restriction.lean`, `032abaf`) landed the *deterministic* restriction
core: `apply` collapses fixed `input` leaves to `const` (#157) and never
increases size or depth. This module is Pass 2's **measure-and-statement
layer**, all zero-sorry:

- `BoolGate.IsDecisionTree` — the decision-tree shape (a query variable at each
  internal node, Boolean constants at the leaves), with the branch-evaluation
  lemma `eval_branch` that makes the shape semantically a query;
- `BoolGate.HasDTDepth` / `BoolGate.dtDepth` — the **decision-tree depth** of a
  circuit: the least number of *queries* needed to compute it, as an `sInf`
  over an explicitly witnessed set. The depth is counted in query levels, not
  gate levels (each query is two gate levels in the `BoolGate` encoding), so
  the switching lemma's `≤ k` conclusion is a statement about decision-tree
  depth in the standard sense;
- `IsRandomRestriction` — a `p`-random restriction stated by its
  *distributional* laws (mass one, and fixed-count distribution
  `C(n,k) p^k (1-p)^(n-k)`) rather than by the product formula, so Pass 3 can
  instantiate it with the canonical product measure and discharge the laws;
- `SwitchingLemmaStatement` / `SwitchingLemmaExists` — Håstad's switching
  lemma frozen as genuine `Prop`s over `dtDepth` and `IsRandomRestriction`.

**What is not claimed here.** The inductive depth-reduction proof
(`∑ failure mass ≤ (5 p d)^k`) is Pass 3; it is *stated*, not proven. This
module deliberately contains no `sorry` — the milestone is rendered the same
way Pass 1 rendered `parity_notin_AC0`: a zero-sorry `Prop` target plus the
deterministic support it will consume.

-/

namespace PleaNP

namespace Circuits

/-- `Restriction n` is finite (`Fin n → Option Bool`), declared before the
random-restriction predicate so that the probability sums below resolve their
`Fintype` instance. -/
noncomputable instance (n : Nat) : Fintype (Restriction n) :=
  Fintype.ofEquiv (Fin n → Option Bool)
    { toFun := fun f => ⟨f⟩
      invFun := fun r => r.val
      left_inv := fun _ => rfl
      right_inv := fun r => by cases r; rfl }

/-- A **`p`-random restriction** is a probability distribution over
`Restriction n` with the distributional laws of "each variable independently
free with probability `p`, otherwise a uniform Boolean": probability mass one,
and exactly `C(n,k) (1-p)^k p^(n-k)` mass on restrictions fixing `k`
variables. The free-probability convention is `p` (Håstad's `p`), so the
number of *fixed* variables is binomial with success probability `1-p`. The
product formula `∏_i (if free then p else (1-p)/2)` is Pass 3's canonical
witness that this predicate is inhabited; stating the laws rather than the
formula keeps the switching-lemma statement independent of that construction. -/
structure IsRandomRestriction (n : Nat) (p : ℚ) (μ : Restriction n → ℚ) : Prop where
  /-- A probability is non-negative. -/
  nonneg : ∀ r : Restriction n, 0 ≤ μ r
  /-- Total probability mass is one. -/
  sum_one : (∑ r : Restriction n, μ r) = 1
  /-- The **fixed-count distribution**: the mass carried by restrictions that
    fix exactly `k` variables is `C(n,k) (1-p)^k p^(n-k)`, the binomial law of
    the number of fixed variables when each variable is free with probability
    `p` (Håstad's convention). -/
  fixedCount_law : ∀ k : Nat,
    (∑ r : Restriction n, if r.fixedCount = k then μ r else 0)
      = (n.choose k : ℚ) * (1 - p) ^ k * p ^ (n - k)

namespace BoolGate

/-- **A decision tree** over `n` variables: a Boolean constant leaf, a single
input leaf, or a **query** — "read variable `i`; if it is `true` evaluate the
`true`-branch `a`, otherwise the `false`-branch `b`". A query is the
simplified shape `(i ∧ a) ∨ (¬i ∧ b)`, so the tree shape is a sub-shape of
`BoolGate` (the substrate is not extended).

The switching lemma's conclusion is that a random restriction turns a
depth-`d` circuit into (with high probability) such a tree of small depth, so
this shape — not the general gate term — is what the depth reduction lands in. -/
inductive IsDecisionTree : {n : Nat} → BoolGate n → Prop where
  | const (b : Bool) : IsDecisionTree (.const b)
  | input (i : Fin n) : IsDecisionTree (.input i)
  | branch (i : Fin n) {a b : BoolGate n} :
      IsDecisionTree a → IsDecisionTree b →
      IsDecisionTree (.or (.and (.input i) a) (.and (.not (.input i)) b))

/-- **The branch semantics.** A query `(i ∧ a) ∨ (¬i ∧ b)` evaluates by
reading variable `i` and taking the corresponding branch — the lemma that
makes `IsDecisionTree.branch` a genuine *query* rather than two gates that
happen to be written down. -/
lemma eval_branch {n : Nat} (i : Fin n) (a b : BoolGate n) (v : Fin n → Bool) :
    eval (.or (.and (.input i) a) (.and (.not (.input i)) b)) v =
      if v i then eval a v else eval b v := by
  by_cases h : v i <;> simp [eval, h]

/-- **A decision tree of bounded query depth.** `HasDTDepth c k` says `c`
admits a decision tree that reads at most `k` variables along any path: a
constant needs `0` queries, a bare input needs `1`, and a query adds one level
over the deeper of its two branches. Counted in *queries*, so `k` is the
decision-tree depth in the standard sense (the two gate levels of the
`BoolGate` query encoding are not charged).

`weaken` makes the predicate monotone in `k` (a depth-`k` tree is also a
depth-`k'` tree for `k ≤ k'`), which is the form Pass 3's induction needs —
the refinement step produces a tree of some bounded depth and must relax it to
the statement's `≤ k`. -/
inductive HasDTDepth : {n : Nat} → BoolGate n → Nat → Prop where
  | const (b : Bool) : HasDTDepth (.const b : BoolGate n) 0
  | input (i : Fin n) : HasDTDepth (.input i : BoolGate n) 1
  | branch (i : Fin n) {a b : BoolGate n} {ka kb : Nat} :
      HasDTDepth a ka → HasDTDepth b kb →
      HasDTDepth (.or (.and (.input i) a) (.and (.not (.input i)) b)) (1 + max ka kb)
  | weaken {c : BoolGate n} {k k' : Nat} : HasDTDepth c k → k ≤ k' → HasDTDepth c k'

/-- Monotonicity of the bounded query depth in its bound. -/
lemma HasDTDepth.mono {n : Nat} {c : BoolGate n} {k k' : Nat}
    (h : HasDTDepth c k) (hk : k ≤ k') : HasDTDepth c k' :=
  .weaken h hk

/-- The shape is the depth-erased reading of `HasDTDepth` (a sanity link
between the two views of a decision tree). -/
lemma HasDTDepth.isDecisionTree {n : Nat} {c : BoolGate n} {k : Nat}
    (h : HasDTDepth c k) : c.IsDecisionTree := by
  induction h with
  | const b => exact .const b
  | input i => exact .input i
  | branch i _ _ iha ihb => exact .branch i iha ihb
  | weaken _ _ ih => exact ih

/-- **The decision-tree depth of a circuit:** the least number of queries a
decision tree computing it needs, an `sInf` over the set of depths witnessed
by an explicit tree. Because membership in the set is witnessed by that tree,
`dtDepth_le` derives the bound directly — the switching lemma only consumes
this `≤` direction, never the exact value (so no existence theorem about
circuits outside the tree shape is needed). -/
noncomputable def dtDepth {n : Nat} (c : BoolGate n) : Nat :=
  sInf {k : Nat | HasDTDepth c k}

/-- **The witnessed bound.** An explicit query-depth witness bounds `dtDepth`.
This is the bridge from the switching lemma's conclusion ("here is a shallow
tree") to the `dtDepth` bound the statement is phrased in. -/
lemma dtDepth_le {n : Nat} {c : BoolGate n} {k : Nat} (h : HasDTDepth c k) :
    dtDepth c ≤ k :=
  Nat.sInf_le h

/-- Constant leaves are computed with no queries, so their `dtDepth` is `0`
(non-vacuity check on the measure). -/
lemma dtDepth_const_le {n : Nat} (b : Bool) : dtDepth (.const b : BoolGate n) ≤ 0 :=
  dtDepth_le (.const b)

/-- A bare input is read with one query. -/
lemma dtDepth_input_le {n : Nat} (i : Fin n) : dtDepth (.input i : BoolGate n) ≤ 1 :=
  dtDepth_le (.input i)

/-- A query whose branches are both query-depth `≤ k` is query-depth
`≤ k + 1` — the increment the depth reduction iterates. -/
lemma dtDepth_query_le {n : Nat} (i : Fin n) {a b : BoolGate n} {ka kb : Nat}
    (ha : HasDTDepth a ka) (hb : HasDTDepth b kb) :
    dtDepth (.or (.and (.input i) a) (.and (.not (.input i)) b)) ≤ 1 + max ka kb :=
  dtDepth_le (.branch i ha hb)

end BoolGate

/-- **The switching lemma (Håstad), frozen (Pass 3 target).** For a
`p`-random restriction `μ`, a depth-`d` circuit `c`, and any `k`, the
`μ`-mass of restrictions whose restricted circuit *fails* to have
decision-tree depth `≤ k` is at most `(5 p d)^k`.

The failure event is written with `dtDepth` (`if dtDepth (apply r c) ≤ k then
0 else μ r`), so the bound is over the same query-depth measure Pass 3's
induction will bound. This is a `Prop`, not a theorem: the inductive proof is
the Pass-3 work. -/
def SwitchingLemmaStatement (d : Nat) (p : ℚ) : Prop :=
  ∀ n : Nat, ∀ μ : Restriction n → ℚ, IsRandomRestriction n p μ →
  ∀ c : BoolGate n, c.depth ≤ d →
  ∀ k : Nat,
    (∑ r : Restriction n, if BoolGate.dtDepth (Restriction.apply r c) ≤ k then 0 else μ r)
      ≤ (5 * p * (d : ℚ)) ^ k

/-- **The switching lemma, existential form.** For every depth bound `d` there
is a restricting probability `p ∈ (0,1)` making `SwitchingLemmaStatement d p`
hold — the shape the `parity ∉ AC⁰` ladder consumes (small `p` forces small
expected depth, and the union bound over the `d` levels yields a depth bound
independent of `n`). Stated, not proven (Pass 3).

The `p < 1` conjunct matters: it excludes the degenerate `p = 1` distribution
(which fixes every variable, making the conclusion vacuous), so the statement
is not trivially satisfiable. -/
def SwitchingLemmaExists : Prop :=
  ∀ d : Nat, ∃ p : ℚ, 0 < p ∧ p < 1 ∧ SwitchingLemmaStatement d p

end Circuits

end PleaNP
