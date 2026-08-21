import PleaNP.Computability.Oracle
import PleaNP.Computability.OracleComplexity
set_option warningAsError true

/-!
# Oracle-sensitivity smoke test

One concrete oracle machine program (`smokeTM`), two oracle
instantiations (`oracleTrue`, `oracleFalse`), and the executable
distinction between them: the oracle-true machine accepts, the
oracle-false machine does not.

This is the behavioral check that the v4 reachability wiring is real
(not just type-correct): Flaw B (oracle inert) cannot return —
`AcceptsInTime` distinguishes oracle answers reached via
`EvalsToInTime`. The accept direction is closed by evaluation (`rfl`);
the reject direction uses determinism (`evalsTo_unique_result`) plus
evaluation, which is the strongest check short of `decide` over the
existential (Cfg contains function fields, so the ∃ is not decidable).
-/

namespace PleaNP

namespace Oracles

open Turing

/-- Labels for the smoke machine: query, accept-branch, reject-branch. -/
inductive SmokeLabel where
  | ask | yes | no
  deriving DecidableEq

instance : Fintype SmokeLabel where
  elems := {SmokeLabel.ask, SmokeLabel.yes, SmokeLabel.no}
  complete := fun x => by cases x <;> decide

/-- The smoke machine program. When the label is the query label, the
  oracle wrapper (`Oracles.step`) consults the oracle instead of the
  program; the program only runs the two post-oracle branches:
  push `true` (yes) or `false` (no) onto the output stack, then halt. -/
def smokeTM : FinTM2 where
  K := Fin 2
  k₀ := 0
  k₁ := 1
  Γ := fun _ => Bool
  Λ := SmokeLabel
  main := SmokeLabel.ask
  σ := PUnit
  initialState := PUnit.unit
  m := fun
    | SmokeLabel.ask => TM2.Stmt.halt
    | SmokeLabel.yes => TM2.Stmt.push 1 (fun _ => true) TM2.Stmt.halt
    | SmokeLabel.no => TM2.Stmt.push 1 (fun _ => false) TM2.Stmt.halt

/-- Typeclass resolution does not unfold `smokeTM` projections on its
  own; bridge the label instances explicitly. -/
instance : DecidableEq smokeTM.Λ := inferInstanceAs (DecidableEq SmokeLabel)

instance : Fintype smokeTM.Λ := inferInstanceAs (Fintype SmokeLabel)

/-- The two oracles under test: always-true and always-false. -/
def oracleTrue : Oracle Bool := fun _ => true

def oracleFalse : Oracle Bool := fun _ => false

/-- The same machine program with an oracle slot. -/
def smokeM (A : Oracle Bool) : Machine Bool smokeTM where
  oracle := A
  queryLabel := SmokeLabel.ask
  yesLabel := SmokeLabel.yes
  noLabel := SmokeLabel.no

/-- Two-step run of the smoke machine: step 1 consults the oracle,
  step 2 pushes the branch output and halts. -/
def smokeRun (A : Oracle Bool) (input : List Bool) : Cfg Bool smokeTM :=
  match @step smokeTM inferInstance (smokeM A)
      (@initCfg Bool smokeTM inferInstance (smokeM A) input) with
  | some c₁ =>
    match @step smokeTM inferInstance (smokeM A) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg Bool smokeTM inferInstance (smokeM A) input

/-- Single query `true` on the input stack. -/
def smokeEa : PUnit → List Bool := fun _ => [true]

/-- Positive: with the always-true oracle, the machine halts within
  2 steps with output head `true` — closed by evaluation. -/
theorem smoke_accepts_true :
    @AcceptsInTime smokeTM PUnit inferInstance smokeEa id
      (smokeM oracleTrue) PUnit.unit (fun _ => 2) := by
  refine ⟨smokeRun oracleTrue [true], ⟨⟨⟨2, rfl⟩, by decide⟩⟩, rfl, rfl⟩

/-- Negative: with the always-false oracle, no halted reachable config
  outputs `true`. The only halted endpoint is the reject branch
  (determinism), and its output head is `false`. -/
theorem smoke_rejects_false :
    ¬ @AcceptsInTime smokeTM PUnit inferInstance smokeEa id
      (smokeM oracleFalse) PUnit.unit (fun _ => 2) := by
  intro ⟨cfg', hReach, hHalt, hOutput⟩
  have hFalseRun : StateTransition.EvalsToInTime (@step smokeTM inferInstance (smokeM oracleFalse))
      (@initCfg Bool smokeTM inferInstance (smokeM oracleFalse) [true])
      (some (smokeRun oracleFalse [true])) 2 :=
    { steps := 2
      evals_in_steps :=
        (rfl : (flip bind (@step smokeTM inferInstance (smokeM oracleFalse)))^[2]
            (some (@initCfg Bool smokeTM inferInstance (smokeM oracleFalse) [true]))
          = some (smokeRun oracleFalse [true]))
      steps_le_m := by decide }
  have hRun : cfg' = smokeRun oracleFalse [true] :=
    evalsTo_unique_result
      (step_none _ _ hHalt)
      (step_none _ _ (rfl : (smokeRun oracleFalse [true]).cfg.l = Option.none))
      hReach.some.toEvalsTo
      hFalseRun.toEvalsTo
  subst hRun
  have hStk : (smokeRun oracleFalse [true]).cfg.stk smokeTM.k₁ = [false] := rfl
  rw [hStk] at hOutput
  exact absurd hOutput (by decide)

end Oracles

end PleaNP
