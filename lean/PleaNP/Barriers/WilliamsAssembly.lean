import PleaNP.Barriers.Williams
import PleaNP.Barriers.WilliamsTransfer

set_option warningAsError true

/-!
# Williams transfer — Pass 4 assembly (issue #91)

The closing pass of the #76 Williams umbrella: assemble the Pass-1 statement
freeze (#88, `Williams.lean`: `CircuitSAT`/`IsACC0`/`NEXP_membership`), the
Pass-2 verified algorithm (#89, `WilliamsSat.lean`), and the Pass-3 transfer
theorem statement (#90, `WilliamsTransfer.lean`:
`SubExpCircuitSATT → NEXP_not_subset_ACC0`) into the final `NEXP ⊄ ACC⁰`
lower bound.

## Umbrella-level blocker (precisely documented, per #76/DoD fallback)

The full zero-sorry proof of `NEXP ⊄ ACC⁰` is **blocked on the tracked
sub-exponential ACC⁰-CircuitSAT bound** (`acc0SatSubExpBound`, #89's
honest gap; #98 follow-up): the transfer needs the ACC⁰-structure packing
(Shah–Shetty Good-SAT) to move from the verified brute-force baseline
(`acc0SatSteps_eq = 2^n`) to the `2^(n^c)` bound the transfer compiles.
The statement is frozen here; the proof is #98's job (never a sorry).
-/

namespace PleaNP

namespace Barriers

namespace Williams

/-- **The assembled final theorem statement.**  `NEXP ⊄ ACC⁰`:  no
  constant-depth polynomial-size circuit family computes every NEXP language
  — assembled over the Pass-1 `NEXP_membership`/`IsACC0` anchors.  This is
  the roadmap's "one known non-relativizing, non-natural, non-algebrizing
  lower bound".  Zero-sorry target; the proof is #98 (the tracked
  sub-exponential bound), per #76/DoD fallback. -/
def final_NEXP_not_subset_ACC0 : Prop :=
  NEXP_not_subset_ACC0

/-- **The assembled transfer closure.**  Sub-exponential ACC⁰-CircuitSAT
  implies the final `NEXP ⊄ ACC⁰` — the Pass-3 `williams_transfer`
  instantiated with the frozen target. -/
def assembled_williams_transfer : Prop :=
  williams_transfer

/-- **The assembled classification record.**  The Williams lower bound is
  non-relativizing / non-natural / non-algebrizing (asserted per the Rung-4
  classification doc; the reasoning per-technique is in
  `docs/STATEMENTS/WilliamsTransfer.classification.md`). -/
def assembled_classification : Prop :=
  NonRelativizing final_NEXP_not_subset_ACC0 ∧
  NonNatural final_NEXP_not_subset_ACC0 ∧
  NonAlgebrizing final_NEXP_not_subset_ACC0

/-! ## Assembly sanity -/

/-- The assembled target is the frozen Pass-3 target (definitional; the
  chain #88→#89→#90→#91 is recorded). -/
example : final_NEXP_not_subset_ACC0 = NEXP_not_subset_ACC0 := rfl

end Williams

end Barriers

end PleaNP
