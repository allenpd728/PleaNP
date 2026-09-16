import PleaNP.Barriers.Algebrization
import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-!
# Algebrization proof-work module (AW09 2009) -- AZ3

DEC-022 paper-statement layout (mirroring `RelativizationProof.lean`):
the proof work for the Algebrization clauses lives in its own module,
physically separated from the statement root
(`lean/PleaNP/Barriers/Algebrization.lean`). The statement module does
not import this module.

## The algebrizing barrier consequence (asymmetric-access analogue)

Given an algebrizing separating pair (NP^A not-subset P^E) and an
algebrizing equalizing pair (P^B = NP^E), neither uniform direction of a
P-vs-NP resolution survives the low-degree-extension access model. Each
consequence below is provable today (zero sorries).
-/

namespace PleaNP

namespace Barriers

namespace AlgebrizationProof

open PleaNP.Oracles
open PleaNP.Barriers.Algebrization

/-! ## The algebrizing barrier consequence (zero-sorry) -/

/-- A uniform algebrizing collapse contradicts the separating (A, E)
  witness: if NP^A subset P^E held for every low-degree pair, it would
  hold for the separating pair (NP^A not-subset P^E). Asymmetric-access
  form of `RelativizationProof.uniform_collapse_...` (Gate 2/4). -/
theorem uniform_collapse_contradicted_by_separating
    (hUniform : ∀ (A : Oracle QueryType) (E : Oracle ExtQuery),
      LowDegreeExtensionOf A E → AlgBoundedNP A ⊆ AlgBoundedP E)
    (hSeparating : algebrizing_separation_statement) :
    False := by
  rcases hSeparating with ⟨A, E, hComp, hLD, hNotSubset⟩
  exact hNotSubset (hUniform A E hLD)

/-- A uniform algebrizing separation contradicts the equalizing (B, E)
  witness: if NP^A not-subset P^E held for every low-degree pair, it
  would hold for the equalizing pair, whose defining property is
  P^B = NP^E. -/
theorem uniform_separation_contradicted_by_equalizing
    (hUniform : ∀ (A : Oracle QueryType) (E : Oracle ExtQuery),
      LowDegreeExtensionOf A E → ¬ (AlgBoundedNP A ⊆ AlgBoundedP E))
    (hEqualizing : algebrizing_equalization_statement) :
    False := by
  rcases hEqualizing with ⟨B, E, hComp, hLD, hEq⟩
  have hsubset : AlgBoundedNP B ⊆ AlgBoundedP E := by
    simp [hEq]
  exact hUniform B E hLD hsubset

/-- Jointly: no algebrizing-uniform resolution of P vs NP. Given the two
  AW09 existence statements (separating + equalizing), neither uniform
  direction survives: a uniform collapse is contradicted by the separating
  pair, a uniform separation by the equalizing pair. Asymmetric-access
  counterpart of `RelativizationProof.no_uniform_resolution_of_p_vs_np`. -/
theorem no_algebrizing_uniform_resolution
    (hSeparating : algebrizing_separation_statement)
    (hEqualizing : algebrizing_equalization_statement) :
    ¬ (∀ (A : Oracle QueryType) (E : Oracle ExtQuery),
      LowDegreeExtensionOf A E → AlgBoundedNP A ⊆ AlgBoundedP E) ∧
    ¬ (∀ (A : Oracle QueryType) (E : Oracle ExtQuery),
      LowDegreeExtensionOf A E → ¬ (AlgBoundedNP A ⊆ AlgBoundedP E)) := by
  constructor
  · intro hCollapse
    rcases hSeparating with ⟨A, E, hComp, hLD, hNotSubset⟩
    exact hNotSubset (hCollapse A E hLD)
  · intro hSep
    rcases hEqualizing with ⟨B, E, hComp, hLD, hEq⟩
    have hsubset : AlgBoundedNP B ⊆ AlgBoundedP E := by
      simp [hEq]
    exact hSep B E hLD hsubset

end AlgebrizationProof
end Barriers
end PleaNP