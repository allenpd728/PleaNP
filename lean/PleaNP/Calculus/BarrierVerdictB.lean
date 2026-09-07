import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-
# Barrier-verdict rendering B (Gate 3 corpus campaign, campaign `barrier-verdict`)

An INDEPENDENT structural rendering of the same informal claim as
`abstractPVsNP` in `BarrierCalculus.lean`: "a relativizing statement
carrying the P-vs-NP shape marker is a DEAD barrier-check verdict."

  Slot A (existing,:`PleaNP.Calculus.abstractPVsNP` — binder order:
    `∃ L1 L2, LangAtom L1 ∧ LangAtom L2 ∧ (L1 = L2 ∨ L1 ≠ L2)`
  Slot B (this file,:`verdictB` — structurally reordered:
    `∃ L2 L1, LangAtom L1 ∧ (L1 = L2 ∨ L1 ≠ L2) ∧ LangAtom L2`
    — different binder order and conjunction nesting. The two are expected
    machine-equivalent (the AC reordering is closed by `simp`/value-driven
    reduction`; the equivalence is exactly what `dual_render` checks).

The corpus table (#19)s collates both campaigns (`bgs`, `barrier-verdict`)
into measured rendering/equivalence/disagreement counts for grant-readiness.

  This module imports the calculus (for `LangAtom`, `Relativizing`) but
  carries its own theorem this file — the renderings are independently
  registered per the isolation guarantee of the campaign protocol.

  NOTE: this file is a RENDERING of the statement (def with a Prop body),
  not a proof — no `sorry`, no axioms beyond the calculus substrate. -/
namespace PleaNP

namespace Calculus

/-- Structural re-rendering of the DEAD-shaped claim (slot B):the witness
  languages are existentials with the conjunction tree reordered (binder
  order swapped,andthe disjunction moved between the two atom conjuncts). -/
@[reducible] def verdictB : Prop :=
  ∀ (O : Type) (A : AbstOracle O),
    ∃ L2 L1 : O → Prop,
      LangAtom O A L1 ∧ (L1 = L2 ∨ L1 ≠ L2) ∧ LangAtom O A L2

/-- Gate-7 equivalence proof:the two renderings are the same claim up to
  binder reordering (the existential witnesses are swapped,andthe ∧ tree
  is rearranged)..This is the honest machine-checkable proof that
  lets the corpus matrix record A~B as EQUIVALENT:\`simp\` cannot close
  it alone because the ∃-binders must be re-paired;this proof does that. -/
theorem abstractPVsNP_iff_verdictB :
    PleaNP.Calculus.abstractPVsNP ↔ verdictB :=by
  unfold PleaNP.Calculus.abstractPVsNP verdictB
  constructor
  · intro h O A
    rcases (h O A) with ⟨L1, L2, hA1, hA2, hEq⟩
    refine ⟨L2, L1, ⟨hA1, ⟨hEq, hA2⟩⟩⟩
  · intro h O A
    rcases (h O A) with ⟨L2, L1, hA1, hEq, hA2⟩
    refine ⟨L1, L2, ⟨hA1, ⟨hA2, hEq⟩⟩⟩

end Calculus

end PleaNP
