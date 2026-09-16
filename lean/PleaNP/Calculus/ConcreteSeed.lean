import PleaNP.Calculus.BarrierCalculus
import PleaNP.Computability.OracleComplexity
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# Concrete Relativizing seeds on `P_A` / `NP_A` (Rung 5 integration, issue #82 Pass 1)

Connects the abstract Barrier Calculus (`PleaNP.Calculus.*`) to the concrete
oracle-relative class definitions in `OracleComplexity.lean`:

- `Oracles.Oracle Q` is definitionally `Q → Bool`, identical to the abstract
  `AbstOracle Q` — so the oracle totality discipline is the SAME type, and
  the class-membership statements are the concrete atoms the calculus'
  `Relativizing` marker annotates.
- `L ∈ P_A A` / `L ∈ NP_A A` are the concrete analogues of the abstract
  `LangAtom`: "L is decidable (resp. has a polytime verifier) relative to
  oracle A". As STATEMENTS about a fixed class membership, they are uniform
  in the oracle — a machine that decides L relative to A does so for any
  oracle fed through the same `decode`/query channel (the oracle only ever
  answers yes/no; step counting is oracle-oblivious per
  `OracleTM2Recompose.spec.md` §4 trap 2). So the seed instances below are
  honest: they mark the *membership atom*, exactly as the abstract
  `Relativizing.langAtom` marks `LangAtom O A L`.

- The **interesting non-relativizing case**: the *class-level equality*
  `P_A A = NP_A A` (and the BGS meta-existence `∃ A, P_A A = NP_A A`) is
  intentionally NOT seeded — "can't be relativizing" is the BGS point, and
  leaving it instance-free is what makes `#barrier_check` answer
  Inconclusive (the discipline in AGENTS.md "Barrier-calculus discipline" /
  ROADMAP Rung 5).

Concrete `#barrier_check` demonstrations:

```
  #barrier_check concreteClassEq   → DEAD (relativizing + P-vs-NP-shaped)
  #barrier_check bgsMetaStatement  → Inconclusive (no Relativizing instance)
```

Sanity examples assert synthesis directly (no per-theorem annotation).
-/

namespace PleaNP

namespace Calculus

open PleaNP.Oracles

/-- Concrete membership atom: `L` is in the oracle-relative polytime
  class `P_A A`. As a statement about a fixed membership it is uniform in
  the oracle (the machine's queries are exactly-one-step oracle answers;
  the step count never inspects A's content), so it gets the `Relativizing`
  marker — the concrete counterpart of `Relativizing.langAtom`. -/
instance Relativizing.pA_mem {Q : Type} {A : Oracle Q} {alpha : Type}
    {L : Set alpha} : Relativizing (L ∈ P_A (alpha := alpha) A) := ⟨⟩

/-- Concrete membership atom for the nondeterministic side: `L ∈ NP_A A`.
  Same uniformity-in-the-oracle rationale (the verifier's oracle queries
  are one-step answers), hence the marker. -/
instance Relativizing.npA_mem {Q : Type} {A : Oracle Q} {alpha : Type}
    {L : Set alpha} : Relativizing (L ∈ NP_A (alpha := alpha) A) := ⟨⟩

/-- A concrete P-vs-NP-SHAPED claim that synthesizes `Relativizing` from the
  two membership seeds (via the propagation instances: `and` / `or` / `forall`
  / `exists`): "some language is in P^A and in NP^A". It is marked
  `PVsNPShaped` below, so `#barrier_check` must answer DEAD — a proof of
  this claim relativizes, so BGS rules it out as a P-vs-NP resolution. -/
@[reducible] def concreteClassMembership : Prop :=
  ∀ (Q : Type) (A : Oracle Q) (alpha : Type),
    ∃ L : Set alpha, L ∈ P_A (alpha := alpha) A ∧ L ∈ NP_A (alpha := alpha) A

instance : PVsNPShaped concreteClassMembership := ⟨⟩

/-- Sanity: the seeded membership claim relativizes (auto-synthesized from
  the two seed instances + propagation). -/
example : Relativizing concreteClassMembership := by
  infer_instance

/-- The BGS meta-statement over the concrete classes: `∃ A : Oracle Q,
  P_A A = NP_A A`. Intentionally NOT seeded — a proof that constructs an
  equalizing oracle is exactly the non-relativizing direction of BGS, and
  per the discipline we do not hand-annotate it. `#barrier_check` must
  answer Inconclusive (the interesting negative case). -/
@[reducible] def bgsMetaStatement : Prop :=
  ∀ (Q : Type), ∃ A : Oracle Q, P_A (alpha := Bool) A = NP_A (alpha := Bool) A

-- Verify the intended verdicts: `concreteClassMembership` relativizes and
-- is P-vs-NP-shaped (DEAD); the BGS meta-statement carries no `Relativizing`
-- instance (Inconclusive — the interesting non-relativizing case).
#barrier_check concreteClassMembership
#barrier_check bgsMetaStatement

end Calculus

end PleaNP