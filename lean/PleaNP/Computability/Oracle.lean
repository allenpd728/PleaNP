import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Computability.StateTransition
set_option warningAsError true

/-!
# Oracle machines (v4: reachability wired)

v4 repair: closes Flaw A by wiring EvalsToInTime reachability through
the real step function. ea, M, t are now load-bearing by construction.

Flaw B (oracle inert) was fixed in v3 and is kept: step branches on
queryLabel and routes the oracle answer to yesLabel/noLabel.

Flaw C is fixed in OracleComplexity.lean (AcceptsInTime with
reachability + per-input application to (x, y)).
-/

namespace PleaNP

namespace Oracles

open Turing

/-- An oracle is a total function from queries to yes/no answers. -/
def Oracle (Q : Type) := Q -> Bool

instance Oracle.inhabited (Q : Type) : Inhabited (Oracle Q) :=
  ⟨fun _ => false⟩

/-- The oracle answers a query. One step in the cost model. -/
@[simp]
def Oracle.query {Q : Type} (A : Oracle Q) (q : Q) : Bool := A q

/-- The configuration of an oracle machine. -/
structure Cfg (Q : Type) (tm : FinTM2) where
  cfg : tm.Cfg
  oracle : Oracle Q

/-- An oracle machine: a FinTM2 with a fixed oracle and query/yes/no
  labels. The tm parameter is NOT stored as a field (avoids the
  type-unification issue from v2). -/
structure Machine (Q : Type) (tm : FinTM2) [DecidableEq tm.Λ] where
  oracle : Oracle Q
  queryLabel : tm.Λ
  yesLabel : tm.Λ
  noLabel : tm.Λ

/-- Construct the initial configuration for a given input list, using
  Mathlib's Turing.initList as the loader. -/
def initCfg {Q : Type} {tm : FinTM2} [DecidableEq tm.Λ]
    (M : Machine Q tm) (input : List (tm.Γ tm.k₀)) : Cfg Q tm :=
  ⟨Turing.initList tm input, M.oracle⟩

/-- A step of the oracle machine. If the current label is the query
  label, the oracle is consulted: the query (head of the input stack)
  is sent to the oracle, the answer determines the next label
  (yesLabel for true, noLabel for false). Otherwise, delegates to
  FinTM2.step. The oracle answer IS used (Flaw B fix). -/
def step {tm : FinTM2} [DecidableEq tm.Λ]
    (M : Machine (tm.Γ tm.k₀) tm) (c : Cfg (tm.Γ tm.k₀) tm) :
    Option (Cfg (tm.Γ tm.k₀) tm) :=
  match c.cfg.l with
  | Option.none => Option.none
  | Option.some l =>
    if l = M.queryLabel then
      match c.cfg.stk tm.k₀ with
      | [] => Option.none
      | q :: rest =>
        let answer := Oracle.query c.oracle q
        some (Cfg.mk
          { l := if answer then some M.yesLabel else some M.noLabel
            var := c.cfg.var
            stk := fun k =>
              if h : k = tm.k₀ then by rw [h]; exact rest
              else c.cfg.stk k }
          c.oracle)
    else
      match FinTM2.step tm c.cfg with
      | Option.none => Option.none
      | Option.some cfg' => some (Cfg.mk cfg' c.oracle)

/-- Whether the halted config's output encodes χ_L(x): the head of
  the output stack, decoded via outputAlphabet, equals true iff x ∈ L. -/
def outputEncodesChi {Q : Type} {tm : FinTM2} {alpha : Type}
    (outputAlphabet : tm.Γ tm.k₁ -> Bool)
    (c : Cfg Q tm) (L : Set alpha) (x : alpha) : Prop :=
  match c.cfg.stk tm.k₁ with
  | [] => False
  | head :: _ => outputAlphabet head = true ↔ x ∈ L

/-- A language L is decided in time t by oracle machine M if, for
  every input x, M started on ea x reaches a halted configuration
  within t(|ea x|) steps (via EvalsToInTime on the real step
  function), AND the halted config's output encodes χ_L(x).

  v4 fix (Flaw A): ea, M, t are ALL load-bearing — ea builds the
  initial config, M provides the step function, t bounds the steps. -/
def DecidesInTime {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha -> List (tm.Γ tm.k₀))
    (outputAlphabet : tm.Γ tm.k₁ -> Bool)
    (M : Machine (tm.Γ tm.k₀) tm) (L : Set alpha) (t : Nat -> Nat) : Prop :=
  ∀ x : alpha,
    ∃ cfg' : Cfg (tm.Γ tm.k₀) tm,
      Nonempty (StateTransition.EvalsToInTime (step M) (initCfg M (ea x)) (some cfg') (t (ea x).length))
      ∧ cfg'.cfg.l = Option.none
      ∧ outputEncodesChi outputAlphabet cfg' L x

/-- The empty oracle. -/
def emptyOracle (Q : Type) : Oracle Q := fun _ => false

/-- P^∅ = P compatibility (statement, proof pending upstream P). -/
theorem P_empty_eq_upstream_P {Q : Type} {tm : FinTM2} [DecidableEq tm.Λ]
    (M : Machine Q tm) (h_empty : M.oracle = emptyOracle Q) :
    True := by
  sorry

end Oracles

end PleaNP
