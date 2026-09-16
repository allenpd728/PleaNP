import PleaNP.Circuits.Basic

set_option warningAsError true

/-!
# Rung-4 circuit substrate — must-refute suite (issue #71 Pass 3)

The `docs/VALIDATION_SUITE.md` must-refute / non-triviality checks for the
`PleaNP.Circuits` substrate (Passes 1-2: `BoolGate` size/depth, `IsPPoly`,
`NaturalProperty`). This module proves the concrete facts that keep the
definitions honest — the definitions are not vacuous and the natural-property
notion is not trivially satisfied:

1. `univ_property_constructive` — the universal property family
   (`C_n = F_n`) is **constructive** (companion to the Pass-2
   `univ_largeness`): `Constructive` is inhabited.
2. `empty_not_largeness` — the empty property family is **NOT large**
   (must-refute: a natural property must be large; the empty family is the
   canonical counterexample).
3. `empty_not_natural` — the empty property family is not a natural property
   (direct from 2).
4. `boolfunc_card` — `|F_n| = 2^n` (the counting baseline every lower-bound
   argument uses; makes the largeness fraction meaningful).

Zero sorries. The suite records the "typed → validated" step of the
validation ladder for the Circuits substrate.
-/

namespace PleaNP

namespace Circuits

/-- The universal property family is constructive: membership in `Set.univ`
  is decided by the constant-`true` characteristic function at every length. -/
lemma univ_property_constructive : Constructive (fun _ : Nat => Set.univ) := by
  unfold Constructive
  intro n
  refine ⟨fun _ => true, ?_⟩
  intro f
  simp

/-- The empty property family is NOT large: each `∅_n` has cardinality 0
  while largeness needs `2^n · |C_n| ≥ |F_n| > 0` for all large `n`. -/
lemma empty_not_largeness : ¬ Largeness (fun _ : Nat => (∅ : Set (BoolFunc _))) := by
  unfold Largeness
  push Not
  intro n₀
  refine ⟨n₀ + 1, by omega, ?_⟩
  simp [BoolFunc]

/-- The empty property family is not a natural property (largeness fails). -/
lemma empty_not_natural : ¬ NaturalProperty (fun _ : Nat => (∅ : Set (BoolFunc _))) := by
  intro h
  exact empty_not_largeness h.2

/-- The number of n-ary Boolean functions is `2^n` (each of the `n` variables
  maps to two values) — the counting baseline for lower-bound arguments. -/
lemma boolfunc_card (n : Nat) : Fintype.card (BoolFunc n) = 2 ^ n := by
  simp [BoolFunc]

end Circuits

end PleaNP