import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-!
# Marker funeq/funne — Candidate A: unconditional-atom reading (as-implemented)

Issue #41, slot 1. Reproduces the **as-implemented** reading of the
`Relativizing.funeq` / `Relativizing.funne` markers (the unconditional
oracle-oblivious atom instances in `PleaNP.Calculus.BarrierCalculus`,
lines 145–163) as an **isolated, self-contained candidate module**.

This candidate formalizes the semantics as:

  - a marker class `MarkerAtom` (role: `Relativizing` in the as-implemented
    calculus);
  - the **unconditional atom instances**
    `MarkerAtom.funeq` / `MarkerAtom.funne`: for any `p q : α → Prop`,
    the function-level claim `p = q` (resp. `p ≠ q`) relativizes *without
    inspecting the fibers* — the equality reports on the functions
    themselves, not on any oracle query, so it is oracle-oblivious
    unconditionally;
  - the disjunctive closure `p = q ∨ p ≠ q` under the atom reading.

The declaration `atomEqOrNe` below is the candidate's "shape statement": the
one `#barrier_check`-like synthesis goal that the as-implemented reading must
discharge. It compiles under this module's own marker class, proving the
unconditional-atom semantics is internally coherent. It does NOT register
any instance in the global `Relativizing` class — the global calculus's
instances are untouched (isolated sibling per the campaign protocol).

See `lean/PleaNP/Calculus/MarkerFuneqPointwise.lean` for the paired
candidate (the pointwise propagation reading, as originally requested in
#1), and `churn/marker-funeq/` for the campaign workspace.
-/

namespace PleaNP

namespace Calculus

namespace MarkerFuneqAtom

open PleaNP.Calculus

-- The oracle/language atoms are imported from BarrierCalculus (shared
-- substrate; only the *marker* reading differs between the two candidates).

/-- Candidate marker class (slot 1, as-implemented reading): a prop-carrying
  marker whose semantics is the **unconditional atom** form — the function
  equality/inequality markers are oracle-oblivious atoms, so their instances
  are declared unconditionally (no per-fiber hypotheses). -/
class MarkerAtom (α : Sort u) : Prop where

/-- Seed instance: oracle-relative atom relativizes (shared with the
  as-implemented calculus). -/
instance MarkerAtom.relAtom {O : Type} {A : AbstOracle O} :
    MarkerAtom ( RelAtom O A) := ⟨⟩

/-- Seed instance: oracle-relative language atom. -/
instance MarkerAtom.langAtom {O : Type} {A : AbstOracle O} {L : O → Prop} :
    MarkerAtom ( LangAtom O A L) := ⟨⟩

/-- Propagation: conjunction. -/
instance MarkerAtom.and {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p ∧ q) := ⟨⟩

/-- Propagation: disjunction. -/
instance MarkerAtom.or {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p ∨ q) := ⟨⟩

/-- Propagation: implication. -/
instance MarkerAtom.imp {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p → q) := ⟨⟩

/-- Propagation: iff. -/
instance MarkerAtom.iff {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p ↔ q) := ⟨⟩

/-- Propagation: negation. -/
instance MarkerAtom.not {p : Prop} [MarkerAtom p] :
    MarkerAtom ( ¬ p) := ⟨⟩

/-- Propagation: universal quantification. -/
instance MarkerAtom.forall {α : Sort u} {p : α → Prop}
    [_h : (a : α) → MarkerAtom (p a)] : MarkerAtom (∀ a, p a) := ⟨⟩

/-- Propagation: existential quantification. -/
instance MarkerAtom.exists {α : Sort u} {p : α → Prop}
    [_h : (a : α) → MarkerAtom (p a)] : MarkerAtom (∃ a, p a) := ⟨⟩

/-- Propagation: propositional equality. -/
instance MarkerAtom.eq {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p = q) := ⟨⟩

/-- Propagation: propositional inequality. -/
instance MarkerAtom.ne {p q : Prop} [MarkerAtom p] [MarkerAtom q] :
    MarkerAtom ( p ≠ q) := ⟨⟩

/-- **The as-implemented unconditional atom instances.** The equality of two
  FIXED predicates is oracle-oblivious: it reports on the functions
  themselves, not on any oracle query — so it relativizes unconditionally,
  with NO pointwise/marker hypothesis. This mirrors exactly
  `PleaNP.Calculus.Relativizing.funeq` / `.funne` (BarrierCalculus.lean
  lines 145–163). -/
instance MarkerAtom.funeq {α : Sort u} {p q : α → Prop} :
    MarkerAtom ( p = q) := ⟨⟩

/-- Same rationale (as-implemented, unconditional) for function inequality. -/
instance MarkerAtom.funne {α : Sort u} {p q : α → Prop} :
    MarkerAtom ( p ≠ q) := ⟨⟩

/-- The shape statement under the **atom** reading: for any oracle A and
  oracle-relative witness languages L1 L2, the disjunction of the
  function-level equality and inequality relativizes *unconditionally*.
  Instance synthesis discharges it purely from the unconditional
  `funeq`/`funne` atom instances — no pointwise fiber markers required. -/
theorem atomEqOrNe (O : Type) (_A : AbstOracle O) (L1 L2 : O → Prop) :
    MarkerAtom ( L1 = L2 ∨ L1 ≠ L2) := by
  infer_instance

end MarkerFuneqAtom

end Calculus

end PleaNP