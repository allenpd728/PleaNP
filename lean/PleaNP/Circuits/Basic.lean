import Mathlib

set_option warningAsError true

/-
Circuit complexity infrastructure needed to state and apply the barriers.

Planned coverage (Rung 4, see `docs/ROADMAP.md` and DEC-025, which chose the
LOCAL build over the complexitylib import):

  - Boolean circuits (uniform families)          <- this module, issue #71 Pass 1
  - AC^0 (constant-depth, {AND, OR, NOT})
  - TC^0 (AC^0 + threshold gates)
  - NC hierarchy
  - Switching lemma (Hastad)
  - Parity notin AC^0
  - Monotone circuit lower bounds (Razborov)
  - Williams (2011): NEXP not-subset ACC^0

Issue #71 Pass 1 (2026-09-13): the typed Boolean circuit-family substrate —
the gate term, its structural `size`/`depth` (the two quantities every
Rung-4 bound quantifies), the circuit *family* (P/poly shape: one circuit
per input length), and the natural-property vocabulary (Boolean function
`Fin n -> Bool`, the `F_n` carrier). Pass 2 adds P/poly membership + the
largeness/constructivity predicates; Pass 3 the must-refute suite.
-/

namespace PleaNP

namespace Circuits

/-- A Boolean gate term over `n` input variables: an input bit, a Boolean
  constant leaf, or an AND/OR/NOT gate over sub-terms. This is the *tree*
  model of a Boolean circuit (each gate has fan-out sharing elided — the
  size/depth functions below are structural, and the family shape carries
  the size/depth quantities every Rung-4 bound quantifies).

  The `const` leaf (issue #157) is the representation prerequisite for the
  Håstad switching lemma (#72 Pass 1): a random restriction must *fix* a
  variable to a Boolean constant, and without a constant gate there is no
  representable result for `Restriction.apply`. Its shape matches the
  `input` leaf (`size = 1`, `depth = 0`): both are 0-ary leaves. -/
inductive BoolGate (n : Nat) where
  | input (i : Fin n)      -- reads the i-th input bit
  | const (b : Bool)       -- constant leaf (the restriction's fixed value)
  | and (a b : BoolGate n) -- AND gate over two sub-circuits
  | or (a b : BoolGate n)  -- OR gate over two sub-circuits
  | not (a : BoolGate n)   -- NOT gate over one sub-circuit
  deriving DecidableEq

namespace BoolGate

/-- **Circuit size:** the number of gates (nodes) in the circuit, by
  structural recursion. This is the `size` of circuit-size lower bounds
  (parity ∉ AC⁰, monotone CLIQUE, resolution width → NEXP ⊄ ACC⁰ counting).
  Load-bearing: `BoolGate.size` increases strictly through every gate. -/
def size : {n : Nat} → BoolGate n → Nat
  | _, input _ => 1
  | _, const _ => 1
  | _, and a b => 1 + size a + size b
  | _, or a b => 1 + size a + size b
  | _, not a => 1 + size a

/-- **Circuit depth:** the longest root-to-leaf path, by structural
  recursion. Constant-depth classes (AC⁰/ACC⁰) are captured by bounding
  this quantity. -/
def depth : {n : Nat} → BoolGate n → Nat
  | _, input _ => 0
  | _, const _ => 0
  | _, and a b => 1 + max (depth a) (depth b)
  | _, or a b => 1 + max (depth a) (depth b)
  | _, not a => 1 + depth a

lemma size_pos {n : Nat} (c : BoolGate n) : 0 < size c := by
  cases c <;> simp [size]

lemma depth_size_le {n : Nat} (c : BoolGate n) : depth c < size c := by
  induction c with
  | input i => simp [size, depth]
  | const b => simp [size, depth]
  | and a b iha ihb =>
      simp [size, depth]
      have ha : depth a < size a + size b :=
        Nat.lt_of_lt_of_le iha (Nat.le_add_right (size a) (size b))
      have hb : depth b < size a + size b :=
        Nat.lt_of_lt_of_le ihb (Nat.le_add_left (size b) (size a))
      omega
  | or a b iha ihb =>
      simp [size, depth]
      have ha : depth a < size a + size b :=
        Nat.lt_of_lt_of_le iha (Nat.le_add_right (size a) (size b))
      have hb : depth b < size a + size b :=
        Nat.lt_of_lt_of_le ihb (Nat.le_add_left (size b) (size a))
      omega
  | not a ih =>
      simp [size, depth]
      omega

end BoolGate

namespace BoolGate

/-- **A leaf** is a 0-ary gate: an input variable or a Boolean constant. The
  const leaf (issue #157) sits beside `input` as the other depth-0 shape, so
  the depth ladder's base case is stated over `IsLeaf` rather than `input`
  alone. -/
inductive IsLeaf : {n : Nat} → BoolGate n → Prop where
  | input (i : Fin n) : IsLeaf (.input i)
  | const (b : Bool) : IsLeaf (.const b)

end BoolGate

/-- A Boolean function on `n` inputs: the `F_n` carrier of the natural-property
  vocabulary (`Fin n → Bool`). `f ∈ C_n` is membership in a property's n-th
  slice (NaturalProofs.md §2). -/
abbrev BoolFunc (n : Nat) : Type := Fin n → Bool

/-- A **circuit family**: one circuit per input length — the P/poly shape.
  (Membership in `P/poly` is a family whose size is polynomially bounded:
  the polynomial-bound predicate is the Pass-2 `IsPPoly`.) -/
abbrev CircuitFamily := ∀ n : Nat, BoolGate n

/-- The family size at length n. -/
def CircuitFamily.sizeOf (C : CircuitFamily) (n : Nat) : Nat :=
  BoolGate.size (C n)

/-- The family depth at length n. -/
def CircuitFamily.depthOf (C : CircuitFamily) (n : Nat) : Nat :=
  BoolGate.depth (C n)

/-! ## P/poly shape + natural property (issue #71 Pass 2) -/

/-- **P/poly membership (shape):** a circuit family whose size is polynomially
  bounded. `p : Polynomial ℕ` bounds the family size at every length — the
  standard non-uniform class reading (NaturalProofs.md §2: "superpolynomial
  lower bounds against general polynomial-size circuits"). -/
def IsPPoly (C : CircuitFamily) : Prop :=
  ∃ p : Polynomial ℕ, ∀ n : Nat, CircuitFamily.sizeOf C n ≤ p.eval n

/-- A **property family** `C = {C_n}`: a sequence of subsets of the `F_n`
  of n-ary Boolean functions — the carrier of the natural-property
  definition (NaturalProofs.md §2). -/
abbrev PropertyFamily := ∀ n : Nat, Set (BoolFunc n)

/-- **Largeness:** for all large enough `n`, `C_n` contains at least the
  `2^-n` fraction of all n-ary Boolean functions. Since `Fintype.card (F_n)
  = 2^n`, the fraction condition `|C_n| ≥ |F_n|/2^n` is equivalent to the
  cardinality inequality `2^n * |C_n| ≥ |F_n|` (avoiding division). This is
  the "a random function is in C_n with non-negligible probability" reading
  (NaturalProofs.md §2(3)). -/
def Largeness (C : PropertyFamily) : Prop :=
  ∃ n₀ : Nat, ∀ n ≥ n₀,
    2 ^ n * Nat.card {f : BoolFunc n // f ∈ C n} ≥ Fintype.card (BoolFunc n)

/-- **Constructivity (v1 substrate):** membership in `C_n` is decided by
  some boolean characteristic `χ_n : F_n → Bool`, witnessing `f ∈ C_n`.
  The `P`-natural / `NP`-natural polynomial-time bound in the truth-table
  size is the machine-substrate refinement (the constructivity-class
  decision); the v1 form records the decision-function shape the barrier's
  constructivity condition requires (NaturalProofs.md §2(2)). -/
def Constructive (C : PropertyFamily) : Prop :=
  ∀ n : Nat, ∃ χ : BoolFunc n → Bool, ∀ f : BoolFunc n, (χ f = true ↔ f ∈ C n)

/-- **Natural property:** a property family satisfying constructivity and
  largeness — the two conditions of NaturalProofs.md §2 (usefulness is the
  third, a predicate on the target class added where the barrier is stated). -/
def NaturalProperty (C : PropertyFamily) : Prop :=
  Constructive C ∧ Largeness C

/-! ## Concrete sanity (substrate self-exercise; the must-refute suite is Pass 3) -/

/-- A concrete 2-input circuit computing `x0 ∧ x1` (one AND gate over two
  inputs): size 3 (AND + 2 inputs), depth 1. -/
def and2 : BoolGate 2 :=
  BoolGate.and (BoolGate.input 0) (BoolGate.input 1)

example : BoolGate.size and2 = 3 := by
  simp [and2, BoolGate.size]

example : BoolGate.depth and2 = 1 := by
  simp [and2, BoolGate.depth]

/-- The constant-`true` circuit (`const true`): size 1, depth 0 — the leaf a
  random restriction produces when it fixes a variable (#157). -/
example : BoolGate.size (BoolGate.const true : BoolGate 3) = 1 := by
  simp [BoolGate.size]

example : BoolGate.depth (BoolGate.const true : BoolGate 3) = 0 := by
  simp [BoolGate.depth]

/-- The universal property `C_n = F_n` is Large: every n-ary function is a
  member, so `|C_n| = |F_n|` and the fraction inequality is trivially
  satisfied. This is the substrate's non-vacuity sanity — `Largeness` is
  inhabited. -/
theorem univ_largeness : Largeness (fun _ : Nat => Set.univ) := by
  unfold Largeness
  refine ⟨0, ?_⟩
  intro n _hn
  simp
  exact Nat.one_le_pow n 2 (by decide)

end Circuits

end PleaNP
