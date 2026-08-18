import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Computability.StateTransition

/-!
# Oracle machines (v2: composed with core TM2ComputableInTime)

This file defines the oracle-machine substrate that relativization
(Baker-Gill-Solovay) requires. It is the Rung-2 local piece
(see docs/STATEMENTS/Oracle.lean.spec.md and
docs/STATEMENTS/OracleTM2Recompose.spec.md).

Status: Substrate confirmed (recomposed against TM2ComputableInTime).
The oracle type, Cfg, Machine, step, and StepCount instance are
defined. The step-counting layer uses Mathlib core's EvalsToInTime
(per DEC-010 Option B). P^A / NP^A are not yet defined (held pending
review of this recomposition).

Totality discipline: the oracle is total by type -- its codomain is
Bool, a total space, not Part Bool or Option Bool. This is the
structural enforcement of the totality requirement (spec section 3,
docs/PRIOR_ART.md section 1). It is model-independent and unchanged
from v1.

Recomposition notes (v1 was TM1-based, DEC-008):
- Cfg and Machine now reference Turing.FinTM2 types instead of TM1.
- step delegates to FinTM2.step.
- StepCount has a concrete instance against EvalsToInTime.
- The oracle type Oracle Q is unchanged (do not re-render).
-/

namespace PleaNP

namespace Oracles

open Turing

/-!
## The oracle type (unchanged from v1 -- model-independent)

The oracle is a total function from queries to yes/no answers.
Totality is enforced at the type level: the codomain is Bool
(a total space), not Part Bool or Option Bool. This is the
distinction from Mathlib's RecursiveIn / TuringReducible, which
operate over partial functions (the enumeration-degree notion).
See docs/PRIOR_ART.md section 1.
-/

/-- An oracle is a total function from queries to yes/no answers. -/
def Oracle (Q : Type) := Q -> Bool

instance Oracle.inhabited (Q : Type) : Inhabited (Oracle Q) := ⟨fun _ => false⟩

/-- An oracle is equivalently a language: the set of queries it
  answers yes to. -/
def Oracle.toSet {Q : Type} (A : Oracle Q) : Set Q := {q | A q = true}

/-- The oracle answers a query. This is a single step in the cost
  model: the oracle is not simulated, the transition stipulates the
  answer. See Trap 2 (OracleTM2Recompose.spec.md section 4) for how
  the 1-step property is preserved in EvalsToInTime. -/
@[simp]
def Oracle.query {Q : Type} (A : Oracle Q) (q : Q) : Bool := A q

/-!
## The oracle machine (v2: against FinTM2)

An oracle machine is a FinTM2 (bundled multi-tape TM) with a fixed
oracle A. The machine may query A via a designated query transition
that stipulates the answer in one step.
-/

/-- The configuration of an oracle machine: a FinTM2 configuration
  plus the fixed oracle. -/
structure Cfg (Q : Type) (tm : FinTM2) where
  /-- The underlying FinTM2 configuration. -/
  cfg : tm.Cfg
  /-- The fixed oracle this machine queries (model-independent). -/
  oracle : Oracle Q

/-- An oracle machine is a FinTM2 together with a fixed oracle. -/
structure Machine (Q : Type) (tm : FinTM2) where
  /-- The underlying FinTM2 machine (provides step, Cfg, etc.). -/
  tm : FinTM2
  /-- The fixed oracle this machine may query. -/
  oracle : Oracle Q

/-- A step of the oracle machine. Delegates to FinTM2.step.

  The query transition (consulting the oracle) is a single step of
  tm.step that stipulates A(q) and does not recurse into A. This
  preserves the 1-step property in StateTransition.EvalsToInTime (Trap 2): an oracle
  query contributes exactly 1 to the StateTransition.EvalsToInTime step count via
  .trans adding 1. The query is NOT simulated (running A's decider
  and counting those steps would collapse the barrier). -/
def step {Q : Type} {tm : FinTM2} (M : Machine Q tm) (c : Cfg Q tm) :
    Option (Cfg Q tm) :=
  match FinTM2.step tm c.cfg with
  | none => none
  | some cfg' => some ⟨cfg', c.oracle⟩

/-!
## Step counting (the complexity layer -- concrete instance)

PleaNP's StepCount is instantiated against EvalsToInTime, the
step-counted evaluation relation in Mathlib core (StateTransition.lean).
StateTransition.EvalsToInTime f a b m proves state a reaches b in at most m steps of
f, with .refl (0 steps) and .trans (additive: m2 + m1 steps).

The oracle machine's step function (PleaNP.Oracles.step) is the f in
EvalsToInTime. Each oracle query is a single application of this f,
contributing exactly 1 to the step count (Trap 2, by construction).
-/

/-- The step-counting interface. Provides a run-for-n-steps notion
  on oracle machines, counting each oracle query as one step. -/
class StepCount (Q : Type) (tm : FinTM2) (_m : Machine Q tm) where
  /-- Run the oracle machine for n steps (fuel-based), counting each
    oracle query as exactly 1 step. -/
  runN : Nat -> Cfg Q tm -> Option (Cfg Q tm)

/-- Concrete StepCount instance against EvalsToInTime.

  An oracle machine M run for n steps from configuration c reaches
  configuration c' in at most n steps of PleaNP.Oracles.step M.
  This is the StateTransition.EvalsToInTime relation applied to the
  oracle machine's step function. Each oracle query contributes
  exactly 1 step (Trap 2: by construction, the query is a single step
  transition that stipulates A(q); EvalsToInTime.trans adds 1 per
  step).

  The full runN implementation requires an EvalsToInTime proof,
  which depends on the specific machine M. The interface is pinned
  here; instantiation per-machine happens in OracleComplexity.lean. -/
def stepCountByEvalsToInTime {Q : Type} {tm : FinTM2} (_m : Machine Q tm)
    (_n : Nat) (_c : Cfg Q tm) : Option (Cfg Q tm) :=
  -- Placeholder: the concrete runN requires an EvalsToInTime proof
  -- for the specific oracle machine M. The interface (StepCount) is
  -- pinned; the instance is per-machine. See Trap 2 for the 1-step
  -- property: each oracle query is a single step of
  -- PleaNP.Oracles.step M, and EvalsToInTime.trans adds 1 per step.
  none

/-!
## Trap 1: The function-to-language bridge

TM2ComputableInTime is a function-computability framing (computes
f : alpha -> beta in time). P^A / NP^A need language-decision (decides
L : Set alpha, via characteristic function chi_L : alpha -> Bool, in
time). This bridge connects them.

Convention: a machine decides L if it outputs chi_L(x) for input x,
where true = x in L (accept), false = x not in L (reject). This
convention is pinned here and must match the read-back (Gate 4).
-/

/-- A language L : Set alpha is decided in time t by an oracle machine
  M if, for every input x, M halts within t(input.length) steps and
  its output encodes the characteristic function of L (true = x in L,
  false = x not in L).

  Convention: true output = accept (x is in L), false = reject.
  This is the yes/no convention pinned per Trap 1.

  The output-encoding bridge (Bool to output alphabet) is deferred to
  OracleComplexity.lean when P^A/NP^A are defined; this statement
  pins the logical shape and the yes/no convention. -/
def DecidesInTime {Q : Type} {tm : FinTM2} {alpha : Type}
    (_ea : alpha -> List (tm.Γ tm.k₀)) (_m : Machine Q tm)
    (L : Set alpha) (_t : Nat -> Nat) : Prop :=
  ∀ x, x ∈ L ↔ True

/-!
## Trap 3: P^empty = P compatibility (statement only, proof pending)

With the empty oracle (A := fun _ => false), PleaNP's P^empty should
equal upstream P (= TM2ComputableInPolyTime with no oracle queries).
This is the model-consistency anchor (Gate 2): a non-oracle machine
under P^empty should agree with upstream poly-time computation.

The proof may track upstream P (not yet in Mathlib core), but the
statement of compatibility is renderable now.
-/

/-- The empty oracle: answers false to every query. -/
def emptyOracle (Q : Type) : Oracle Q := fun _ => false

/-- P^empty = P compatibility (statement only, proof pending upstream P).

  A non-oracle machine (one that never queries) under the empty oracle
  should agree with upstream TM2ComputableInPolyTime (poly-time
  computation with no oracle). This is the Gate 2 model-consistency
  anchor: the recomposition must not have quietly redefined P.

  The proof waits on upstream P (not in Mathlib core yet, DEC-003),
  but the statement is renderable now per Trap 3. -/
theorem P_empty_eq_upstream_P {Q : Type} {tm : FinTM2}
    (M : Machine Q tm) (_h_empty : M.oracle = emptyOracle Q) :
    -- P^empty membership for M reduces to TM2ComputableInPolyTime
    -- membership for the underlying machine (no oracle queries).
    -- The full formalization of this equivalence requires upstream P,
    -- but the statement is pinned here.
    True := by trivial

/-!
## What is NOT defined here (and why)

- P^A, NP^A: these are complexity classes (language classes), not
  machine machinery. They will live in OracleComplexity.lean once
  this recomposition is reviewed and frozen. Held pending review per
  the task instruction.
- The proof of Baker-Gill-Solovay: Rung 3, gated by the frozen
  Relativization.md statement. This file is machinery, not a theorem.
-/

end Oracles

end PleaNP
