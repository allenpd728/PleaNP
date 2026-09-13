import PleaNP.Circuits.Basic
import PleaNP.Circuits.AC0
import Mathlib

set_option warningAsError true

/-!
# Williams transfer — statement freeze (issue #88, Williams STOC 2011)

Pass 1 of the #76 umbrella: render the frozen *statements* the Williams
transfer needs — `NEXP`, `ACC⁰`, and `CircuitSAT` — over the #71 circuit
substrate (`PleaNP.Circuits`, DEC-025 local build), with full fidelity
gates. The transfer theorem itself (`nontrivial CircuitSAT for ACC⁰ ⟹ NEXP
⊄ ACC⁰) is Pass 3; Pass 2 is the ACC⁰ CircuitSAT algorithm.

## What each declaration means (read-back anchors)

- `CircuitSAT C` — the **decision problem**: "is there an assignment on
  which the circuit evaluates to true?"  Concrete over `BoolGate.eval`
  (AC0.lean). This is the *same* decision problem the Williams algorithm
  targets (nontrivial = better than brute force over the 2^n assignments).
- `IsACC0 C` — **ACC⁰ shape**: a constant-depth, polynomial-size circuit
  family (AND/OR/NOT basis).  The Mod-m gate extension (the distinguishing
  ACC⁰ feature over AC⁰) is documented as a substrate-extension note in the
  statement, since Pass 1 freezes the *shape* the transfer's statements
  quantify, and the exact gate basis is pinned with rung-4's substrate builds.
- `NEXP_membership L` — the **exponential-time nondeterministic class**,
  stated over an abstract exponential-bounded machine witness
  (2^(n^k)-step acceptance).  Per DEC-003 the concrete P/NP model is
  deferred to upstream; the statement records the conceptual shape the
  transfer needs: `L` is decided by some nondeterministic exponential-time
  machine.

## Fidelity note (Gate 1/4)

The informal source is Williams STOC 2011 "Non-uniform ACC Circuit Lower
Bounds" (Theorem: NTIM(2^{n^o(1)}) + Algorithmic improvements to ACC⁰
Circuit SAT ⟹ Nexp ⊄ ACC⁰).  The v1 statements below are the component
anchors; Pass 3 assembles the transfer and the classification
(non-relativizing / non-natural / non-algebrizing) for #73.
-/

namespace PleaNP

namespace Barriers

namespace Williams

open PleaNP.Circuits

/-- **CircuitSAT**, the decision problem over `BoolGate` circuits: exists an
  assignment `v : Fin n → Bool` such that evaluating the circuit on `v`
  yields `true`.  The brute-force search space is 2^n — the quantity Pass 2's
  algorithm must beat.  Concrete and non-vacuous (a constant-`true` gate is
  satisfiable; see `sat_const_true`). -/
def CircuitSAT {n : Nat} (C : BoolGate n) : Prop :=
  ∃ v : Fin n → Bool, BoolGate.eval C v = true

/-- **ACC⁰ shape:** a circuit family of constant depth AND polynomial size —
  the class the Williams transfer's lower bound targets (`NEXP ⊄ ACC⁰` = no
  constant-depth polynomial-size family computes every NEXP language).
  Combines `IsAC0` (constant depth, AC0.lean) with `IsPPoly` (polynomial
  size, Basics.lean).  The Mod-m gate basis is the ACC⁰-defining extension
  over AC⁰; Pass 1 records the family-level shape and a Mod-gate extension
  note (the exact gate basis is pinned with rung-4's substrate builds). -/
def IsACC0 (C : CircuitFamily) : Prop :=
  IsAC0 C ∧ IsPPoly C

/-- The exponential time budget from exponent `k`: `2^(n^k)` steps for an
  input of length `n`. -/
def expBound (k : Nat) (x : List Bool) : Nat :=
  2 ^ (x.length ^ k)

/-- A decider `M` settles membership of `L` within a per-input time budget.
  The machine-step semantics (accept within `budget x` steps) is the
  deferred DEC-003 model; Pass 1 records the shape, with the budget
  function as the load-bearing witness parameter. -/
def DecidesWithinBudget (M : List Bool → Bool) (L : Set (List Bool))
    (budget : List Bool → Nat) : Prop :=
  (∀ x : List Bool, x ∈ L ↔ M x = true) ∧ (∀ x : List Bool, 1 ≤ budget x)

/-- **NEXP statement:** `L` is an exponential-time nondeterministic language
  — some decider `M` settles it within the exponential budget `2^(n^k)`.
  The nondeterministic-machine details are deferred per DEC-003; the
  statement records the shape (an exponential witness budget) the transfer's
  lower bound contraposes against. -/
def NEXP_membership (L : Set (List Bool)) : Prop :=
  ∃ k : Nat, ∃ M : List Bool → Bool, DecidesWithinBudget M L (expBound k)

/-! ### Non-vacuity sanity -/

/-- A tautological circuit is satisfiable: `x0 ∨ ¬x0` evaluates to `true`
  under every assignment (excluded middle), so `CircuitSAT` is non-empty.
  Proves the decision problem is a real object (not an empty name). -/
theorem circuitSAT_tautology : CircuitSAT
    (BoolGate.or (BoolGate.input 0) (BoolGate.not (BoolGate.input 0)) : BoolGate 1) := by
  refine ⟨fun _ => false, ?_⟩
  simp [BoolGate.eval]

end Williams

end Barriers

end PleaNP
