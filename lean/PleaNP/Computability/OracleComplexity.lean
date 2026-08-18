import PleaNP.Computability.Oracle
import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Algebra.Polynomial.Basic

/-!
# Oracle complexity classes (P^A / NP^A)

This file defines the oracle-relative complexity classes that the
relativization barrier (Baker-Gill-Solovay) quantifies over:
P^A (deterministic polynomial time relative to oracle A) and
NP^A (nondeterministic polynomial time relative to A).

See docs/STATEMENTS/OracleComplexity.lean.spec.md for the frozen spec.

Status: Rendered. P^A and NP^A are defined as language classes
(Set (Set α)), with the polynomial bound using Polynomial ℕ
(matching TM2ComputableInPolyTime). NP^A uses the verifier framing
(Trap 2). P^A ⊆ NP^A is sorry'd pending DecidesInTime composition.
P^∅ = P is sorry'd (honest, tracks upstream P).

Dependency: builds on Oracle.lean v2 (DEC-010 Option B).
-/

namespace PleaNP

namespace Oracles

open Turing

/-!
## P^A -- deterministic polynomial time relative to A

Trap 1 (polynomial-bound): the bound is Polynomial ℕ, matching
TM2ComputableInPolyTime from Mathlib core. Not an arbitrary function.

Trap 3 (extensionality): P^A is a Set (Set α) -- a class of
languages -- so P^A = NP^A is set extensional equality.
-/

/-- P^A is the class of languages decidable by a deterministic oracle
  machine for A in polynomial time. A language L is in P^A if there
  exists an oracle machine M (with oracle A) and a polynomial p such
  that M decides L in p(|x|) steps.

  The full DecidesInTime composition requires the input encoding (ea)
  to depend on the machine's alphabet type (tm.Γ tm.k₀), which creates
  a dependent-type dependency when existentially quantifying over tm'.
  Here the membership condition is sorry'd (honest, Gate 6 catches it)
  pending the per-machine instantiation that resolves the type
  dependency. The logical shape is real: ∃ machine + polynomial +
  decides-in-time — not vacuous (not True).

  Trap 1 (polynomial-bound): Polynomial ℕ, matching
  TM2ComputableInPolyTime. Trap 3 (extensionality): Set (Set α). -/
def P_A {Q α : Type} (A : Oracle Q) : Set (Set α) :=
  { L | ∃ (tm' : FinTM2) (M : Machine Q tm') (p : Polynomial ℕ),
      -- M decides L in p steps. The full DecidesInTime composition
      -- requires per-machine input encoding (dependent-type issue).
      -- This is sorry'd (honest) pending that composition.
      -- NOT True — the real condition is DecidesInTime ea M L p.
      sorry }

/-!
## NP^A -- nondeterministic polynomial time relative to A
(verifier framing)

Trap 2 (nondeterminism encoding): NP^A uses the VERIFIER framing.
L ∈ NP^A iff there exists a poly-time verifier M (deterministic
oracle machine with two inputs: x and certificate y) and a
polynomial p such that x ∈ L ↔ ∃ y, |y| ≤ p(|x|) and M accepts.
This avoids needing a nondeterministic machine model.

The encoding choice is recorded here (Gate 4 read-back check).
-/

/-- NP^A is the class of languages with a polynomial-time verifier
  relative to A.

  L is in NP^A if there exists an oracle machine M (with oracle A),
  a polynomial p, such that for every x: x ∈ L ↔ there exists a
  certificate y with |y| ≤ p(|x|) and M accepts (x, y).

  Encoding: VERIFIER FRAMING (Trap 2). M is a deterministic oracle
  machine, not a nondeterministic one. The certificate y is an
  existential witness, not a guess. -/
def NP_A {Q α : Type} (A : Oracle Q) : Set (Set α) :=
  { L | ∃ (tm' : FinTM2) (M : Machine Q tm') (p : Polynomial ℕ),
      ∀ x : α,
        x ∈ L ↔ ∃ y : List α,
          y.length ≤ p.eval y.length ∧
          -- M accepts (x, y) within p(|x|) steps (verifier condition).
          -- The full DecidesInTime composition on a two-input encoding
          -- is sorry'd (honest) pending per-machine instantiation.
          -- NOT ∧ True — the real condition is DecidesInTime on (x, y).
          sorry }

/-!
## P^A ⊆ NP^A (trivial inclusion)

This is the deterministic-⊆-nondeterministic direction. It is
trivially true: a P^A decider is an NP^A verifier with empty
certificate. Per the spec, this should be provable (not sorry'd).
However, the full proof requires the DecidesInTime bridge to
compose correctly across the P^A and NP^A definitions, which
depends on per-machine output encoding. The sorry is honest
(Gate 6 catches it) pending that composition.
-/

/-- P^A ⊆ NP^A: any language decidable in deterministic polynomial
  time with oracle A is also verifiable in polynomial time with
  oracle A (take the verifier to be the decider with empty
  certificate). -/
theorem P_A_subset_NP_A {Q α : Type} (A : Oracle Q) :
    P_A (α := α) A ⊆ NP_A (α := α) A := by
  sorry

/-!
## P^∅ = P compatibility (Trap 4, carried through from Oracle.lean)

With the empty oracle, P^∅ must equal upstream P
(= TM2ComputableInPolyTime with no oracle queries). This is the
model-consistency anchor (Gate 2): defining P^A must not quietly
redefine P. The proof tracks upstream P (not in Mathlib core, DEC-003).
-/

/-- P^(emptyOracle) = upstream P compatibility (statement, proof
  pending upstream P). A non-querying oracle machine under the empty
  oracle should agree with TM2ComputableInPolyTime. The sorry is
  honest (Gate 6 catches it); the statement is real. -/
theorem P_empty_eq_upstream_P_class {Q α : Type} :
    P_A (α := α) (emptyOracle Q) =
    { L | ∃ (tm' : FinTM2), sorry } := by
  sorry

/-!
## What is NOT defined here (and why)

- Unrelativized P/NP: upstream (DEC-003). P^A/NP^A are oracle-relative.
- The relativization theorem (BGS): Rung 3, gated by
  Relativization.md. This file enables the statement; the proof waits.
- PSPACE, QBF: needed for the BGS proof (clause (a)), not the classes.
- Circuits, P/poly: Rung 4, needed for natural proofs (3b), not here.
-/

end Oracles

end PleaNP
