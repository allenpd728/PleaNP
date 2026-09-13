import PleaNP.Computability.OracleComplexity

set_option warningAsError true

/-!
# Rung 7 Tier-1 baseline — `UpstreamPolyTime` closure facts (issue #81, T1.4)

The first **Tier-1 baseline datapoint**: non-trivial set-membership facts about
the oracle-free polynomial-time class `UpstreamPolyTime` (the
`TM2ComputableInPolyTime` function-to-language recharacterization from
`OracleComplexity.lean` — the P^∅ = P anchor's RHS).

What is proved here (zero sorries):

1. `constFalseInPolyTime` — a **concrete poly-time Turing machine** that
   computes the constant `false` characteristic function: on input `[a]` it
   pops the single symbol and pushes `false`, halting with output `[false]`
   in one step (so `time := 1`, a constant, trivially polynomial).
2. `emptyLang_in_UpstreamPolyTime` — `∅ : Set Bool ∈ UpstreamPolyTime Bool`,
   witnessed by that machine.
3. `constTrueInPolyTime` — the mirror machine computing constant `true`.
4. `univLang_in_UpstreamPolyTime` — `(⊤ : Set Bool) ∈ UpstreamPolyTime Bool`.

The canonical T1.4 closure statements (`P` closed under `∩`, `∪`, `¬`) are
NOT yet theorems: machine composition for `TM2ComputableInPolyTime` is a
`proof_wanted` in Mathlib (`Turing.TM2ComputableInPolyTime.comp`,
`Mathlib/Computability/TuringMachine/Computable.lean`), so composing the
constant machines with input-dependent `not`/`and`/`or` machines — the
general closure argument — is blocked on that upstream hole. This is
documented in `docs/BENCHMARK.md` as the honest measurement: the closure
lemmas are the next calibration step once composition (or a PleaNP-local
composition) lands.

This module is the calibration record for the Rung-7 Tier-1 baseline (issue
#81 Pass 2): a textbook complexity-class fact, formalized through the gates,
zero-sorry.
-/

namespace PleaNP

namespace Benchmark

open Turing

/-- Transparent single-symbol encoding on `Bool` (definitionally reduces;
  it is `Computability.encodeBool` by `rfl`). -/
def enc : Bool → List Bool := fun b => [b]

/-- The constant-false machine: single tape; pops the single input symbol,
  pushes `false`, halts. Output = `[false]`. -/
inductive TwoLabel where | step
  deriving DecidableEq

instance : Fintype TwoLabel := ⟨{TwoLabel.step}, by intro x; cases x; simp⟩

def constMachine (out : Bool) : FinTM2 :=
  { K := Unit
    k₀ := ⟨⟩
    k₁ := ⟨⟩
    Γ := fun _ => Bool
    Λ := TwoLabel
    main := TwoLabel.step
    σ := PUnit
    initialState := PUnit.unit
    m := fun
      | TwoLabel.step =>
          TM2.Stmt.pop ⟨⟩ (fun _ : PUnit => fun _ : Option Bool => PUnit.unit)
            (TM2.Stmt.push ⟨⟩ (fun _ => out) TM2.Stmt.halt) }

instance : DecidableEq (constMachine out : FinTM2).Λ := inferInstanceAs (DecidableEq TwoLabel)
instance : Fintype (constMachine out : FinTM2).Λ := inferInstanceAs (Fintype TwoLabel)

/-- The constant machine computes `out` in one step (poly time). -/
noncomputable def constInPolyTime (out : Bool) :
    @TM2ComputableInPolyTime Bool Bool Bool Bool enc enc
      (fun _ : Bool => out) where
  tm := constMachine out
  inputAlphabet := Equiv.refl Bool
  outputAlphabet := Equiv.refl Bool
  time := 1
  outputsFun a := by
    -- Reduce transports, the wrapper, the time bound, and the machine's
    -- pop-push behavior to a raw one-step `EvalsToInTime`.
    simp [TM2OutputsInTime, initList, haltList, constMachine, Polynomial.eval, enc]
    refine ⟨⟨1, ?_⟩, ?_⟩
    · -- one step pops `[a]` (leaving `[]`) and pushes `out` (leaving `[out]`).
      simp [flip, Option.bind_eq_bind, TM2.step, Function.update_eq_const_of_subsingleton]
      rfl
    · norm_num

/-- The constant-false characteristic function is poly-time computable. -/
noncomputable def constFalseInPolyTime :
    @TM2ComputableInPolyTime Bool Bool Bool Bool enc enc
      (fun _ : Bool => false) :=
  constInPolyTime false

/-- The constant-true characteristic function is poly-time computable. -/
noncomputable def constTrueInPolyTime :
    @TM2ComputableInPolyTime Bool Bool Bool Bool enc enc
      (fun _ : Bool => true) :=
  constInPolyTime true

/-- The EMPTY language is in the oracle-free poly-time class. -/
theorem emptyLang_in_UpstreamPolyTime :
    (∅ : Set Bool) ∈ PleaNP.Oracles.UpstreamPolyTime Bool := by
  unfold PleaNP.Oracles.UpstreamPolyTime
  refine ⟨Bool, enc, enc, (fun _ : Bool => false), ?_, ?_⟩
  · intro a; simp
  · exact ⟨constFalseInPolyTime⟩

/-- The UNIVERSAL language is in the oracle-free poly-time class. -/
theorem univLang_in_UpstreamPolyTime :
    (⊤ : Set Bool) ∈ PleaNP.Oracles.UpstreamPolyTime Bool := by
  unfold PleaNP.Oracles.UpstreamPolyTime
  refine ⟨Bool, enc, enc, (fun _ : Bool => true), ?_, ?_⟩
  · intro a; simp
  · exact ⟨constTrueInPolyTime⟩

end Benchmark

end PleaNP