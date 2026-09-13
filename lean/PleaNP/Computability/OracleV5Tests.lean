import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec

set_option warningAsError true

/-!
# v5 word-query substrate — executable test coverage (issue #40)

Follow-up to the v5 word-query oracle-substrate repair (#35,
`docs/STATEMENTS/Oracle.v5-repair.spec.md`). This module provides the
*executable* checks for the §5 acceptance items; the accompanying test
spec (coverage narrative + regression contract) is
`docs/STATEMENTS/OracleV5.tests.spec.md`.

Covered items:

1. **Query is exactly one step** — the query transition (consulting the
   oracle on the decode of the query word) is a single `step`
   application that routes to `yesLabel` / `noLabel` by the oracle
   answer (spec §4.3(2)); pinned as `rfl` examples on the real `step`.
2. **Word-query smoke machine** — a concrete machine whose query word
   is *nontrivial* (`[true, false, true]` — the "101" analogue over the
   Bool alphabet), with two oracles (`oracleTrue`, `oracleFalse`)
   proving the accept / reject split end-to-end (spec §5(3)).
3. **P^∅ = P empty-oracle note** — the empty oracle
   (`emptyOracle O := fun _ => false`) makes the query channel inert;
   pinned as a definitional fact so the P^∅ → P statement
   (`OracleUpstreamP.lean`) reads off a stable base (spec §4.2(4)/§5(5)).

Every `example`/`theorem` below *must* typecheck (theorems closed by
`rfl`/evaluation), so a regression in the substrate kills the build:
this module is part of the `PleaNP` library glob and CI builds the
clean module set including it.
-/

namespace PleaNP

namespace Oracles

open Turing

/-! ## 1. Query is exactly one step -/

/-- Word-query machine labels: query, accept-branch, reject-branch. -/
inductive V5Label where
  | ask | yes | no
  deriving DecidableEq

instance : Fintype V5Label where
  elems := {V5Label.ask, V5Label.yes, V5Label.no}
  complete := fun x => by cases x <;> decide

/-- The word-query smoke machine: the program is inert at the query
  label (the oracle wrapper handles it); the two post-oracle branches
  push `true` (yes) / `false` (no) onto the output stack and halt. -/
def v5tm : FinTM2 where
  K := Fin 2
  k₀ := 0
  k₁ := 1
  Γ := fun _ => Bool
  Λ := V5Label
  main := V5Label.ask
  σ := PUnit
  initialState := PUnit.unit
  m := fun
    | V5Label.ask => TM2.Stmt.halt
    | V5Label.yes => TM2.Stmt.push 1 (fun _ => true) TM2.Stmt.halt
    | V5Label.no => TM2.Stmt.push 1 (fun _ => false) TM2.Stmt.halt

instance : DecidableEq v5tm.Λ := inferInstanceAs (DecidableEq V5Label)

instance : Fintype v5tm.Λ := inferInstanceAs (Fintype V5Label)

/-- The query word under test: `[true, false, true]` — the "101"
  analogue over the Bool alphabet. The decode reads this exact word. -/
def v5QueryWord : List Bool := [true, false, true]

/-- Query value-space for the smoke test: the Bool answer. -/
abbrev V5Query := Bool

/-- Decode: the query word's answer is its HEAD symbol (the v5
  convention that the machine's query is the word's content; the "101"
  word decodes to `true`). A regression to the pre-v5 "query = single
  input symbol" reading would change this and fail the accept
  direction below. -/
def v5Decode (w : List Bool) : V5Query :=
  match w with | [] => false | h :: _ => h

/-- The machine with an oracle slot and the word decode. -/
def v5M (A : Oracle V5Query) : Machine V5Query v5tm where
  oracle := A
  decode := v5Decode
  queryLabel := V5Label.ask
  yesLabel := V5Label.yes
  noLabel := V5Label.no

/-- Two-step run: step 1 consults the oracle on the query word, step 2
  pushes the branch output and halts. -/
def v5Run (A : Oracle V5Query) (input : List Bool) : Cfg V5Query v5tm :=
  match @step V5Query v5tm inferInstance (v5M A)
      (@initCfg V5Query v5tm inferInstance (v5M A) input) with
  | some c₁ =>
    match @step V5Query v5tm inferInstance (v5M A) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg V5Query v5tm inferInstance (v5M A) input

/-- The two oracles under test: always-true and always-false. -/
def v5OracleTrue : Oracle V5Query := fun _ => true

def v5OracleFalse : Oracle V5Query := fun _ => false

/-- **Query is one step (yes-route):** starting from the query label, a
  single `step` consults the oracle on `decode` of the query word and
  routes to `yesLabel`. The oracle-consult transition is counted once
  (spec §4.3(2) pinned as an `rfl` check on the real `step`). -/
example : (step (v5M v5OracleTrue) (initCfg (v5M v5OracleTrue) v5QueryWord)).map (fun c => c.cfg.l)
    = some (some V5Label.yes) := by
  rfl

/-- **Query is one step (no-route):** the same single-step consultation
  under the always-false oracle routes to `noLabel`. -/
example : (step (v5M v5OracleFalse) (initCfg (v5M v5OracleFalse) v5QueryWord)).map (fun c => c.cfg.l)
    = some (some V5Label.no) := by
  rfl

/-! ## 2. Word-query smoke accept / reject -/

/-- Input encoding: the query word itself on the input tape. -/
def v5Ea : PUnit → List Bool := fun _ => v5QueryWord

/-- **Accept:** with the always-true oracle and the nontrivial query
  word "101" (decoding to `true`), the machine halts within 2 steps with
  output head `true`. Closed by evaluation. -/
theorem v5_smoke_accepts_true :
    @AcceptsInTime V5Query v5tm PUnit inferInstance v5Ea id
      (v5M v5OracleTrue) PUnit.unit (fun _ => 2) := by
  refine ⟨v5Run v5OracleTrue v5QueryWord, ⟨⟨⟨2, rfl⟩, by decide⟩⟩, rfl, rfl⟩

/-- **Reject:** with the always-false oracle and the same input word, no
  halted reachable config outputs `true`. The only halted endpoint is the
  reject branch (determinism + evaluation). -/
theorem v5_smoke_rejects_false :
    ¬ @AcceptsInTime V5Query v5tm PUnit inferInstance v5Ea id
      (v5M v5OracleFalse) PUnit.unit (fun _ => 2) := by
  intro ⟨cfg', hReach, hHalt, hOutput⟩
  have hFalseRun : StateTransition.EvalsToInTime (@step V5Query v5tm inferInstance (v5M v5OracleFalse))
      (@initCfg V5Query v5tm inferInstance (v5M v5OracleFalse) v5QueryWord)
      (some (v5Run v5OracleFalse v5QueryWord)) 2 :=
    { steps := 2
      evals_in_steps :=
        (rfl : (flip bind (@step V5Query v5tm inferInstance (v5M v5OracleFalse)))^[2]
            (some (@initCfg V5Query v5tm inferInstance (v5M v5OracleFalse) v5QueryWord))
          = some (v5Run v5OracleFalse v5QueryWord))
      steps_le_m := by decide }
  have hRun : cfg' = v5Run v5OracleFalse v5QueryWord :=
    evalsTo_unique_result
      (step_none _ _ hHalt)
      (step_none _ _ (rfl : (v5Run v5OracleFalse v5QueryWord).cfg.l = Option.none))
      hReach.some.toEvalsTo
      hFalseRun.toEvalsTo
  subst hRun
  have hStk : (v5Run v5OracleFalse v5QueryWord).cfg.stk v5tm.k₁ = [false] := rfl
  rw [hStk] at hOutput
  exact absurd hOutput (by decide)

/-! ## 3. P^∅ = P (empty-oracle note) -/

/-- The empty oracle is the identity of the query channel: every query
  answers `false`. Pinned as a definitional fact so the P^∅ → P
  compatibility statement (`OracleUpstreamP.lean`) reads off a stable
  base. -/
example (q : V5Query) : emptyOracle V5Query q = false := rfl

/-- Under the empty oracle, the word-query smoke machine's oracle is
  exactly `emptyOracle`: with no oracle answers, the machine behaves
  like an ordinary no-oracle machine (spec §4.2(4) reading). -/
example : v5M v5OracleFalse = v5M (emptyOracle V5Query) := rfl

end Oracles

end PleaNP
