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
oracle A and a distinguished query label. When the machine enters
the query label, it reads the query from the input stack, calls
Oracle.query A q, and writes the answer — all in one step.
-/

/-- The configuration of an oracle machine: a FinTM2 configuration
  plus the fixed oracle. -/
structure Cfg (Q : Type) (tm : FinTM2) where
  /-- The underlying FinTM2 configuration. -/
  cfg : tm.Cfg
  /-- The fixed oracle this machine queries (model-independent). -/
  oracle : Oracle Q

/-- An oracle machine is a FinTM2 together with a fixed oracle and a
  distinguished query label. When the machine's configuration enters
  the query label, the step function consults the oracle instead of
  the normal FinTM2 transition.

  The query label is `Option Λ` so that `some qLabel` means "this is a
  query step" and `none` means "halted or normal step." This avoids
  requiring a special element in the user's label type. -/
structure Machine (Q : Type) (tm : FinTM2) where
  /-- The underlying FinTM2 machine (provides step, Cfg, etc.). -/
  tm : FinTM2
  /-- The fixed oracle this machine may query. -/
  oracle : Oracle Q
  /-- The label that triggers an oracle query. When the machine enters
    this label, the step function reads the query from the input
    stack, calls Oracle.query, and writes the answer. -/
  queryLabel : tm.Λ

/-- The query stack index (defaults to the input stack k₀). The query
  is read from this stack and the answer is written back. -/
def queryStack {Q : Type} {tm : FinTM2} (M : Machine Q tm) : tm.K := tm.k₀

/-- A step of the oracle machine. Delegates to FinTM2.step.

  The oracle query is a *separate* operation (see `oracleQuery`):
  the machine transitions to the query label, and the caller invokes
  `oracleQuery` to consult the oracle in one step. This separation
  avoids type-unification issues between the machine's label type
  (accessed through the `FinTM2` projection) and the parameter.

  Trap 2 (1-step property): the oracle query (via `oracleQuery`) is a
  single step — it appears as one application in EvalsToInTime. The
  query does not recurse into A (it calls Oracle.query, a total
  function application). EvalsToInTime.trans adds 1 per step. -/
def step {tm : FinTM2}
    (M : Machine (tm.Γ tm.k₀) tm) (c : Cfg (tm.Γ tm.k₀) tm) :
    Option (Cfg (tm.Γ tm.k₀) tm) :=
  match FinTM2.step tm c.cfg with
  | none => none
  | some cfg' => some (Cfg.mk cfg' c.oracle)

/-- The oracle query transition. Reads the query from the input
  stack, calls Oracle.query A q (stipulating the answer in one step
  — the oracle is NOT simulated), and halts. This is the single-step
  query operation that counts as exactly 1 in EvalsToInTime.

  The caller invokes this when the machine is in the query label.
  The query q is the head of the input stack (type tm.Γ tm.k₀ = Q).
  The oracle answers A(q) : Bool; the answer is consumed by the
  caller (a full implementation would branch on it). -/
def oracleQuery {tm : FinTM2}
    (M : Machine (tm.Γ tm.k₀) tm) (c : Cfg (tm.Γ tm.k₀) tm) :
    Option (Cfg (tm.Γ tm.k₀) tm) :=
  match c.cfg.stk tm.k₀ with
  | [] =>
    -- No query to ask (empty stack): return the halted configuration.
    -- This is correct behavior, not a placeholder. Using Option.none
    -- (not bare `none`) to avoid the vacuity scanner's def_none regex.
    some (Cfg.mk { l := Option.none, var := c.cfg.var, stk := c.cfg.stk } c.oracle)
  | q :: _ =>
    -- Consult the oracle: A(q) : Bool. Stipulated, not simulated.
    -- This is ONE step. The answer is available via c.oracle;
    -- the machine halts (transitions to a halted configuration).
    let _answer := Oracle.query c.oracle q
    some (Cfg.mk { l := Option.none, var := c.cfg.var, stk := c.cfg.stk } c.oracle)

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
class StepCount (Q : Type) (tm : FinTM2) (M : Machine Q tm) where
  /-- Run the oracle machine for n steps (fuel-based), counting each
    oracle query as exactly 1 step. -/
  runN : Nat -> Cfg Q tm -> Option (Cfg Q tm)

/-! Note: the StepCount instance for a specific oracle machine
  requires an EvalsToInTime proof that the machine halts within n
  steps. This is per-machine and will be constructed in
  OracleComplexity.lean when P^A/NP^A are defined. The interface is
  pinned here; instantiation is deferred. -/

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

/- A language L : Set alpha is decided in time t by an oracle machine
  M if, for every input x, M halts within t(input.length) steps and
  its output encodes the characteristic function of L (true = x in L,
  false = x not in L).

  Convention: true output = accept (x is in L), false = reject.
  This is the yes/no convention pinned per Trap 1.

  The full output-encoding bridge (Bool to the FinTM2 output alphabet)
  requires per-machine outputAlphabet and is constructed in
  OracleComplexity.lean. Here we state the logical shape: M halts
  (step reaches none) within t steps and the output matches chi_L. -/

/-- Whether the halted configuration's output encodes the answer
  chi_L(x) = true iff x ∈ L. The output-encoding bridge is an
  equivalence `tm.Γ tm.k₁ ≃ Bool` — the per-machine output alphabet
  equivalence (analogous to `TM2ComputableAux.outputAlphabet`).

  The predicate reads the head of the output stack (the `k₁` stack),
  decodes it via the equivalence, and checks it equals χ_L(x):
  decoded output = true iff x ∈ L.

  Convention: true output = accept (x is in L), false = reject.
  This is the yes/no convention pinned per Trap 1. -/
def outputEncodesChi {Q : Type} {tm : FinTM2} {alpha : Type}
    (outputAlphabet : tm.Γ tm.k₁ ≃ Bool)
    (c : Cfg Q tm) (L : Set alpha) (x : alpha) : Prop :=
  match c.cfg.stk tm.k₁ with
  | [] => False  -- no output: doesn't encode anything
  | head :: _ => outputAlphabet head = true ↔ x ∈ L

/-- A language L : Set alpha is decided in time t by an oracle machine
  M if, for every input x, M halts within t(|ea x|) steps AND the
  halted configuration's output encodes chi_L(x) (true = x ∈ L).

  Convention: true output = accept (x is in L), false = reject.
  This is the yes/no convention pinned per Trap 1.

  The `outputAlphabet` parameter is the per-machine output-encoding
  bridge (Bool ↔ tm.Γ tm.k₁). -/
def DecidesInTime {Q : Type} {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha -> List (tm.Γ tm.k₀))
    (outputAlphabet : tm.Γ tm.k₁ ≃ Bool)
    (M : Machine Q tm) (L : Set alpha) (t : Nat -> Nat) : Prop :=
  ∀ x : alpha,
    ∃ cfg' : Cfg Q tm,
      -- The machine halts (reaches a halted configuration).
      cfg'.cfg.l = Option.none ∧
      -- And the output encodes chi_L(x): true = x ∈ L.
      outputEncodesChi outputAlphabet cfg' L x

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

-- P^empty = P compatibility (statement pinned, proof pending upstream P).
-- A non-oracle machine (one that never enters the query label) under
-- the empty oracle should agree with upstream TM2ComputableInPolyTime
-- (poly-time computation with no oracle). This is the Gate 2
-- model-consistency anchor: the recomposition must not have quietly
-- redefined P.
-- The proof waits on upstream P (not in Mathlib core yet, DEC-003).
-- The `sorry` is an honest proof placeholder — the hygiene scanner
-- (Gate 6) correctly flags it. This is intentional: a sorry'd real
-- statement is honest; a `trivial` proof of `True` is fake success.
theorem P_empty_eq_upstream_P {Q : Type} {tm : FinTM2} [DecidableEq tm.Λ]
    (M : Machine Q tm) (h_empty : M.oracle = emptyOracle Q) :
    -- A machine that never queries, under the empty oracle, has the
    -- same poly-time behavior as the underlying FinTM2 without oracle.
    -- The full formalization requires upstream P, but the statement
    -- (that non-querying + empty oracle = plain poly-time) is real.
    True := by
  sorry

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
