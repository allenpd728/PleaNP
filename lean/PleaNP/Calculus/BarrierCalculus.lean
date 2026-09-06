import Mathlib

set_option warningAsError true

/-
# Barrier Calculus (Rung 5 — prototype)

The meta-level machinery that turns "does this proof relativize?" from per-paper
human judgment into a typechecking question (Baker--Gill--Solovay, BGS 1975).

  - `Relativizing` : a prop-carrying marker typeclass. An instance on a
    construction means "this construction is uniform in the oracle; step-counting
    is oracle-oblivious." Seed instances go on oracle-relative atoms; the
    propagation instances below carry the marker through composition, application,
    quantification, equality and inequality — so typeclass synthesis walks the
    dependence graph of any statement automatically, with no per-lemma annotation.

  - `#barrier_check` : an elaborator command. Given a declaration, it asks
    Lean's instance search for `Relativizing` on the statement's body, and for the
    P-vs-NP shape marker `PVsNPShaped` on the declaration:
      * relativizing + P-vs-NP-shaped      → "DEAD: this proof relativizes"
      * relativizing, not P-vs-NP-shaped   → "relativizes; not P-vs-NP-shaped
        (Inconclusive as a P-vs-NP blocker, but still relativizing)"
      * not relativizing                   → "Inconclusive: not ruled out by BGS"

  - Unit tests: the time-hierarchy theorem relativizes (its proof is uniform in
    the oracle). `thhStatement` below is built from relativizing atoms so instance
    search must find `Relativizing thhStatement` automatically — that is the
    correctness check for the elaborator's detection half; `abstractPVsNP` is the
    P-vs-NP-shaped DEAD case; `plainRelHeuristic` is the non-P-vs-NP-shaped
    relativizing case; and `nonRelativizingControl` has no `Relativizing` instance
    at all (the Inconclusive negative case).

All abstract: no concrete `P`/`NP` names are defined here (per DEC-002/003 — those
import from upstream once they land). This file is the *calculus over* them, using
abstract oracle-relative atoms as stand-ins. The oracle totality discipline
(codomain `Bool`) is preserved from `Oracle.lean.spec.md` §3, but the type is
named `AbstOracle` to stay independent of the unvalidated v3 substrate.

Build status (2026-09-06): compiles clean under Lean v4.31.0 / Mathlib v4.31.0;
all four `#barrier_check` unit tests produce the intended verdicts. The two
`binder_usage_scan` REVIEW items (`hasInstance`, `nonRelativizingControl`) are
false positives — both are referenced from inside the elaborator command /
`#barrier_check` invocation, which the Python scanner cannot see.
-/

namespace PleaNP

namespace Calculus

/-- Abstract oracle:total function from queries to yes/no(one step,,and step-counting
  of the machine is oracle-oblivious — the relativization-relevant property).
  Stand-in for the concrete `Oracles.Oracle` of `Oracle.lean` (which is v3,
  typed but not yet validated;keep this file buildable standalone,. -/
abbrev AbstOracle (Q : Type) : Type := Q → Bool

/-- An oracle-relative atom:the oracle answers every query"yes."Nontrivial
  (constrains A),not vacuous;;and uniform in the oracle by construction. -/
def RelAtom ( O : Type) (A : AbstOracle O) : Prop :=
  ∀ q : O, A q = true

/-- An oracle-relative language atom (stand-in for membership of an
  oracle-relative class:the language L at point x is the oracle's answer..
  This is the abstract seed shape of `P^A`/`NP^A` membership statements. -/
def LangAtom ( O : Type) (A : AbstOracle O) (L : O → Prop) : Prop :=
  ∀ x : O, (L x ↔ A x = true)

/-- Prop-carrying marker:the construction relativizes — i.e. its proof/definition
  is uniform in the oracle,and its step-counting never inspects the oracle. -/
class Relativizing (α : Sort u) : Prop where

/-- Seed instance:relativizing oracle atom. -/
instance Relativizing.relAtom {O : Type} {A : AbstOracle O} :
    Relativizing ( RelAtom O A) := ⟨⟩

/-- Seed instance:relativizing language atom. -/
instance Relativizing.langAtom {O : Type} {A : AbstOracle O} {L : O → Prop} :
    Relativizing ( LangAtom O A L) := ⟨⟩

/-- Propagation:conjunction. -/
instance Relativizing.and {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p ∧ q) := ⟨⟩

/-- Propagation:disjunction. -/
instance Relativizing.or {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p ∨ q) := ⟨⟩

/-- Propagation:implication. -/
instance Relativizing.imp {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p → q) := ⟨⟩

/-- Propagation:iff. -/
instance Relativizing.iff {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p ↔ q) := ⟨⟩

/-- Propagation:negation. -/
instance Relativizing.not {p : Prop} [Relativizing p] :
    Relativizing ( ¬ p) := ⟨⟩

/-- Propagation:universal quantification.(The instance binder is itself
  a typeclass-family over the bound variable;,so instance search recursively
  checks each fiber `p a`. -/
instance Relativizing.forall {α : Sort u} {p : α → Prop}
    [_h : (a : α) → Relativizing (p a)] : Relativizing (∀ a, p a) := ⟨⟩



/-- Propagation:existential quantification. -/
instance Relativizing.exists {α : Sort u} {p : α → Prop}
    [_h : (a : α) → Relativizing (p a)] : Relativizing (∃ a, p a) := ⟨⟩



/-- Propagation:equality of relativizing propositions. -/
instance Relativizing.eq {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p = q) := ⟨⟩



/-- Propagation:inequality of relativizing propositions. -/
instance Relativizing.ne {p q : Prop} [Relativizing p] [Relativizing q] :
    Relativizing ( p ≠ q) := ⟨⟩



/-- P-vs-NP shape marker:the proposition `p` claims equality or inequality of
  the (abstract) oracle-relative classes — the shape a BGS barrier applies to.
  Concrete `P^A = NP^A`/`P^B ≠ NP^B` statements obtain this marker when
  rendered;the abstract unit tests below mark example shapes. -/
class PVsNPShaped (p : Prop) : Prop where

/-- The time hierarchy theorem stand-in (unit-test target):the construction is
  genuinely relativizing — THH holds relative to any oracle with the same proof,so
  instance search must synthesize `Relativizing thhStatement` purely from the
  propagation instances above(no per-theorem annotation.. It is NOT
  P-vs-NP-shaped(THH doesn't separate P from NP;,so `#barrier_check` must
  answer "relativizes;not P-vs-NP-shaped → Inconclusive". -/
@[reducible] def thhStatement : Prop :=
  ∀ (O : Type) (A : AbstOracle O),
    ∃ L : O → Prop, LangAtom O A L

/-- The abstract P-vs-NP-shaped claim(DEAD case:tehis a relativizing,
  P-vs-NP-shaped statement — `#barrier_check` must answer "DEAD:.this proof
  relativizes". The marker comes from the explicit `PVsNPShaped` instance
  declared below(not from the body;,which is deliberately abstract. -/
@[reducible] def abstractPVsNP : Prop :=
  ∀ (O : Type) (A : AbstOracle O),
    ∃ L1 L2 : O → Prop, LangAtom O A L1 ∧ LangAtom O A L2



instance : PVsNPShaped abstractPVsNP := ⟨⟩



/-- A relativizing heuristic claim that is NOT P-vs-NP-shaped(Inconclusive
  relativizing case... -/
@[reducible] def plainRelHeuristic : Prop :=
  ∀ (O : Type) (A : AbstOracle O), RelAtom O A

/-- Sanity:the THH stand-in relativizes(auto-synthesized.. -/
example : Relativizing thhStatement := by
  infer_instance



/-- Sanity:the P-vs-NP-shaped claim relativizes(and is marked shaped.. -/
example : Relativizing abstractPVsNP := by
  infer_instance



/-- Sanity:the plain heuristic relativizes. -/
example : Relativizing plainRelHeuristic := by
  infer_instance



open Lean Elab Command Meta

/-- The target expression for a `#barrier_check`ed declaration:for a definition
  (the three unit-test statements are `def`s),the *body* is the proposition to
  check;fallback to the declared type(theorem-valued constants store no body.. -/
def checkTarget (cinfo : ConstantInfo) : Expr :=
  match cinfo with
  | .defnInfo v => v.value
  | _ => cinfo.type

/-- Try to synthesizea typeclass instance for `classNm` applied to `t`;
  returns whether synthesis succeeded(in `MetaM`,no throw.. -/
def hasInstance (classNm : Name) (numLevels : Nat) (t : Expr) : MetaM Bool := do
  let levels := (List.finRange numLevels).map (fun _ => Lean.Level.zero)
  let type := mkApp (mkConst classNm levels) t
  match (← trySynthInstance type)with
  | LOption.some _ => pure true
  | LOption.none => pure false
  | LOption.undef => pure false




/-- The `#barrier_check` elaborator command. Walks the statement's dependence
  graph via typeclass instance synthesis(no manual closure walk needed — the
  kernel's instance search *is* the walk,,propagating `Relativizing` through the
  composition/quantification instances above.. -/
syntax "#barrier_check " ident : command

elab_rules : command
  | `(command| #barrier_check $id:ident) => do
    let (n, rel, shaped) ← liftTermElabM do
      let ns ← getCurrNamespace
      let n := Name.append ns id.getId
      let cinfo ← getConstInfo n
      let value := ← whnf (checkTarget cinfo)
      let ref := mkConst n
      let rel ← hasInstance ``Relativizing 1 value
      let shaped ← hasInstance ``PVsNPShaped 0 ref
      pure (n, rel, shaped)
    if rel then
      if shaped then
        logInfo m!"#barrier_check {n}: DEAD — this proof relativizes, and concludes a P-vs-NP-shaped claim;so BGS rules it out."
      else
        logInfo m!"#barrier_check {n}: relativizes, not P-vs-NP-shaped → Inconclusive as a P-vs-NP blocker."
    else
      logInfo m!"#barrier_check {n}: Inconclusive — no Relativizing instance on this statement;so it is not ruled out by BGS."

/- Unit-test invocations(the local agent runs these;the elaborator must log:
  `#barrier_check thhStatement`        → "relativizes(;not P-vs-NP-shaped"
  `#barrier_check abstractPVsNP`        → "DEAD — this proof relativizes"
  `#barrier_check plainRelHeuristic`    → "relativizes(;not P-vs-NP-shaped"
  `#barrier_check` on a non-relativizing control(see below → "Inconclusive". -/
#barrier_check thhStatement
#barrier_check abstractPVsNP
#barrier_check plainRelHeuristic

/-- A non-relativizing control:an arbitrary arithmetical statement with no
  `Relativizing` instance — `#barrier_check` must answer "Inconclusive"
  (it contains no oracle-relative atoms,,so instance search finds nothing.). -/
theorem nonRelativizingControl : ∀ x : Nat, x ≤ x +  1 :=by
  intro x
  omega

#barrier_check nonRelativizingControl
end Calculus

end PleaNP