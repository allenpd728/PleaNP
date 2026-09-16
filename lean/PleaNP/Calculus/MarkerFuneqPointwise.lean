import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-!
# Marker funeq/funne — Candidate B: pointwise-propagation reading (as-#1-requested)

Issue #41, slot 2. Formalizes the **pointwise propagation** reading of the
`Relativizing.funeq` / `Relativizing.funne` markers — the form originally
requested in #1 — as an **isolated, self-contained candidate module**.

This candidate formalizes the semantics as:

  - a marker class `MarkerPW` (the slot-2 analogue of the as-implemented
    `MarkerAtom`; kept under its OWN name so neither candidate registers a
    second global `Relativizing` instance — overlapping instances would risk
    nondeterministic `#barrier_check` synthesis);
  - the **pointwise propagation instances**
    `MarkerPW.funeq` / `MarkerPW.funne`.

The pointwise reading differs from the atom reading in exactly the
`funeq`/`funne` clause: instead of being unconditional atoms, the
function-level claim `p = q` relativizes **only when every fiber's
proposition relativizes** (`(x : α) → MarkerPW (p) (q) (x)` — i.e. both
`p x` and `q x` carry the marker pointwise).

The declaration `pointwiseEqOrNe` below is the candidate's shape statement:
the synthesis goal the pointwise reading must discharge. The two candidate
readings make *different* claims about the marker's semantics — the machine
checked equivalence between them is expected to disagree (BLOCKED), and that
disagreement is mined into one plain-language intent probe for the human
per the campaign protocol.

Why NO global `Relativizing` instance is registered here: the campaign
requires the pointwise candidate to keep the elaborator's instance graph
exactly as-is. The pointwise propagation lemma is proved under the `MarkerPW`
class name; `#barrier_check`'s `Relativizing` synthesis is untouched.

See `lean/PleaNP/Calculus/MarkerFuneqAtom.lean` for the paired candidate,
and `churn/marker-funeq/` for the campaign workspace.
-/

namespace PleaNP

namespace Calculus

namespace MarkerFuneqPointwise

open PleaNP.Calculus

/-- Candidate marker class (slot 2, pointwise reading): a prop-carrying marker
  whose semantics for function equality/inequality is **pointwise
  propagation** — the function-level claim relativizes only when each fiber's
  proposition relativizes. -/
class MarkerPW (α : Sort u) : Prop where

/-- Seed instance: oracle-relative atom relativizes (pointwise reading). -/
instance MarkerPW.relAtom {O : Type} {A : AbstOracle O} :
    MarkerPW ( RelAtom O A) := ⟨⟩

/-- Seed instance: oracle-relative language atom. -/
instance MarkerPW.langAtom {O : Type} {A : AbstOracle O} {L : O → Prop} :
    MarkerPW ( LangAtom O A L) := ⟨⟩

/-- Propagation: conjunction. -/
instance MarkerPW.and {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p ∧ q) := ⟨⟩

/-- Propagation: disjunction. -/
instance MarkerPW.or {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p ∨ q) := ⟨⟩

/-- Propagation: implication. -/
instance MarkerPW.imp {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p → q) := ⟨⟩

/-- Propagation: iff. -/
instance MarkerPW.iff {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p ↔ q) := ⟨⟩

/-- Propagation: negation. -/
instance MarkerPW.not {p : Prop} [MarkerPW p] :
    MarkerPW ( ¬ p) := ⟨⟩

/-- Propagation: universal quantification. -/
instance MarkerPW.forall {α : Sort u} {p : α → Prop}
    [_h : (a : α) → MarkerPW (p a)] : MarkerPW (∀ a, p a) := ⟨⟩

/-- Propagation: existential quantification. -/
instance MarkerPW.exists {α : Sort u} {p : α → Prop}
    [_h : (a : α) → MarkerPW (p a)] : MarkerPW (∃ a, p a) := ⟨⟩

/-- Propagation: propositional equality. -/
instance MarkerPW.eq {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p = q) := ⟨⟩

/-- Propagation: propositional inequality. -/
instance MarkerPW.ne {p q : Prop} [MarkerPW p] [MarkerPW q] :
    MarkerPW ( p ≠ q) := ⟨⟩

/-- **The pointwise propagation instances** (the #1-requested reading).
  The function-level equality `p = q` relativizes **pointwise** — provided
  the marker holds on every fiber of BOTH functions (`(x : α) → MarkerPW
  (p x)` and `(x : α) → MarkerPW (q x)`). This is strictly stronger than
  the unconditional atom form: under this reading, a function equality
  whose fibers are not individually marked does NOT carry the marker. -/
instance MarkerPW.funeq {α : Sort u} {p q : α → Prop}
    [_hp : (x : α) → MarkerPW (p x)] [_hq : (x : α) → MarkerPW (q x)] :
    MarkerPW ( p = q) := ⟨⟩

/-- Same pointwise rationale for function inequality. -/
instance MarkerPW.funne {α : Sort u} {p q : α → Prop}
    [_hp : (x : α) → MarkerPW (p x)] [_hq : (x : α) → MarkerPW (q x)] :
    MarkerPW ( p ≠ q) := ⟨⟩

/-- The shape statement under the **pointwise** reading: for any oracle A, if
  the witness languages `L1 L2 : O → Prop` are pointwise-marked (every fiber
  `L1 x` / `L2 x` carries the marker), then the disjunction of the
  function-level equality and inequality relativizes.

  Note the difference from the atom reading: here, synthesis **requires**
  the pointwise marker hypotheses on the fibers. If `L1`/`L2` were left
  unmarked, this statement would NOT synthesize — the pointwise reading is
  strictly stronger than the unconditional-atom reading. That difference is
  the semantic disagreement the campaign mines. -/
theorem pointwiseEqOrNe (O : Type) (_A : AbstOracle O) (L1 L2 : O → Prop)
    [hL1 : (x : O) → MarkerPW (L1 x)]
    [hL2 : (x : O) → MarkerPW (L2 x)] :
    MarkerPW ( L1 = L2 ∨ L1 ≠ L2) := by
  infer_instance

end MarkerFuneqPointwise

end Calculus

end PleaNP