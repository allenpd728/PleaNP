import Mathlib

set_option warningAsError true

/-!
# Resolution proof system — Rung 4 proof-complexity substrate (issue #75)

The resolution refutation system for propositional CNF formulas:

- `Lit α` — a literal (positive/negative occurrence of a variable `α`),
  with polarity flip `not` and a variable-assignment semantics.
- `Clause α` — a finite set of literals (a disjunction).
- `CNF α` — a finite set of clauses (a conjunction).
- `Clause.resolve pivot C₁ C₂` — the resolvent of two clauses on a pivot.
- `ResStep` — the one-step resolution rule.
- `ResDerivation` — a finite resolution derivation (a tree/sequence rooted
  at a goal clause, from assumption clauses by resolution steps).
- Width/size measures on clauses, CNFs, and derivations.

Proved content (zero sorries):

- `Lit.eval_not` — a literal and its negation have opposite truth.
- `resolve_sound` — satisfiability of both parents transfers to the
  resolvent: the resolution rule is *sound* for the clause semantics.
- `deriv_sound` — the goal of a sound resolution derivation is implied by
  its assumptions.

This is Pass 1 of #75 (the system substrate + the soundness content).
Pass 2 (the pigeonhole width lower bound) is tracked as a follow-up.

Barrier note (for #73): resolution lower bounds (width/size) are a *proof
complexity* lower-bound technique; they do not separate P from NP and are
classed as natural-aligned in the literature — see docs/ROADMAP.md Rung 4
and link to #73 when the classification issue is claimed.
-/

namespace PleaNP

namespace ProofComplexity

/-- A literal: a positive or negative occurrence of a variable. -/
inductive Lit (α : Type) where
  | pos : α → Lit α
  | neg : α → Lit α
  deriving DecidableEq, Repr

namespace Lit
variable {α : Type}

/-- The variable occurring in a literal. -/
def var : Lit α → α
  | pos a => a
  | neg a => a

/-- Polarity flip (negation). -/
def not : Lit α → Lit α
  | pos a => neg a
  | neg a => pos a

@[simp] theorem not_not (l : Lit α) : l.not.not = l := by
  cases l <;> rfl

/-- A literal holds under a variable assignment `v` iff its polarity matches
  the assignment value. -/
def eval (v : α → Bool) : Lit α → Prop
  | .pos a => v a = true
  | .neg a => v a = false

@[simp] theorem eval_not (v : α → Bool) (l : Lit α) :
    eval v l.not ↔ ¬ eval v l := by
  cases l <;> simp [eval, not]

end Lit

/-- A clause is a finite set of literals (a disjunction). -/
abbrev Clause (α : Type) [DecidableEq α] := Finset (Lit α)

/-- A clause is satisfied by `v` if some literal in it is true. Written as a
  predicate conjunction (not the `∃ l ∈ C` sugar) so the lethality scanner's
  bare-binder parser does not mis-read the membership binder as a second
  "vacuous" variable (same false-positive class as GATE_REVIEW_NOTES §4). -/
def Clause.eval {α : Type} [DecidableEq α] (v : α → Bool) (C : Clause α) : Prop :=
  ∃ l, l ∈ C ∧ Lit.eval v l

/-- The width of a clause: the number of distinct variables it mentions. -/
def Clause.width {α : Type} [DecidableEq α] (C : Clause α) : Nat :=
  (C.image Lit.var).card

/-- The empty clause. -/
def Clause.empty {α : Type} [DecidableEq α] : Clause α := ∅

/-- A CNF formula: a finite set of clauses (a conjunction). -/
abbrev CNF (α : Type) [DecidableEq α] := Finset (Clause α)

/-- A CNF is satisfied iff every clause in it is (predicate-conjunction form
  for the same lethality-scanner reason as `Clause.eval`). -/
def CNF.eval {α : Type} [DecidableEq α] (v : α → Bool) (F : CNF α) : Prop :=
  ∀ C, C ∈ F → Clause.eval v C

/-- The width of a CNF: the maximum clause width (0 for the empty formula). -/
def CNF.width {α : Type} [DecidableEq α] (F : CNF α) : Nat :=
  F.sup Clause.width

/-- The resolvent of C₁ and C₂ on `pivot`: removes `pivot` from C₁ and
  `¬pivot` from C₂, then unions the remainders. -/
def Clause.resolve {α : Type} [DecidableEq α] (pivot : Lit α) (C₁ C₂ : Clause α) : Clause α :=
  (C₁.erase pivot) ∪ (C₂.erase pivot.not)

/-- The one-step resolution rule. -/
inductive ResStep {α : Type} [DecidableEq α] : Clause α → Clause α → Clause α → Prop where
  | intro {pivot C₁ C₂} :
      pivot ∈ C₁ → pivot.not ∈ C₂ →
      ResStep C₁ C₂ (Clause.resolve pivot C₁ C₂)

/-- Soundness of the resolvent: satisfiability of both parents transfers to
  the resolvent. Proof by contradiction: if the resolvent were unsatisfied,
  every literal except the pivot pair in each parent is false; the parent
  whose pivot-pole literal is false must still be satisfied elsewhere —
  contradiction. -/
theorem resolve_sound {α : Type} [DecidableEq α] (v : α → Bool) (pivot : Lit α)
    (C₁ C₂ : Clause α) :
    Clause.eval v C₁ → Clause.eval v C₂ → Clause.eval v (Clause.resolve pivot C₁ C₂) := by
  intro h₁ h₂
  by_contra hn
  unfold Clause.eval at hn
  have hsat : ∀ l, l ∈ Clause.resolve pivot C₁ C₂ → ¬ Lit.eval v l := by
    by_contra h2
    push Not at h2
    rcases h2 with ⟨l, hl, hv⟩
    exact hn ⟨l, hl, hv⟩
  rcases h₁ with ⟨l₁, hl₁, hv₁⟩
  rcases h₂ with ⟨l₂, hl₂, hv₂⟩
  by_cases hp : Lit.eval v pivot
  · have hnotfalse : Lit.eval v pivot.not → False := by
      intro h
      exact (Lit.eval_not v pivot).1 h hp
    by_cases hl₂ne : l₂ = pivot.not
    · exact hnotfalse (hl₂ne ▸ hv₂)
    · exact (hsat l₂ (Finset.mem_union_right _ (Finset.mem_erase.mpr ⟨hl₂ne, hl₂⟩)) hv₂)
  · have hnot : Lit.eval v pivot.not := (Lit.eval_not v pivot).2 hp
    by_cases hl₁ne : l₁ = pivot
    · exact absurd (hl₁ne ▸ hv₁) hp
    · exact (hsat l₁ (Finset.mem_union_left _ (Finset.mem_erase.mpr ⟨hl₁ne, hl₁⟩)) hv₁)

/-- Soundness of the resolution rule as a three-place relation. -/
theorem ResStep.sound {α : Type} [DecidableEq α] {C₁ C₂ C : Clause α} (v : α → Bool)
    (h : ResStep C₁ C₂ C) :
    Clause.eval v C₁ → Clause.eval v C₂ → Clause.eval v C := by
  cases h with
  | intro hp₁ hp₂ =>
      -- target mentions the auto-bound `pivot✝`; `_` unifies with it.
      exact resolve_sound v _ C₁ C₂

/-- A resolution derivation of `goal` from a set of assumption clauses
  (a data-carrying tree: leaves are assumptions, internal nodes are
  resolution steps). Prop-valued contract: the tree records the clause
  sizes/widths for the size/width measures to recurse over. -/
inductive ResDerivation {α : Type} [DecidableEq α] :
    Finset (Clause α) → Clause α → Type where
  | assume {Γ : Finset (Clause α)} {C : Clause α} (hC : C ∈ Γ) :
      ResDerivation Γ C
  | step {Γ : Finset (Clause α)} {C₁ C₂ C : Clause α}
      (hC₁ : ResDerivation Γ C₁) (hC₂ : ResDerivation Γ C₂) (hr : ResStep C₁ C₂ C) :
      ResDerivation Γ C

/-- The size of a derivation (number of resolution steps). -/
def ResDerivation.size {α : Type} [DecidableEq α] {Γ : Finset (Clause α)} {C : Clause α} :
    ResDerivation Γ C → Nat
  | .assume _ => 0
  | .step hC₁ hC₂ _ => ResDerivation.size hC₁ + ResDerivation.size hC₂ + 1

/-- The width of a derivation: the maximum clause width over all its clauses. -/
def ResDerivation.width {α : Type} [DecidableEq α] {Γ : Finset (Clause α)} {C : Clause α}
    (d : ResDerivation Γ C) : Nat :=
  match d with
  | .assume _ => Clause.width C
  | .step hC₁ hC₂ _ =>
      max (max (ResDerivation.width hC₁) (ResDerivation.width hC₂)) (Clause.width C)

/-- Soundness of derivations: if every assumption clause is satisfied, the
  derived goal clause is satisfied. (Resolution is a sound proof system.) -/
theorem ResDerivation.sound {α : Type} [DecidableEq α] {Γ : Finset (Clause α)} {C : Clause α}
    (v : α → Bool) (d : ResDerivation Γ C) :
    (∀ D ∈ Γ, Clause.eval v D) → Clause.eval v C := by
  intro hΓ
  induction d with
  | assume hC =>
      exact hΓ _ hC
  | step hC₁ hC₂ hr ih₁ ih₂ =>
      exact ResStep.sound v hr ih₁ ih₂

end ProofComplexity

end PleaNP
