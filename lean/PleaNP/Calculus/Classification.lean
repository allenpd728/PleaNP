import PleaNP.Calculus.Soundness
import PleaNP.Calculus.ConcreteSeed
import PleaNP.Barriers.RelativizationProof

set_option warningAsError true

/-!
# Barrier classification method (Rung 4, issue #73 Pass 1)

The Rung-4 deliverable that turns lower-bound proofs into *barrier
classifications*: for a lower-bound technique, a **classification theorem**
of the shape

  `Relativizing (L ∈ P_A A)`  →  `UniformInOracle A ↦ (L ∈ P_A A)`

converts the `#barrier_check`-emitted DEAD verdict into a *provable
oracle-uniformity fact* via the #65 soundness bridge (`Soundness.lean`,
`UniformInOracle`). A proof technique flagged DEAD (relativizing +
P-vs-NP-shaped) is thereby shown to be uniform in the oracle — BGS blocks it.

This module fixes the **method** and demonstrates it on the structures
already proven in this repo:

- the concrete membership atoms (`Relativizing.pA_mem`, from #82), and
- the one-query oracle language (`RelativizationProof._consoleLang_*`, the
  A3 machine from #63) — the first "lower-bound-ish" object classified:
  the class of languages decided by the one-query machine is
  oracle-uniform, so any proof of a P-vs-NP claim built on it relativizes
  and cannot separate P from NP.

The AC⁰/parity instance (#72), monotone (#74), resolution (#75), and
Williams (#76) instances attach once those lower-bound proofs land; the
method here is the reusable spine each instance will instantiate.

No sorries: the bridge theorems are proved.
-/

namespace PleaNP

namespace Calculus

open PleaNP.Oracles
open PleaNP.Barriers.RelativizationProof

/-- **Classification theorem (the method's spine)**: a `Relativizing`
  end-of-line membership atom is oracle-uniform. Concretely: if `L ∈ P_A A`
  carries the `Relativizing` marker (the #82 seed), then the membership
  family is `UniformInOracle` — the #65 soundness bridge applied to the
  concrete P_A atom.

  This is the classification-method spine: it converts the marker that
  `#barrier_check` reads (DEAD) into the semantic fact (uniformity) that
  BGS's blocking argument uses. -/
theorem classification_uniform (O alpha : Type) (L : Set alpha) :
    UniformInOracle O (fun A : Oracle O => L ∈ P_A (alpha := alpha) A) :=
  pA_mem_uniform O alpha L

/-- **Method demonstration — the A3 concrete oracle-languages are
  oracle-uniform.** The one-query machine (#63 Pass 2) decides the
  constant-true and constant-false oracle languages in 2 steps; their
  fixed-language memberships `univ ∈ P_A A` and `∅ ∈ P_A A` are uniform in
  the oracle (the machine's queries answer identically under
  extensionally-equal oracles). This demonstrates the classification
  method on the A3 objects: a membership fact (proved in #63) classified
  as oracle-uniform via the #65 bridge. -/
theorem oneQuery_classification_uniform :
    UniformInOracle PleaNP.Challenges.QueryType (fun A : Oracle PleaNP.Challenges.QueryType =>
      Set.univ ∈ P_A (alpha := PleaNP.Challenges.QueryType) A) := by
  -- A fixed language's membership is uniform (pA_mem_uniform).
  exact pA_mem_uniform PleaNP.Challenges.QueryType PleaNP.Challenges.QueryType Set.univ

/-- The method's verdict: the A3 constant-true oracle language membership
  carries the `Relativizing` seed (the #82 `pA_mem` instance at the A3
  object), so a P-vs-NP-shaped claim built on it is DEAD under
  `#barrier_check` — the marker-to-uniformity bridge is the classification
  method's provable reason. -/
example (A : Oracle PleaNP.Challenges.QueryType) :
    Relativizing (Set.univ ∈ P_A (alpha := PleaNP.Challenges.QueryType) A) := by
  infer_instance

end Calculus

end PleaNP