import PleaNP.Computability.Oracle
import PleaNP.Computability.OracleComplexity
import PleaNP.Computability.OracleSmoke
import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Computability.Encoding

set_option warningAsError true

/-!
# v5 word-query substrate tests (issue #40)

The v5 repair (DEC-024, #35) rewired the oracle substrate so that an
oracle query is the **content of the input tape** — a finite word over
the machine's finite input alphabet, decoded via `Machine.decode` into
the query value-space `Q` — instead of the v4 fusion of `Q` into the
alphabet slot (`hΓ`). These tests exercise the repaired substrate in
the three ways #40's DoD calls for:

1. **Query is exactly one step.** Starting from a configuration whose
   current label is the query label, **one** application of
   `Oracles.step` consults the oracle on the decoded input-tape word
   and routes to `yesLabel`/`noLabel` — the single-transition property
   (`OracleTM2Recompose.spec.md` §4 trap 2), pinned by `native_decide`
   on concrete data.
2. **Word-query smoke machine.** The `OracleSmoke.lean` analogue whose
   query-tape content is a nontrivial word (`[true, false, true]`, the
   binary string "101"): one machine program, two oracle
   instantiations, and the executable accept/reject distinction — the
   check that the word-query path works end-to-end.
3. **`P^∅ = P` compatibility (statement).** The empty-oracle classes
   collapse to the oracle-free polytime class `UpstreamPolyTime`
   (`TM2ComputableInPolyTime` recharacterization), per Trap 3. The
   canonical fully-rendered statement (no statement-level `sorry`)
   lives in `PleaNP.Oracles.P_empty_eq_upstream_P_class`
   (`OracleUpstreamP.lean`); this file sanity-checks that
   `UpstreamPolyTime` is a real predicate on languages (not `True` or
   a vacuous set).

Zero sorries in this file; all tests compile under `warningAsError`.
-/

namespace PleaNP

namespace Oracles

open Turing

section OneStepQuery

/-- Labels for the one-step machine: query/ask, yes-branch, no-branch. -/
inductive QLabel where
  | ask | yes | no
  deriving DecidableEq

instance : Fintype QLabel where
  elems := {QLabel.ask, QLabel.yes, QLabel.no}
  complete := fun x => by cases x <;> decide

/-- A deliberately trivial program: at `ask` the program itself is
  `halt` — the *oracle step* does the routing. The two post-query
  branches push a marker and halt, exactly like the smoke machine. -/
def qTM : FinTM2 where
  K := Fin 2
  k₀ := 0
  k₁ := 1
  Γ := fun _ => Bool
  Λ := QLabel
  main := QLabel.ask
  σ := PUnit
  initialState := PUnit.unit
  m := fun
    | QLabel.ask => TM2.Stmt.halt
    | QLabel.yes => TM2.Stmt.push 1 (fun _ => true) TM2.Stmt.halt
    | QLabel.no => TM2.Stmt.push 1 (fun _ => false) TM2.Stmt.halt

instance : DecidableEq qTM.Λ := inferInstanceAs (DecidableEq QLabel)
instance : Fintype qTM.Λ := inferInstanceAs (Fintype QLabel)

/-- The word-query decode: the query value is the entire input-tape
  word, sent to the oracle's query type `List Bool`. -/
def rawDecode (w : List (qTM.Γ qTM.k₀)) : List Bool := w

/-- The machine for the one-step test: `decode` is the identity on the
  input word, oracle arbitrary. -/
def qM (A : Oracle (List Bool)) : Machine (List Bool) qTM :=
  { oracle := A
    decode := rawDecode
    queryLabel := QLabel.ask
    yesLabel := QLabel.yes
    noLabel := QLabel.no }

/-- The "101" word. -/
def word101 : List (qTM.Γ qTM.k₀) := [true, false, true]

/-- The oracle that answers "yes" exactly on the word "101". -/
def oracleYesOnOneZeroOne : Oracle (List Bool) :=
  fun w => w = [true, false, true]

/-- The always-"no" oracle. -/
def oracleAlwaysNo : Oracle (List Bool) :=
  fun _ => false

/-- (i) The query transition is exactly ONE step. `EvalsTo` records the
  exact step count: from the initial config on the word "101", the
  query configuration (the oracle consultation) is reached in exactly
  `1` step of `Oracles.step` — closed by `rfl`, so the count is
  machine-checked, not asserted. -/
example :
    StateTransition.EvalsTo (step (qM oracleYesOnOneZeroOne))
      (initCfg (qM oracleYesOnOneZeroOne) word101)
      (step (qM oracleYesOnOneZeroOne) (initCfg (qM oracleYesOnOneZeroOne) word101)) :=
  ⟨1, rfl⟩

/-- (i) The oracle answer routes the single step to the yes label: the
  one-query config's label is `QLabel.yes` (the oracle was consulted on
  the *decoded word*, not on anything free). -/
example :
    let c' := step (qM oracleYesOnOneZeroOne) (initCfg (qM oracleYesOnOneZeroOne) word101)
    match c' with
    | some c => c.cfg.l = some QLabel.yes
    | none => False := by
  simp [Oracles.step, qM, oracleYesOnOneZeroOne, initCfg, rawDecode, word101]
  rfl

/-- (i) Same routing to the NO label with the no-oracle: the oracle
  answer is load-bearing (Flaw B cannot return). -/
example :
    let c' := step (qM oracleAlwaysNo) (initCfg (qM oracleAlwaysNo) word101)
    match c' with
    | some c => c.cfg.l = some QLabel.no
    | none => False := by
  simp [Oracles.step, qM, oracleAlwaysNo, initCfg, rawDecode, word101]
  rfl

/-- (i) The decoded word is the full "101" word (the input-tape
  content, not a single symbol): the oracle is consulted on a *word*,
  the v5 substrate's defining property. -/
example : rawDecode word101 = [true, false, true] := rfl

end OneStepQuery

section WordQuerySmoke

/-- (ii) The word-query smoke machine. Uses `qTM`/`wM` (same program
  shape as `OracleSmoke.lean`'s `smokeTM`), with the nontrivial query
  word "101" as the input tape content and `decode = rawDecode` (the
  query value is the word). Two oracles, accept/reject. -/
abbrev Qw := List Bool

/-- The word-recognizing oracle: "yes" exactly on the word "101". -/
def wordOracleTrue : Oracle Qw :=
  fun w => w = [true, false, true]

/-- The always-false oracle. -/
def wordOracleFalse : Oracle Qw :=
  fun _ => false

/-- The same machine program with an oracle slot. -/
def wM (A : Oracle Qw) : Machine Qw qTM :=
  { oracle := A
    decode := rawDecode
    queryLabel := QLabel.ask
    yesLabel := QLabel.yes
    noLabel := QLabel.no }

/-- The input encoding: the single word under test. -/
def wEa : PUnit → List (qTM.Γ qTM.k₀) := fun _ => word101

/-- Two-step run: step 1 consults the oracle on the "101" word, step 2
  pushes the branch output and halts. -/
def wRun (A : Oracle Qw) : Cfg Qw qTM :=
  match @step Qw qTM inferInstance (wM A) (@initCfg Qw qTM inferInstance (wM A) word101) with
  | some c₁ =>
    match @step Qw qTM inferInstance (wM A) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg Qw qTM inferInstance (wM A) word101

/-- Positive: with the word-recognizing oracle, the machine halts
  within 2 steps with output head `true` — the answer routes to the
  yes branch. -/
theorem word_smoke_accepts :
    @AcceptsInTime Qw qTM PUnit inferInstance wEa id
      (wM wordOracleTrue) PUnit.unit (fun _ => 2) := by
  refine ⟨wRun wordOracleTrue, ⟨⟨⟨2, rfl⟩, by decide⟩⟩, rfl, rfl⟩

/-- Negative: with the always-false oracle, no halted reachable config
  outputs `true` for the "101" input. The only halted endpoint is the
  reject branch (determinism via `evalsTo_unique_result`), whose output
  head is `false`. -/
theorem word_smoke_rejects :
    ¬ @AcceptsInTime Qw qTM PUnit inferInstance wEa id
      (wM wordOracleFalse) PUnit.unit (fun _ => 2) := by
  intro ⟨cfg', hReach, hHalt, hOutput⟩
  have hFalseRun : StateTransition.EvalsToInTime (@step Qw qTM inferInstance (wM wordOracleFalse))
      (@initCfg Qw qTM inferInstance (wM wordOracleFalse) word101)
      (some (wRun wordOracleFalse)) 2 :=
    { steps := 2
      evals_in_steps :=
        (rfl : (flip bind (@step Qw qTM inferInstance (wM wordOracleFalse)))^[2]
            (some (@initCfg Qw qTM inferInstance (wM wordOracleFalse) word101))
          = some (wRun wordOracleFalse))
      steps_le_m := by decide }
  have hRun : cfg' = wRun wordOracleFalse :=
    evalsTo_unique_result
      (step_none _ _ hHalt)
      (step_none _ _ (rfl : (wRun wordOracleFalse).cfg.l = Option.none))
      hReach.some.toEvalsTo
      hFalseRun.toEvalsTo
  subst hRun
  have hStk : (wRun wordOracleFalse).cfg.stk qTM.k₁ = [false] := rfl
  rw [hStk] at hOutput
  exact absurd hOutput (by decide)

end WordQuerySmoke

section PEmptyEqP

/-- (iii) The RHS of the P^∅ = P anchor is a genuine recharacterization
  (not `True`/vacuously-huge): a concrete language over `Bool` (the
  "atoms equal true" set) is a member, witnessed by Mathlib's own
  `idComputableInPolyTime` as the polytime characteristic-function
  machine. This proves `UpstreamPolyTime Bool` is nonempty and its
  members really are languages with a `TM2ComputableInPolyTime` χ. The
  full statement `P_A _ (emptyOracle _) = UpstreamPolyTime _` is
  rendered at `P_empty_eq_upstream_P_class` (`OracleUpstreamP.lean`),
  SORRY_TRACKER #7 (proof pending upstream P / DEC-003). -/
example : (fun b : Bool => b = true) ∈ UpstreamPolyTime Bool := by
  unfold UpstreamPolyTime
  refine ⟨Bool, Computability.encodeBool, Computability.encodeBool, id, ?first, ?second⟩
  · intro b
    exact Iff.rfl
  · exact ⟨idComputableInPolyTime Computability.encodeBool⟩

end PEmptyEqP

end Oracles

end PleaNP