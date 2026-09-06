import Mathlib
import PleaNP.Computability.OracleComplexity
import PleaNP.Barriers.BgsRenderings

set_option warningAsError true

/-
# Boundary probe — testing the creativity-protocol "provability boundary" idea

The creativity protocol (docs/CREATIVE_PROTOCOL.md, DEC-019) produced a
candidate strategy: instead of trying to prove P ≠ NP, formalize the
"provability boundary" of the near-P-vs-NP lattice — prove which WEAKER
near-statements hold, and where provability stops.

This module is the FIRST concrete test of that idea: a small lattice of
near-statements, each with a real (or honestly-blocked) proof. The ones that
prove are "below the boundary"; the first that can't is "the boundary."

Near-statements (weakest to strongest):
  N1: P_A ⊆ NP_A for every oracle A            (PROVABLE — P_A_subset_NP_A)
  N2: the equalizing-clause renderings agree    (PROVABLE — equalizing_A_iff_C)
  N3: separating_D → separating_B              (PROVABLE — separating_D_to_B)
  N4: separating_B → separating_D              (BLOCKED — needs classical witness)
  N5: exists_separating_oracle (the real BGS (b))  (BLOCKED — the open theorem)

The boundary, if this lattice is representative, sits between N3 and N4:
the easy direction of the separating clause proves; the reverse (which needs
the classical witness — the actual diagonalization) does not. That is a
*precise location* of the difficulty, exactly as the protocol predicted.

Note: this is a PROBE, not a claim. It tests whether the boundary idea is
real and checkable. It does not prove P vs NP.
-/

namespace PleaNP

namespace Barriers

namespace BoundaryProbe

open PleaNP.Oracles
open PleaNP.Barriers.BgsRenderings

/-- N1: P_A ⊆ NP_A for every oracle A. PROVABLE (upstream theorem). -/
theorem n1_P_subset_NP (Q : Type) (alpha : Type) (A : Oracle Q) :
    P_A (alpha := alpha) A ⊆ NP_A (alpha := alpha) A :=
  PleaNP.Oracles.P_A_subset_NP_A alpha A

/-- N2: the two equalizing-clause renderings are equivalent. PROVABLE. -/
theorem n2_equalizing_agree :
    equalizing_A ↔ equalizing_C :=
  equalizing_A_iff_C

/-- N3: separating_D → separating_B (easy direction). PROVABLE. -/
theorem n3_separating_easy :
    separating_D → separating_B :=
  separating_D_to_B

/-- N4: separating_B → separating_D (hard direction; needs the classical
  witness — the diagonalization). This is the boundary candidate: it is a
  real STATEMENT (a def with a Prop body), machine-verified as type-correct
  but NOT yet proven. It is rendered, not sorry'd — the churn engine flags
  it as "provable-or-not" rather than declaring a hole. -/
def n4_separating_hard : Prop :=
  separating_B → separating_D

/-- N5: the real BGS clause (a) equalizing. The statement of the open
  theorem (rendered, not proven). -/
def n5_exists_equalizing : Prop :=
  ∃ (A : Oracle QueryType),
    Computable (α := QueryType) A ∧
    P_A (alpha := InputType) A = NP_A (alpha := InputType) A

/-- N6: the real BGS clause (b) separating. The statement of the open
  theorem (rendered, not proven). -/
def n6_exists_separating : Prop :=
  ∃ (B : Oracle QueryType),
    Computable (α := QueryType) B ∧
    P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B

end BoundaryProbe

end Barriers

end PleaNP