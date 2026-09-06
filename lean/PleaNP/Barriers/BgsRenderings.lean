import Mathlib
import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-
# BGS multi-rendering module (Gate 3 rendering campaign)

Three INDEPENDENT Lean renderings of the Baker-Gill-Solovay clauses
(equalizing oracle, clause (a), and separating oracle, clause (b)).

These are RENDERINGS of the statements (defs with Prop bodies), NOT proofs.
They exist so the Gate-3 multi-rendering loop (`tooling/gates/multi_render.py`)
can run machine-verified pairwise equivalence checks across genuinely
different structural formulations of the same informal claim:

  Rewriter A — direct, style of Relativization.lean (nested ∃ + ∧).
  Rewriter B — flattened conjunctive style (∃ A, P=NP ∧ Computable A).
  Rewriter C — pointwise/parametric style (∀-indexed claim instance).

The three differ in binder structure and class-reference surface. If a
pairwise check proves them IFF-equivalent, the statement's shape is robust;
DISAGREE flags a shape ambiguity for human mining. See docs/GRANT_READINESS.md
and docs/STATEMENTS/SEMANTIC_APPROVAL.md (the multi-rendering model).
-/

namespace PleaNP

namespace Barriers

namespace BgsRenderings

open PleaNP.Oracles

/-- The query type: bitstrings (same as Relativization.lean; kept local so
  this rendering module builds without the sorry'd Relativization file). -/
abbrev QueryType := List Bool

/-- The input type: bitstrings. Languages are sets of bitstrings. -/
abbrev InputType := List Bool

/-- Rendering A (rewrite of clause (a)) — nested-existential style: there is
  an oracle A that is computable and collapses the classes. -/
def equalizing_A : Prop :=
  ∃ (A : Oracle QueryType),
    Computable (α := QueryType) A ∧
    P_A (alpha := InputType) A = NP_A (alpha := InputType) A

/-- Rendering B (rewrite of clause (b)) — flat-conjunctive style: there is an
  oracle B that is computable AND keeps the classes apart. -/
def separating_B : Prop :=
  ∃ (B : Oracle QueryType),
    Computable (α := QueryType) B ∧
    P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B

/-- Rendering C (rewrite of clause (a), pointwise style): there is an oracle
  A with membership-equality of the classes at every language. -/
def equalizing_C : Prop :=
  ∃ (A : Oracle QueryType),
    Computable (α := QueryType) A ∧
    (∀ (L : Set InputType), (L ∈ P_A (alpha := InputType) A) ↔ (L ∈ NP_A (alpha := InputType) A))

/-- Rendering D (rewrite of clause (b), pointwise style): there is an oracle
  B with a language that separates the classes. -/
def separating_D : Prop :=
  ∃ (B : Oracle QueryType),
    Computable (α := QueryType) B ∧
    (∃ (L : Set InputType), (L ∈ P_A (alpha := InputType) B) ∧ ¬ (L ∈ NP_A (alpha := InputType) B))

/-- Within-clause equivalence A ↔ C: class equality is extensional set
  equality (pointwise membership). This is the Gate-7 proof that lets the
  multi-rendering matrix record A~C as EQUIVALENT rather than BLOCKED. -/
theorem equalizing_A_iff_C :
    equalizing_A ↔ equalizing_C := by
  unfold equalizing_A equalizing_C
  constructor
  · intro h
    rcases h with ⟨A, hA, hEq⟩
    refine ⟨A, hA, ?_⟩
    intro L
    -- hEq : P_A A = NP_A A ; pointwise membership via simpa [hEq]
    constructor
    · intro hL; simpa [hEq] using hL
    · intro hL; simpa [hEq] using hL
  · intro h
    rcases h with ⟨A, hA, hExt⟩
    refine ⟨A, hA, ?_⟩
    -- extensional: ∀ L, L∈P ↔ L∈N  ==>  P = N, via Set.ext
    apply Set.ext
    intro L
    exact hExt L

/-- Within-clause equivalence B ↔ D (reverse direction is easy; forward
  needs a classical witness). We prove the reverse direction `separating_D →
  separating_B` (a separating language refutes set equality) — the honest
  machine-verifiable part. The forward direction (set inequality → a
  separating witness exists) is classical and left as open Gate-7 work; the
  multi-rendering matrix therefore records B~D as "needs proof" (BLOCKED),
  which is the honest state. -/
theorem separating_D_to_B :
    separating_D → separating_B := by
  unfold separating_D separating_B
  intro h
  rcases h with ⟨B, hB, ⟨L, hLp, hLn⟩⟩
  refine ⟨B, hB, ?_⟩
  intro hEq
  -- hEq : P_A B = NP_A B ; then L∈P -> L∈N, contradicting hLn
  exact hLn (by simpa [hEq] using hLp)

end BgsRenderings

end Barriers

end PleaNP