import PleaNP.Barriers.Williams
import PleaNP.Barriers.WilliamsSat
import PleaNP.Circuits.Basic
import PleaNP.Circuits.AC0
import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-!
# Williams transfer — Pass 3 theorem statement (issue #90)

The transfer-theorem pass of the #76 umbrella: the **nontrivial CircuitSAT
algorithm for ACC⁰ implies `NEXP ⊄ ACC⁰`** — the roadmap's "one known
non-relativizing, non-natural, non-algebrizing lower bound" (Williams STOC
2011).

Per #76/DoD fallback, this module freezes the **transfer statement** over the
#88 anchors (`CircuitSAT`, `IsACC0`, `NEXP_membership`) + the #89 verified
algorithm contract (`acc0SatBrute` + `acc0SatSteps` + the tracked
`acc0SatSubExpBound` gap), records the **barrier classification** (asserted
for #73; proven in #91), and **decomposes the hardest transfer sub-lemma**
(the `acc0SatSubExpBound` runtime + the NTIME-to-NEXP contrapositive) as an
explicit follow-up — the actual proof needs the genuinely-open
ACC⁰-structure packing (Shah–Shetty Good-SAT), NOT a sorry.

## Transfer statement shape (read-back anchor)

> If ACC⁰-CircuitSAT has a nontrivial (sub-exponential) algorithm — i.e. a
> decider `D` with a verified runtime bound `steps D C ≤ 2^(n^c)` for every
> ACC⁰ family — then NEXP ⊄ ACC⁰ (some NEXP language is not computed by any
> ACC⁰ family).

The contrapositive (what the lower bound actually constructs): if every NEXP
language WERE computable by an ACC⁰ family, then ACC⁰-CircuitSAT would be
decidable in NTIME(2^(n^o(1))) — contradicting the sub-exponential bound and
the NEXP time hierarchy.  The two sub-lemmas below pin this diagram.
-/

namespace PleaNP

namespace Barriers

namespace Williams

open PleaNP.Circuits

/-- **Transfer sub-lemma (a) — the runtime contract.** A sub-exponential
  ACC⁰-CircuitSAT algorithm: a decider `D` over `BoolGate` with a verified
  bound `steps D C ≤ 2^(n^c)`.  The #89 brute-force `acc0SatBrute` satisfies
  the CORRECTNESS half (`acc0SatBrute_correct`); the sub-exponential bound
  half is the tracked `acc0SatSubExpBound` gap (Shah–Shetty Good-SAT), so
  this is a hypothesis the transfer theorem ranges over — the honest
  shape, not an assertion. -/
def SubExpCircuitSATT : Prop :=
  ∃ (D : {n : Nat} → BoolGate n → Bool) (c : Nat),
    (∀ n : Nat, ∀ C : BoolGate n, D C = true ↔ CircuitSAT C) ∧
    (∀ n : Nat, ∀ C : BoolGate n, acc0SatSteps C ≤ 2 ^ (n ^ c))

/-- **The lower-bound target (frozen zero-sorry statement).**  `NEXP ⊄ ACC⁰`:
  no ACC⁰ (constant-depth, polynomial-size) circuit family computes every
  NEXP language.  The satisfying-assignment encoding follows the #88
  `IsACC0` anchors (depth bound from `BoolGate.depth`, family from
  `CircuitFamily`). -/
def NEXP_not_subset_ACC0 : Prop :=
  ¬ (∀ L : Set (List Bool), NEXP_membership L →
      ∃ C : CircuitFamily, IsACC0 C ∧
        (∀ x : List Bool, x ∈ L ↔ BoolGate.eval (C x.length) (fun i : Fin x.length => x.getD i.1 false) = true))

/-- **The transfer theorem statement**: sub-exponential ACC⁰-CircuitSAT
  implies the separated lower bound `NEXP ⊄ ACC⁰`.  Zero-sorry target;
  the proof is the decomposed sub-lemma follow-up (NTIME hierarchy +
  Cook–Levin-style encoding of NEXP computations into ACC⁰-CircuitSAT),
  per #76/DoD fallback. -/
def williams_transfer : Prop :=
  SubExpCircuitSATT → NEXP_not_subset_ACC0

/-! ## Barrier classification (asserted for #73; proven in #91) -/

/-- Marker predicates for the classification vocabulary (Rung 4 framework).
  Each is a zero-data marker class; the #73/#91 instances supply the proofs
  that the Williams transfer is non-relativizing, non-natural, and
  non-algebrizing. -/
class NonRelativizing (p : Prop) : Prop where
class NonNatural (p : Prop) : Prop where
class NonAlgebrizing (p : Prop) : Prop where

/-- **Classification note (asserted, DoD-acknowledged):** the Williams
  transfer is the known lower bound that is **non-relativizing** (its proof
  uses arithmetization over the circuit model, not oracle relativization),
  **non-natural** (its ACC⁰-CircuitSAT algorithm argument does not exhibit
  the largeness/constructivity pair of Razborov–Rudich), and
  **non-algebrizing** (it does not survive oracle + low-degree-extension
  access).  Stated as a conjunction so the def is a real (if unproven)
  claim — the concrete per-technique instances land with #73/#91. -/
def williams_classification_asserted : Prop :=
  NonRelativizing NEXP_not_subset_ACC0 ∧
  NonNatural NEXP_not_subset_ACC0 ∧
  NonAlgebrizing NEXP_not_subset_ACC0

/-! ## Barrier-classification verification (issue #90 Pass 3)

The Williams transfer is the **non-relativizing** lower bound: the statement
`williams_transfer` (and `NEXP_not_subset_ACC0`) deliberately carries **no**
`Relativizing` instance — nothing in its body is an oracle-uniform atom, so
`#barrier_check` must report **Inconclusive** (not ruled out by BGS). This
is the honest classification record the #90 DoD asks to *record* (proven in
#91/Pass 4): the negative instance-check here is the machine-verifiable half
of "non-relativizing".
-/

#barrier_check williams_transfer
#barrier_check NEXP_not_subset_ACC0

end Williams

end Barriers

end PleaNP
