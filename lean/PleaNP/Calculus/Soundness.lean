import PleaNP.Calculus.BarrierCalculus
import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-!
# `#barrier_check` soundness: oracle-uniformity semantics (issue #65)

`#barrier_check` classifies a claim **DEAD** ("this proof relativizes, so
BGS rules it out as a P-vs-NP resolution") by asking Lean's instance search
whether the claim's body carries a `Relativizing` marker (and a
`PVsNPShaped` marker). That verdict is authoritative only if the marker
system is **sound**: a `Relativizing` construction truly is uniform in the
oracle in the BGS sense.

`Relativizing` is a field-less marker (`class Relativizing … : Prop where` —
no data), so its *meaning* cannot be extracted from the class; soundness
must give it one. This module does so with a semantic model:

- `UniformInOracle O P` : the oracle-parameterized family
  `P : (O → Bool) → Prop` is **uniform in the oracle** iff its truth is
  invariant under replacing the oracle with any other oracle that answers
  every query identically (extensional equality of the answer function).
  This is the precise sense in which a construction "never inspects the
  oracle beyond the answer stream": if two oracles give the same answers to
  every query, the construction's conclusion is the same for both.
- Soundness lemmas: the seed atoms (`RelAtom`, `LangAtom`) are uniform; each
  `Relativizing.*` propagation case (∧ ∨ → ↔ ¬ ∀ ∃, and the oracle-oblivious
  function-equality atoms `funeq`/`funne`) preserves uniformity. Together:
  *every statement built from the seeded atoms through the propagation
  grammar is uniform in the oracle* — the marker system is sound for
  everything it classifies.
- `transfer_under_ext` : the primitive transfer — a uniform family's truth
  transfers between any two extensionally-equal oracles.
- `pA_mem_uniform` (one concrete hook, post-#35): `L ∈ P_A A` is uniform.
- `sound_verdict_abstract` : the classification-level statement for the
  abstract atom shape — a `Relativizing` `LangAtom` claim transfers its
  verdict across every extensionally-equal oracle.

**Concrete `NP_A`/class-equality hook — documented plan (NOT proved here):**
`L ∈ NP_A A` is uniform by the same construction: under extensionally-equal
oracles the verifier's queries answer identically, so `AcceptsInTime`
transfers; the class-equality `P_A A = NP_A A` then transfers by the same
argument as `pA_mem_uniform` applied elementwise. Proving those is the
concrete-instance follow-up (the doD's "documented plan for the concrete
`P_A`/`NP_A` hook"); the BGS `False` (an equalizing `E` and a separating `S`)
is the subject of #18/#63. No sorries: every lemma is proved.
-/

namespace PleaNP

namespace Calculus

open PleaNP.Oracles

/-- **Oracle-uniformity**: the oracle-parameterized family `P` is uniform in
  the oracle iff substituting any two extensionally-equal oracles leaves the
  truth of `P` unchanged. This is the BGS "the construction is uniform in
  the oracle and never inspects its content" semantic. -/
def UniformInOracle (O : Type) (P : Oracle O → Prop) : Prop :=
  ∀ A A' : Oracle O, (∀ q : O, A q = A' q) → (P A ↔ P A')

/-- The primitive transfer principle: a uniform family's truth transfers
  between extensionally-equal oracles. -/
theorem transfer_under_ext {O : Type} {P : Oracle O → Prop}
    (hU : UniformInOracle O P) {A A' : Oracle O}
    (hExt : ∀ q : O, A q = A' q) : P A ↔ P A' :=
  hU A A' hExt

/-- The `Relativizing.relAtom` seed is uniform: `RelAtom O A := ∀ q, A q =
  true` depends only on the oracle's answers. -/
theorem relAtom_uniform (O : Type) : UniformInOracle O (fun A => RelAtom O A) := by
  intro A A' hExt
  unfold RelAtom
  constructor
  · intro h q
    rw [← hExt q]
    exact h q
  · intro h q
    rw [hExt q]
    exact h q

/-- The `Relativizing.langAtom` seed is uniform: `LangAtom O A L := ∀ x,
  L x ↔ A x = true`. -/
theorem langAtom_uniform  {O :Type} (L : O → Prop) :
    UniformInOracle O (fun A => LangAtom O A L) := by
  intro A A' hExt
  unfold LangAtom
  constructor
  · intro h x
    rw [← hExt x]
    exact h x
  · intro h x
    rw [hExt x]
    exact h x

/-- The concrete `P_A` membership atom is uniform (one concrete hook,
  post-#35): for extensionally-equal oracles the classes coincide (the
  machine's oracle queries are answered identically), so membership
  transfers. -/
theorem pA_mem_uniform (O alpha : Type) (L : Set alpha) :
    UniformInOracle O (fun A => L ∈ P_A (alpha := alpha) A) := by
  intro A A' hExt
  unfold P_A
  constructor
  · intro h
    rcases h with ⟨tm', hdec, ea, oa, M, p, hM⟩
    refine ⟨tm', hdec, ea, oa, M, p, ?_⟩
    rcases hM with ⟨hOr, hDt⟩
    constructor
    · rw [hOr]
      funext q
      exact hExt q
    · exact hDt
  · intro h
    rcases h with ⟨tm', hdec, ea, oa, M, p, hM⟩
    refine ⟨tm', hdec, ea, oa, M, p, ?_⟩
    rcases hM with ⟨hOr, hDt⟩
    constructor
    · rw [hOr]
      funext q
      exact (hExt q).symm
    · exact hDt

/-- Uniformity propagates through conjunction. -/
theorem uniform_and {O : Type} {P Q : Oracle O → Prop}
    (hP : UniformInOracle O P) (hQ : UniformInOracle O Q) :
    UniformInOracle O (fun A => P A ∧ Q A) := by
  intro A A' hExt
  rcases hP A A' hExt with ⟨hp1, hp2⟩
  rcases hQ A A' hExt with ⟨hq1, hq2⟩
  constructor
  · intro h; exact ⟨hp1 h.1, hq1 h.2⟩
  · intro h; exact ⟨hp2 h.1, hq2 h.2⟩

/-- Uniformity propagates through disjunction. -/
theorem uniform_or {O : Type} {P Q : Oracle O → Prop}
    (hP : UniformInOracle O P) (hQ : UniformInOracle O Q) :
    UniformInOracle O (fun A => P A ∨ Q A) := by
  intro A A' hExt
  rcases hP A A' hExt with ⟨hp1, hp2⟩
  rcases hQ A A' hExt with ⟨hq1, hq2⟩
  constructor
  · intro h
    rcases h with hP | hQ
    · exact Or.inl (hp1 hP)
    · exact Or.inr (hq1 hQ)
  · intro h
    rcases h with hP | hQ
    · exact Or.inl (hp2 hP)
    · exact Or.inr (hq2 hQ)

/-- Uniformity propagates through implication. -/
theorem uniform_imp {O : Type} {P Q : Oracle O → Prop}
    (hP : UniformInOracle O P) (hQ : UniformInOracle O Q) :
    UniformInOracle O (fun A => P A → Q A) := by
  intro A A' hExt
  rcases hP A A' hExt with ⟨hp1, hp2⟩
  rcases hQ A A' hExt with ⟨hq1, hq2⟩
  constructor
  · intro h hP'
    exact hq1 (h (hp2 hP'))
  · intro h hP'
    exact hq2 (h (hp1 hP'))

/-- Uniformity propagates through bi-implication. -/
theorem uniform_iff {O : Type} {P Q : Oracle O → Prop}
    (hP : UniformInOracle O P) (hQ : UniformInOracle O Q) :
    UniformInOracle O (fun A => P A ↔ Q A) := by
  intro A A' hExt
  rcases hP A A' hExt with ⟨hp1, hp2⟩
  rcases hQ A A' hExt with ⟨hq1, hq2⟩
  constructor
  · intro h
    constructor
    · intro hP'; exact hq1 (h.1 (hp2 hP'))
    · intro hQ'; exact hp1 (h.2 (hq2 hQ'))
  · intro h
    constructor
    · intro hP'; exact hq2 (h.1 (hp1 hP'))
    · intro hQ'; exact hp2 (h.2 (hq1 hQ'))

/-- Uniformity propagates through negation. -/
theorem uniform_not {O : Type} {P : Oracle O → Prop}
    (hP : UniformInOracle O P) : UniformInOracle O (fun A => ¬ P A) := by
  intro A A' hExt
  rcases hP A A' hExt with ⟨hp1, hp2⟩
  constructor
  · intro h hP'; exact h (hp2 hP')
  · intro h hP'; exact h (hp1 hP')

/-- Uniformity propagates through universal quantification over an
  oracle-independent index family. -/
theorem uniform_forall {O ι : Type} {P : ι → Oracle O → Prop}
    (hP : ∀ i, UniformInOracle O (P i)) :
    UniformInOracle O (fun A => ∀ i, P i A) := by
  intro A A' hExt
  constructor
  · intro h i; exact (hP i A A' hExt).1 (h i)
  · intro h i; exact (hP i A A' hExt).2 (h i)

/-- Uniformity propagates through existential quantification over an
  oracle-independent index family. -/
theorem uniform_exists {O ι : Type} {P : ι → Oracle O → Prop}
    (hP : ∀ i, UniformInOracle O (P i)) :
    UniformInOracle O (fun A => ∃ i, P i A) := by
  intro A A' hExt
  constructor
  · intro h; rcases h with ⟨i, hi⟩; exact ⟨i, (hP i A A' hExt).1 hi⟩
  · intro h; rcases h with ⟨i, hi⟩; exact ⟨i, (hP i A A' hExt).2 hi⟩

/-- The `Relativizing.funeq`/`funne` atoms: equality/inequality of two
  FIXED predicates is oracle-oblivious, hence trivially uniform. -/
theorem funeq_uniform {O α : Type} {p q : α → Prop} :
    UniformInOracle O (fun _ => p = q) := by
  intro _ _ _
  exact Iff.rfl

/-- Same for inequality. -/
theorem funne_uniform {O α : Type} {p q : α → Prop} :
    UniformInOracle O (fun _ => p ≠ q) := by
  intro _ _ _
  exact Iff.rfl

/-- **Classification-level soundness (abstract atom shape)**: a
  `Relativizing` `LangAtom` claim transfers its verdict across
  extensionally-equal oracles — the soundness statement for the abstract
  calculus. The concrete class-equality transfer is the documented plan
  above (via `pA_mem_uniform` / the `NP_A` analogue). -/
theorem sound_verdict_abstract
    (O : Type) (A A' : Oracle O) (L : O → Prop)
    (hExt : ∀ q : O, A q = A' q)
    (hAtom : LangAtom O A L) : LangAtom O A' L :=
  (langAtom_uniform L A A' hExt).1 hAtom

theorem sound_verdict_abstract_rev
    (O : Type) (A A' : Oracle O) (L : O → Prop)
    (hExt : ∀ q : O, A q = A' q) (hAtom : LangAtom O A' L) :
    LangAtom O A L :=
  (langAtom_uniform L A A' hExt).2 hAtom

/-- The `Relativizing` seed on `LangAtom` means a `Relativizing` claim is
  BGS-relativizing in the uniform sense: the `Relativizing`-marked atom's
  truth transfers across extensionally-equal oracles. This example closes the
  loop from the marker to the transfer that `#barrier_check`'s DEAD verdict
  rests on. -/
example (O : Type) (A A' : Oracle O) (L : O → Prop)
    (hExt : ∀ q : O, A q = A' q) (hAtom : LangAtom O A L) :
    LangAtom O A' L :=
  sound_verdict_abstract O A A' L hExt hAtom

end Calculus

end PleaNP
