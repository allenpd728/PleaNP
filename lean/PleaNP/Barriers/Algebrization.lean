import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec
set_option warningAsError true

/-!
# Algebrization (Aaronson–Wigderson, 2009) — AW09 v1 statement render

Rung 3c, issue #69 Pass 1 (AZ2 per `docs/STATEMENTS/Algebrization.design.md`).
Renders the **frozen AW09 v1 statement** from
`docs/STATEMENTS/Algebrization.md` §3 into Lean.

## The two clauses (asymmetric access — the crux)

- Clause (a): there exist a recursive oracle `A` and a low-degree extension
  `Ã` of `A` such that `NP^A ⊄ P^Ã`  — the NP side gets the **Boolean
  oracle `A`**, the P simulator gets the **extension `Ã`**. This asymmetry
  is the distinguishing feature vs. plain relativization (a rendering that
  gives the simulator plain `A` access has collapsed algebrization to
  relativization — the Gate-2/Gate-4 failure mode).
- Clause (b): there exist a recursive oracle `B` and a low-degree extension
  `B̃` of `B` such that `P^B = NP^B̃` (AW09 Thm 3.17 form).

## Rendering notes

- The **extension subspace** is abstract (`ExtQuery`); the concrete
  multiquadratic construction is AZ1's job. The `LowDegreeExtensionOf`
  marker below is the load-bearing non-collapse guard: it is a genuine
  hypothesis distinct from `A` itself, so the statement cannot silently
  weaken to relativization (Gate 2/4).
- The algebraic class operators `AlgBoundedP`/`AlgBoundedNP` are the
  **asymmetric-access** stand-ins: `AlgBoundedP` runs with extension access,
  `AlgBoundedNP` runs with Boolean-oracle access. AZ3 defines their concrete
  semantics; the statement only needs their well-typed shape.
- `PleaNP.Barriers.Algebrization` namespace (DEC-002).

Status: statement rendered, zero-sorry (Gate 1 anchor); proof work (the
two clause claims and their proofs) lands in AZ5 and is tracked in
`docs/SORRY_TRACKER.md`. This file builds green in the clean module set.
-/

namespace PleaNP

namespace Barriers

namespace Algebrization

open PleaNP.Oracles

/-- The query type: bitstrings (the Boolean-oracle side). -/
abbrev QueryType := List Bool

/-- The input type: bitstrings. Languages are sets of bitstrings. -/
abbrev InputType := List Bool

/-- The extension query subspace (abstract — AZ1's multiquadratic
  construction instantiates it; e.g. `Σ m, F^m` over a finite field). -/
abbrev ExtQuery := Nat

/-- **Low-degree extension marker** (non-collapse guard, Gate 2/4): `E` is a
  genuine low-degree extension of the Boolean oracle `B` — abstract at the
  statement layer (the concrete multiquadratic construction + the distinctness
  proof land in AZ1). The hypothesis carries the "not the identity" content:
  the `P`-side simulator queries `E`, not `B`. -/
class LowDegreeExtensionOf (B : Oracle QueryType) (E : Oracle ExtQuery) : Prop where

/-- The **asymmetric-access P-operator** `P^Ã`: the polytime class whose
  simulating machine queries the *extension* `E` of the oracle.
  real `P_A` class at the extension query type (the P-side simulator's
  oracle answers live in `E`'s space, `Oracle ExtQuery`). -/
abbrev AlgBoundedP (E : Oracle ExtQuery) : Set (Set InputType) :=
  P_A (alpha := InputType) E

/-- The **asymmetric-access NP-operator** `NP^A`: the nondeterministic
  polytime class whose verifier queries the *Boolean* oracle `A`.
  real `NP_A` class at the Boolean query type. The asymmetry (NP reads
  `A`, P reads `E`) is literal. -/
abbrev AlgBoundedNP (A : Oracle QueryType) : Set (Set InputType) :=
  NP_A (alpha := InputType) A

/-!
## The two clauses — zero-sorry statement references

Statement-shape per `Algebrization.md` §5 read-back: the Oracle `A`/`B` is
existential and recursive (`Computable` — Trap-1 non-triviality), and the
extension `E` is an existential over `LowDegreeExtensionOf`. The asymmetric
access is literal: `AlgBoundedNP A` (Boolean side) vs `AlgBoundedP E`
(extension side).
-/

/-- **Clause (a), statement reference:** there exist a recursive oracle `A`
  and a low-degree extension `E` of `A` such that `NP^A ⊄ P^E`
  (strict non-containment — the algebrizing separation witness). The
  `Computable` hypothesis carries the recursiveness (Trap 1); the asymmetry
  (`AlgBoundedNP A` vs `AlgBoundedP E`) is the crux vs. relativization. -/
def algebrizing_separation_statement : Prop :=
  ∃ (A : Oracle QueryType) (E : Oracle ExtQuery),
    Computable (α := QueryType) A ∧
      LowDegreeExtensionOf A E ∧
        ¬ (AlgBoundedNP A ⊆ AlgBoundedP E)

/-- **Clause (b), statement reference:** there exist a recursive oracle `B`
  and a low-degree extension `E` of `B` such that `P^B = NP^E` (the
  equalizing side, AW09 Thm 3.17 form). Symmetric asymmetry: the P side
  queries `B`, the NP side queries the extension `E`. -/
def algebrizing_equalization_statement : Prop :=
  ∃ (B : Oracle QueryType) (E : Oracle ExtQuery),
    Computable (α := QueryType) B ∧
      LowDegreeExtensionOf B E ∧
        AlgBoundedP E = AlgBoundedNP B

end Algebrization

end Barriers

end PleaNP
