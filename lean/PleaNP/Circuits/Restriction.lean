import PleaNP.Circuits.AC0

set_option warningAsError true

/-!
# Random restrictions — the Håstad switching-lemma substrate (issue #72, Pass 1)

The switching lemma (#72 Pass 1's milestone) is stated over **restrictions**:
partial assignments that fix some variables to Boolean constants and leave the
rest free. A restriction is then *applied* to a circuit, collapsing every fixed
`input` into a `const` leaf (the representation prerequisite landed in #157).

This module lands the deterministic core of that substrate — all zero-sorry:

- `Restriction` and its `agrees` / `extend` vocabulary;
- `apply`: restrict a circuit (fixed input → `const`, free input unchanged,
  gates recurse);
- **evaluation correctness** — `apply_eval_agrees` (`eval (apply r c) v =
  eval c (r.extend v)`) and `apply_eval_congr` (the restricted circuit depends
  only on the free variables);
- **structural preservation** — `apply_size_le` and `apply_depth_le`: a
  restriction never increases a circuit's size or depth.

The probabilistic half of the switching lemma (a random restriction shrinks
the depth to a decision-tree bound with high probability) needs a probability
space and a decision-tree depth measure; that is the Pass-2 follow-up, frozen
in the `Switching-lemma statement freeze` section below. This module deliberately
does not claim it.

-/

namespace PleaNP

namespace Circuits

/-- A **restriction** on `n` variables: a partial assignment. `val i = some b`
  fixes variable `i` to `b`; `val i = none` leaves it free. -/
structure Restriction (n : Nat) where
  val : Fin n → Option Bool

namespace Restriction

variable {n : Nat}

/-- `r.agrees v`: the total assignment `v` respects every fixed variable of
  `r`. -/
def agrees (r : Restriction n) (v : Fin n → Bool) : Prop :=
  ∀ i b, r.val i = some b → v i = b

/-- Extend a restriction to a total assignment: fixed variables take their
  value, free variables are read from `w`. -/
def extend (r : Restriction n) (w : Fin n → Bool) : Fin n → Bool :=
  fun i => (r.val i).getD (w i)

lemma extend_agrees (r : Restriction n) (w : Fin n → Bool) : r.agrees (r.extend w) := by
  intro i b hb
  simp [extend, hb]

/-- A total assignment agrees with `r` exactly when it is one of `r`'s
  extensions. -/
lemma agrees_iff (r : Restriction n) (v : Fin n → Bool) :
    r.agrees v ↔ v = r.extend fun i => v i := by
  constructor
  · intro h
    funext i
    unfold extend
    cases hval : r.val i with
    | none => simp only [Option.getD_none]
    | some b => simp only [Option.getD_some]; exact h i b hval
  · rintro h i b hb
    have hi := congrFun h i
    simp [extend, hb] at hi
    exact hi

/-- The number of fixed variables. -/
def fixedCount (r : Restriction n) : Nat :=
  (Finset.univ.filter (fun i => (r.val i).isSome)).card

/-- The number of free variables. -/
def freeCount (r : Restriction n) : Nat :=
  (Finset.univ.filter (fun i => (r.val i) = none)).card

/-- **Apply a restriction to a circuit.** A fixed input becomes a `const`
  leaf, a free input is unchanged, and gates recurse. This is the operation
  the switching lemma iterates: each application collapses the restricted
  variables, shrinking the circuit toward the decision tree of its free
  variables. -/
def apply (r : Restriction n) : BoolGate n → BoolGate n
  | .input i => match r.val i with
      | none => .input i
      | some b => .const b
  | .const b => .const b
  | .and a b => .and (apply r a) (apply r b)
  | .or a b => .or (apply r a) (apply r b)
  | .not a => .not (apply r a)

/-- Applying a restriction to a leaf yields a leaf (a fixed input becomes a
  `const`, a `const` stays, a free input stays). -/
lemma apply_isLeaf {r : Restriction n} {c : BoolGate n} (hc : c.IsLeaf) :
    (apply r c).IsLeaf := by
  cases hc with
  | input i =>
      cases hval : r.val i with
      | none => simp only [apply, hval]; exact BoolGate.IsLeaf.input i
      | some b => simp only [apply, hval]; exact BoolGate.IsLeaf.const b
  | const b => exact BoolGate.IsLeaf.const b

/-- **Evaluation correctness (extension form).** Evaluating the restricted
  circuit at `v` is evaluating the original circuit at an extension of `r`
  that reads the free variables from `v`. This is the load-bearing bridge
  between `apply` (syntax) and the circuit's semantics. -/
lemma apply_eval_agrees (r : Restriction n) (c : BoolGate n) (v : Fin n → Bool) :
    BoolGate.eval (apply r c) v = BoolGate.eval c (r.extend v) := by
  induction c with
  | input i =>
      cases hval : r.val i with
      | none => simp [apply, hval, extend, BoolGate.eval]
      | some b => simp [apply, hval, extend, BoolGate.eval]
  | const b => simp [apply, BoolGate.eval]
  | and a b iha ihb => simp [apply, BoolGate.eval, iha, ihb]
  | or a b iha ihb => simp [apply, BoolGate.eval, iha, ihb]
  | not a iha => simp [apply, BoolGate.eval, iha]

/-- **Evaluation correctness (congruence form).** The restricted circuit
  depends only on the *free* variables of `r`: two assignments that agree on
  every free variable evaluate the restricted circuit identically. -/
lemma apply_eval_congr (r : Restriction n) (c : BoolGate n) {v w : Fin n → Bool}
    (h : ∀ i, r.val i = none → v i = w i) :
    BoolGate.eval (apply r c) v = BoolGate.eval (apply r c) w := by
  rw [apply_eval_agrees, apply_eval_agrees]
  have hext : r.extend v = r.extend w := by
    funext i
    unfold extend
    cases hval : r.val i with
    | none => simp only [Option.getD_none]; exact h i hval
    | some b => simp only [Option.getD_some]
  rw [hext]

/-- **A restriction never increases size.** -/
lemma apply_size_le (r : Restriction n) (c : BoolGate n) :
    (apply r c).size ≤ c.size := by
  induction c with
  | input i =>
      cases hval : r.val i with
      | none => simp [apply, hval, BoolGate.size]
      | some b => simp [apply, hval, BoolGate.size]
  | const b => simp [apply, BoolGate.size]
  | and a b iha ihb => simp [apply, BoolGate.size]; omega
  | or a b iha ihb => simp [apply, BoolGate.size]; omega
  | not a iha => simp [apply, BoolGate.size]; omega

/-- **A restriction never increases depth.** The structural monotonicity the
  depth-reduction argument consumes: iterating restrictions cannot make a
  circuit deeper. -/
lemma apply_depth_le (r : Restriction n) (c : BoolGate n) :
    (apply r c).depth ≤ c.depth := by
  induction c with
  | input i =>
      cases hval : r.val i with
      | none => simp [apply, hval, BoolGate.depth]
      | some b => simp [apply, hval, BoolGate.depth]
  | const b => simp [apply, BoolGate.depth]
  | and a b iha ihb =>
      simp only [apply, BoolGate.depth]
      omega
  | or a b iha ihb =>
      simp only [apply, BoolGate.depth]
      omega
  | not a iha =>
      simp only [apply, BoolGate.depth]
      omega

/-- The **total** restriction fixing every variable. Applying it makes the
  circuit constant in the assignment: `t`'s free set is empty. -/
def total (n : Nat) (w : Fin n → Bool) : Restriction n :=
  ⟨fun i => some (w i)⟩

@[simp] lemma total_val (n : Nat) (w : Fin n → Bool) (i : Fin n) :
    (total n w).val i = some (w i) := rfl

/-- A total restriction's application is independent of the assignment:
  the restricted circuit is already fully evaluated. -/
lemma total_apply_eval_const (n : Nat) (w : Fin n → Bool) (c : BoolGate n)
    (v v' : Fin n → Bool) :
    BoolGate.eval (apply (total n w) c) v = BoolGate.eval (apply (total n w) c) v' := by
  apply apply_eval_congr
  intro i hfree
  simp [total] at hfree

/-! ## Switching-lemma statement freeze (Pass 1 marker; Pass 2 proves it)

Håstad's switching lemma is now statable over this substrate. The precise
Pass-2 target:

> For every `d`, there is a `p ∈ (0,1)` small enough that for every circuit
> `c : BoolGate n` with `c.depth ≤ d` and every `p`-random restriction `r`
> (`val i` independently `none` with probability `p`, else a uniform Boolean),
> there is a **decision tree** `T` of depth at most `k` on the free variables
> of `r` that computes `apply r c`, with failure probability at most
> `(5 p d) ^ k` over the choice of `r`.

Two pieces are still missing, and are the Pass-2 work:
1. A **probability space** for `p`-random restrictions (`PMF (Restriction n)`)
   and a **decision-tree depth** measure (`DTdepth`, the min-depth tree
   computing `apply r c` on the free variables). The evaluation semantics to
   define either of these now exists (`apply_eval_agrees` / `apply_eval_congr`).
2. The **inductive depth-reduction proof** itself (the `≤ (5pd)^k` bound).

What this module settles deterministically, and the depth-reduction will
consume: `apply` collapses fixed variables into `const` leaves (#157), never
increases size or depth (`apply_size_le`, `apply_depth_le`), and yields a
function of the free variables only (`apply_eval_congr`). The `depth ≤ 1`
base case of the ladder is `depth_le_one_shapes` (AC0.lean).

-/

end Restriction

end Circuits

end PleaNP
