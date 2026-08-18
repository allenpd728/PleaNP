import Mathlib.Computability.TuringMachine.PostTuringMachine
set_option warningAsError true

/-!
# Oracle machines

This file defines the oracle-machine substrate that relativization
(Baker-Gill-Solovay) requires. It is the unblocked Rung-2 local piece
(see docs/STATEMENTS/Oracle.lean.spec.md).

Status: Partial prototype. The oracle type and oracle machine
(oracle tape + query transition) are defined here. The step-counting
layer is blocked on upstream step counting (Mathlib #35366 runN or
#33132 EvalsToInTime), which core Turing.TM1 lacks (see
docs/GAP_AUDIT.md section 1). The StepCount abstraction below
isolates this dependency so that when upstream step counting lands,
only the counting glue changes -- not the oracle type.

Totality discipline: the oracle is total by type -- its codomain is
Bool, a total space, not Part Bool or Option Bool. This is the
structural enforcement of the totality requirement (spec section 3,
docs/PRIOR_ART.md section 1). It must not be weakened.
-/

namespace PleaNP

namespace Oracles

/-- An oracle is a total function from queries to yes/no answers.
  Totality is enforced at the type level: the codomain is Bool
  (a total space), not Part Bool or Option Bool. -/
def Oracle (Q : Type) := Q -> Bool

instance Oracle.inhabited (Q : Type) : Inhabited (Oracle Q) := ⟨fun _ => false⟩

/-- An oracle is equivalently a language: the set of queries it
  answers yes to. -/
def Oracle.toSet (Q : Type) (A : Oracle Q) : Set Q := {q | A q = true}

/-- The oracle answers a query. This is a single step in the cost
  model: the oracle is not simulated, the transition stipulates the
  answer. -/
@[simp]
def Oracle.query (Q : Type) (A : Oracle Q) (q : Q) : Bool := A q

/-- The configuration of an oracle machine: a TM1 configuration plus
  an oracle tape. -/
structure Cfg (Q Gamma Lambda Sigma : Type) [Inhabited Q] [Inhabited Gamma] where
  tm : Turing.TM1.Cfg Gamma Lambda Sigma
  oracleTape : Turing.Tape Q

/-- An oracle machine is a TM1 machine together with a fixed oracle. -/
structure Machine (Q Gamma Lambda Sigma : Type) [Inhabited Q] [Inhabited Gamma]
    [Inhabited Lambda] where
  tm : Lambda -> Turing.TM1.Stmt Gamma Lambda Sigma
  oracle : Oracle Q

/-- A step of the oracle machine. For non-query steps, this delegates
  to TM1 step. The query transition is a separate operation the
  machine triggers explicitly. -/
def step {Q Gamma Lambda Sigma : Type} [Inhabited Q] [Inhabited Gamma]
    [Inhabited Lambda] (M : Machine Q Gamma Lambda Sigma)
    (c : Cfg Q Gamma Lambda Sigma) : Option (Cfg Q Gamma Lambda Sigma) :=
  match c.tm.l with
  | none => none
  | some _ => match Turing.TM1.step M.tm c.tm with
    | none => none
    | some tm' => some ⟨tm', c.oracleTape⟩

/-- The step-counting interface. This is the abstraction the complexity
  classes (P^A, NP^A) will be built on. The concrete implementation
  waits on upstream runN-style counting (#35366 or #33132). -/
class StepCount (Q : Type) [Inhabited Q] (Gamma Lambda Sigma : Type)
    [Inhabited Gamma] [Inhabited Lambda] (M : Machine Q Gamma Lambda Sigma) where
  runN : Nat -> Cfg Q Gamma Lambda Sigma -> Option (Cfg Q Gamma Lambda Sigma)

end Oracles

end PleaNP
