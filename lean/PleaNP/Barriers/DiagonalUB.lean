import PleaNP.Barriers.BGSDiagonal
import PleaNP.Computability.OracleSmoke
set_option warningAsError true

/-!
# Diagonal U_B machine construction (sub-task #36, Pass 1-2 progress)

Implements the **guess-query-verify oracle machine** for `U_B ∈ NP^B`
over the v5 word-query substrate (DEC-024, #35):

- **Certificate encoding roundtrip** (zero-sorry, proved): `encWord`
  length-tags a `Bits n` certificate into a word over the finite
  alphabet; `decodeWord` recovers it (`decodeWord_encWord`).
- **The machine** `ubTM`/`ubM`: on the query label it decodes the
  input word into `Query`, consults the oracle once (1 step, per v5
  spec §4.3), accepts iff yes.
- **Constant-oracle behavior** (zero-sorry, proved): with a concrete
  oracle answering `true`/`false`, the machine accepts/rejects
  (`accepts_const_true`, `rejects_const_false`).

Deferred (tracked, see SORRY_TRACKER): the bridge `accepts_depends_on_answer`
— that `ubM B` and the constant-oracle machine have identical runs when
the oracle answers the encoded query the same way — and the assembled
`U_B ∈ NP_A B` membership theorem. This module is ISOLATED (not imported
by BGSDiagonal) so `warningAsError` does not cascade.
-/

namespace PleaNP
namespace Barriers
namespace BGSDiagonal

open PleaNP.Oracles
open Turing

/-- Length-tagged word encoding of a certificate: n trues, a false
  separator, then n bits. This is what the machine writes on its input
  tape (the query word, v5 substrate). -/
def encWord (n : Nat) (x : Bits n) : List Bool :=
  List.replicate n true ++ [false] ++ List.ofFn (fun i : Fin n => x i)

/-- Leading-true count: how many `true`s prefix a word. -/
def leadTrue (w : List Bool) : Nat :=
  (w.takeWhile (fun b : Bool => b)).length

/-- The bits after the leading-true prefix and one false separator. -/
def tailBits (w : List Bool) : List Bool :=
  (w.drop (leadTrue w + 1)).take (leadTrue w)

/-- Decode a word into the length-tagged query type. The length is the
  leading-true count; the bits are the tail. -/
def decodeWord (w : List Bool) : Query :=
  ⟨leadTrue w, fun i => (tailBits w).getD i.1 false⟩

/-- The certificate's bit-value convention: only 1 means `true`. -/
def natToBit (k : Nat) : Bool := k = 1

/-- Encoding of a certificate-list into bits (the `y` of NP_A's
  certificate, of length n). -/
def certBits (n : Nat) (y : List Nat) (i : Fin n) : Bool :=
  natToBit (y.getD i.1 0)

-- Lemmas about the encoding roundtrip.

/-- `takeWhile true` on `true :: ws` skips the head. -/
lemma leadTrue_cons_true (ws : List Bool) :
    leadTrue (true :: ws) = leadTrue ws + 1 := by
  unfold leadTrue
  simp

/-- `takeWhile true` on `false :: ws` is 0. -/
lemma leadTrue_cons_false (ws : List Bool) :
    leadTrue (false :: ws) = 0 := by
  unfold leadTrue
  simp

/-- `takeWhile true` on `replicate n true ++ [false] ++ ws` is n. -/
lemma leadTrue_replicate_sep (n : Nat) (ws : List Bool) :
    leadTrue (List.replicate n true ++ [false] ++ ws) = n := by
  unfold leadTrue
  induction n with
  | zero => simp
  | succ n ih =>
    rw [List.replicate_succ]
    simp

/-- Leading-true count of the full encoding is exactly n. -/
lemma leadTrue_encWord (n : Nat) (x : Bits n) :
    leadTrue (encWord n x) = n := by
  unfold encWord
  exact leadTrue_replicate_sep n (List.ofFn (fun i : Fin n => x i))

/-- `drop (k+1)` of `replicate k true ++ [false] ++ ws` is ws. -/
lemma drop_sep_replicate (k : Nat) (ws : List Bool) :
    List.drop (k + 1) (List.replicate k true ++ [false] ++ ws) = ws := by
  induction k with
  | zero => rfl
  | succ k ih =>
    rw [List.replicate_succ]
    change List.drop (k.succ + 1) (true :: List.replicate k true ++ [false] ++ ws) = ws
    have hpos : 0 < k.succ + 1 := by omega
    simpa [List.drop_cons hpos, Nat.succ_eq_add_one] using ih

/-- The bits after `replicate n true ++ false :: ws` are exactly ws. -/
lemma tailBits_encWord (n : Nat) (x : Bits n) :
    tailBits (encWord n x) = List.ofFn (fun i : Fin n => x i) := by
  unfold encWord tailBits
  rw [leadTrue_replicate_sep]
  rw [drop_sep_replicate]
  simp

/-- Bit-roundtrip: recovering the i-th bit of the decoded word gives x i. -/
lemma getD_tailBits_encWord (n : Nat) (x : Bits n) (i : Fin n) :
    (tailBits (encWord n x)).getD i.1 false = x i := by
  rw [tailBits_encWord]
  simp

/-- Full roundtrip: decode (encWord n x) = ⟨n, x⟩. -/
lemma decodeWord_encWord (n : Nat) (x : Bits n) :
    decodeWord (encWord n x) = ⟨n, x⟩ := by
  unfold decodeWord
  rw [leadTrue_encWord]
  apply Sigma.ext
  · rfl
  · simp
    funext i
    exact getD_tailBits_encWord n x i

/-- Encoding of a certificate list x : Bits n into Nat bits. -/
def encodeList (n : Nat) (x : Bits n) : List Nat :=
  (List.ofFn x).map (fun b : Bool => if b then 1 else 0)

/-- `certBits` recovers x from `encodeList n x`. -/
lemma certBits_encodeList (n : Nat) (x : Bits n) :
    certBits n (encodeList n x) = x := by
  funext i
  unfold certBits natToBit encodeList
  simp

/-- Certificate bound: |encodeList n x| = n. -/
lemma length_encodeList (n : Nat) (x : Bits n) :
    (encodeList n x).length = n := by
  unfold encodeList
  simp

/-- ea's length on (n, []): the word length is 2n + 1. -/
lemma length_ea_empty (n : Nat) :
    (encWord n (certBits n [])).length = 2 * n + 1 := by
  unfold encWord
  simp [List.length_append]
  omega

/-- The U_B machine labels: query, accept-branch, reject-branch. -/
inductive UBLab where | ask | yes | no
  deriving DecidableEq

instance : Fintype UBLab where
  elems := {UBLab.ask, UBLab.yes, UBLab.no}
  complete := fun x => by cases x <;> decide

/-- The U_B machine program: on query label, the wrapper consults the
  oracle (v5 `step`); yes-label pushes true, no-label pushes false, halt. -/
def ubTM : FinTM2 :=
  { K := Fin 2
    k₀ := 0
    k₁ := 1
    Γ := fun _ => Bool
    Λ := UBLab
    main := UBLab.ask
    σ := PUnit
    initialState := PUnit.unit
    m := fun
      | UBLab.ask => TM2.Stmt.halt
      | UBLab.yes => TM2.Stmt.push 1 (fun _ => true) TM2.Stmt.halt
      | UBLab.no => TM2.Stmt.push 1 (fun _ => false) TM2.Stmt.halt }

instance : DecidableEq ubTM.Λ := inferInstanceAs (DecidableEq UBLab)
instance : Fintype ubTM.Λ := inferInstanceAs (Fintype UBLab)

/-- The U_B machine with oracle B: decode the input word into the
  length-tagged query, ask B, accept iff yes. -/
def ubM (B : Oracle Query) : Machine Query ubTM where
  oracle := B
  decode := decodeWord
  queryLabel := UBLab.ask
  yesLabel := UBLab.yes
  noLabel := UBLab.no

/-- The input-tape encoding function for NP_A's (x, y) pairs. -/
def ubEa (n : Nat) (y : List Nat) : List Bool :=
  encWord n (certBits n y)

/-- Time bound: polynomial X (p.eval k = k); the machine halts in 2 steps. -/
def ubTime (k : Nat) : Nat := k

/-- Two-step run of the U_B machine starting from word w. -/
def ubRun (B : Oracle Query) (w : List Bool) : Cfg Query ubTM :=
  match @step Query ubTM inferInstance (ubM B)
      (@initCfg Query ubTM inferInstance (ubM B) w) with
  | some c₁ =>
    match @step Query ubTM inferInstance (ubM B) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg Query ubTM inferInstance (ubM B) w

/-- The U_B machine with a *constant* oracle answering `ans`. The oracle
  is concrete, so the 2-step run reduces by rfl (the smoke pattern). -/
def ubC (ans : Bool) : Machine Query ubTM where
  oracle := fun _ => ans
  decode := decodeWord
  queryLabel := UBLab.ask
  yesLabel := UBLab.yes
  noLabel := UBLab.no

/-- Constant-oracle run (concrete): two explicit steps. -/
def ubCRun (ans : Bool) (w : List Bool) : Cfg Query ubTM :=
  match @step Query ubTM inferInstance (ubC ans)
      (@initCfg Query ubTM inferInstance (ubC ans) w) with
  | some c₁ =>
    match @step Query ubTM inferInstance (ubC ans) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg Query ubTM inferInstance (ubC ans) w

/-- Constant-oracle acceptance: oracle-ans-true is accepted, ans-false rejected. -/
lemma accepts_const_true (n : Nat) (y : List Nat) :
    @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubC true) (n, y) (fun _ => 2) := by
  refine ⟨ubCRun true (ubEa n y), ⟨⟨2, rfl⟩, by simp⟩, rfl, rfl⟩

/-- Constant-oracle reject: ans-false is not accepted. -/
lemma rejects_const_false (n : Nat) (y : List Nat) :
    ¬ @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubC false) (n, y) (fun _ => 2) := by
  intro ⟨cfg', hReach, hHalt, hOut⟩
  have hRun : StateTransition.EvalsToInTime (@step Query ubTM inferInstance (ubC false))
      (@initCfg Query ubTM inferInstance (ubC false) (ubEa n y))
      (some (ubCRun false (ubEa n y))) 2 :=
    { steps := 2
      evals_in_steps := rfl
      steps_le_m := by omega }
  have hEq : cfg' = ubCRun false (ubEa n y) :=
    evalsTo_unique_result
      (step_none _ _ hHalt)
      (step_none _ _ (rfl : (ubCRun false (ubEa n y)).cfg.l = Option.none))
      hReach.some.toEvalsTo hRun.toEvalsTo
  subst hEq
  simp [ubCRun, step, initCfg, initList, ubTM, ubC] at hOut

/-- The machine's acceptance depends only on the oracle's answer to the
  encoded query: with answer `ans`, `ubM B` behaves like `ubC ans` on the
  relevant input (the runs are step-for-step identical).

  Deferred: the run-identity between `ubM B` and `ubC ans` under
  `B (decodeWord (ubEa n y)) = ans` requires a step-by-step
  extensionality proof; tracked in SORRY_TRACKER / the #36 follow-up. -/
lemma accepts_depends_on_answer (B : Oracle Query) (n : Nat) (y : List Nat)
    (hans : B (decodeWord (ubEa n y)) = true) :
    @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubM B) (n, y) (fun _ => 2) := by
  sorry

/-- U_B ∈ NP^B (the #36 goal). The certificate is the oracle-witness:
  `y = encodeList n x` and the machine accepts exactly on the yes-answer.
  Assembled via `accepts_depends_on_answer` + `decodeWord_encWord` +
  `U_B_iff_witness`; proof deferred (tracked in SORRY_TRACKER). -/
theorem U_B_in_NP (B : Oracle Query) :
    U_B B ∈ NP_A (alpha := Nat) B := by
  sorry

end BGSDiagonal
end Barriers
end PleaNP

/-! #36 follow-up specification (Pass 3)

The two sorries above are the ONLY gaps to `U_B ∈ NP_A B` zero-sorry.
The bridge lemma `accepts_depends_on_answer` (machine-run identity under
equal oracle answers) is a step-by-step combinatorics of `step`/`ubRun`/
`ubCRun`; the assembly theorem then follows from `decodeWord_encWord`,
`certBits_encodeList`, `length_encodeList`, `U_B_iff_witness`, and the
time bound `length_ea_empty` (choice `p = Polynomial.X`, run in 2 steps).
Test spec: `docs/STATEMENTS/Oracle.v5-repair.spec.md` §5.3-5.5. This
follow-up is filed as a GitHub issue (Tests/Bridge: #36 Pass 3).
-/
