import PleaNP.Challenges.Relativization
import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec

set_option warningAsError true

/-!
# Relativization proof-work module (BGS 1975, clause (a)+(b))

DEC-022 §3.3 paper-statement layout (issue #66): the *proof work* for the
BGS clauses lives in its own module, physically separated from the
statement/claim root (`lean/PleaNP/Barriers/Relativization.lean` — which
holds the two `theorem` claims and their honest, tracked `sorry`
placeholders until #18/#63 close them). The statement root **does not
import** this module; this module imports only the clean substrates
(`PleaNP.Challenges.Relativization` for the zero-sorry statement
references + `PleaNP.Computability.OracleComplexity` for `P_A`/`NP_A`).

## What lives here

- The **BGS barrier consequence** (the derived corollary of `Relativization.md`
  §3): the reason relativistic proof techniques cannot resolve P vs NP.
  Rendered in its purest oracle-uniform form — if a *collapse* claim holds
  for every oracle then it is contradicted by the separating oracle; if a
  *separation* claim holds for every oracle then it is contradicted by the
  equalizing oracle. Each is provable right now (zero sorries).
- Onward proof-work lemmas (A1–A5 for clause (a), D1–D6 for clause (b)) land
  here as they are proved; the statement root is never edited by proof
  search (Gate-1 freeze discipline).

## The barrier-consequence shape

Baker–Gill–Solovay 1975 exhibited:

  (a) an equalizing oracle A with P^A = NP^A, and
  (b) a separating oracle B with P^B ≠ NP^B.

A *relativizing* proof technique must be uniform in the oracle: any
conclusion it reaches for one oracle it reaches for every oracle. Hence:

  · a relativizing proof of P = NP ⇒ P^B = NP^B, contradicting (b);
  · a relativizing proof of P ≠ NP ⇒ P^A ≠ NP^A, contradicting (a).

So the two existence clauses are jointly **incompatible** with an
oracle-uniform resolution of P vs NP. That joint incompatibility is what
`#barrier_check`'s "DEAD" verdict reports.
-/

namespace PleaNP

namespace Barriers

namespace RelativizationProof

open PleaNP.Oracles
open PleaNP.Challenges

/-! ## The barrier consequence (zero-sorry, provable today) -/

/-- **A uniform collapse contradicts the separating oracle.** If P^A = NP^A
  held for *every* oracle (the conclusion of any relativizing proof of
  P = NP), then it would hold in particular for the separating oracle B —
  whose defining property is P^B ≠ NP^B. Contradiction.

  This is the purest form of the clause-(b) barrier: no proof technique
  uniform in the oracle can establish the collapse. -/
theorem uniform_collapse_contradicted_by_separating
    (hCollapse : ∀ B : Oracle QueryType,
      P_A (alpha := InputType) B = NP_A (alpha := InputType) B)
    (hSeparating : ∃ B : Oracle QueryType,
      P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B) :
    False := by
  rcases hSeparating with ⟨B, hB⟩
  exact hB (hCollapse B)

/-- **A uniform separation contradicts the equalizing oracle.** If P^A ≠ NP^A
  held for *every* oracle (the conclusion of any relativizing proof of
  P ≠ NP), then it would hold in particular for the equalizing oracle A —
  whose defining property is P^A = NP^A. Contradiction.

  Mirror form of the clause-(a) barrier. -/
theorem uniform_separation_contradicted_by_equalizing
    (hSep : ∀ A : Oracle QueryType,
      P_A (alpha := InputType) A ≠ NP_A (alpha := InputType) A)
    (hEqualizing : ∃ A : Oracle QueryType,
      P_A (alpha := InputType) A = NP_A (alpha := InputType) A) :
    False := by
  rcases hEqualizing with ⟨A, hA⟩
  exact (hSep A) hA

/-- **Jointly: no oracle-uniform resolution of P vs NP.** Given the two BGS
  existence facts — an equalizing oracle (P^A = NP^A for some A) and a
  separating oracle (P^B ≠ NP^B for some B) — neither uniform direction of a
  P-vs-NP resolution can hold: a uniform collapse would force P^B = NP^B on
  the separating oracle, and a uniform separation would force P^A ≠ NP^A on
  the equalizing oracle. This is the single "relativization blocks both
  directions" statement of the barrier consequence. -/
theorem no_uniform_resolution_of_p_vs_np
    (hEqualizing : ∃ A : Oracle QueryType,
      P_A (alpha := InputType) A = NP_A (alpha := InputType) A)
    (hSeparating : ∃ B : Oracle QueryType,
      P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B) :
    ¬ (∀ B : Oracle QueryType, P_A (alpha := InputType) B = NP_A (alpha := InputType) B) ∧
    ¬ (∀ A : Oracle QueryType, P_A (alpha := InputType) A ≠ NP_A (alpha := InputType) A) := by
  constructor
  · intro hCollapse
    rcases hSeparating with ⟨B, hB⟩
    exact hB (hCollapse B)
  · intro hSep
    rcases hEqualizing with ⟨A, hA⟩
    exact (hSep A) hA

end RelativizationProof

end Barriers

end PleaNP
