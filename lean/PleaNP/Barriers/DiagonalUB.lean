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

Deferred (tracked, see SORRY_TRACKER): **resolved 2026-09-13 (run=20260911-0944-qmzn)** — `U_B_in_NP` is zero-sorry. The reject-run identity, the machine-run-identity bridge, and the assembly theorem are all proved; this module builds green with the clean tree.
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

/-- Step-1 projections of the U_B machine on the initial config: the
  label routes to yes/no per the oracle answer (which is `ans` under `h`),
  the query tape k₀ is cleared, and the output tape k₁ is untouched.
  (Only these projections drive acceptance; config equality is too strong
  because the oracle field differs between `ubM B` and `ubC ans`.) -/
private def step1cfg (B : Oracle Query) (w : List Bool) : Cfg Query ubTM :=
  (@step Query ubTM inferInstance (ubM B)
    (@initCfg Query ubTM inferInstance (ubM B) w)).getD
    (@initCfg Query ubTM inferInstance (ubM B) w)

lemma step1_label (B : Oracle Query) (ans : Bool) (w : List Bool)
    (h : B (decodeWord w) = ans) :
    (step1cfg B w).cfg.l = (if ans = true then some UBLab.yes else some UBLab.no) ∧
    (step1cfg B w).cfg.stk ubTM.k₀ = [] ∧
    (step1cfg B w).cfg.stk ubTM.k₁ = (@initCfg Query ubTM inferInstance (ubM B) w).cfg.stk ubTM.k₁ := by
  unfold step1cfg step initCfg initList ubM ubTM Oracle.query
  simp [h]

/-- Direct step-1 rewrite: with oracle-false the query step returns the
  no-branch config (used to reduce `ubRun`'s match scrutinee). -/
lemma step1false_eq (B : Oracle Query) (n : Nat) (y : List Nat)
    (hf : B (decodeWord (ubEa n y)) = false) :
    @step Query ubTM inferInstance (ubM B)
      (@initCfg Query ubTM inferInstance (ubM B) (ubEa n y))
    = some (step1cfg B (ubEa n y)) := by
  unfold step1cfg step initCfg initList ubM ubTM Oracle.query
  simp [hf]

/-- The `ubM B` run on an oracle-false word halts in the no-branch. -/
lemma ubRun_halts_no (B : Oracle Query) (n : Nat) (y : List Nat)
    (hf : B (decodeWord (ubEa n y)) = false) :
    (ubRun B (ubEa n y)).cfg.l = Option.none := by
  unfold ubRun
  rw [step1false_eq B n y hf]
  -- step 2 on the no-label config pushes false and halts
  simp [step, step1cfg, initCfg, initList, ubM, ubTM, hf]

/-- Acceptance of the U_B machine forces the oracle answer to the encoded
  query to be `true` (else the machine's output would be false). This is
  the (→) direction of accepts_iff_oracle, via the reject-run argument.
  The time bound is arbitrary (only the 2-step run structure matters). -/
lemma accepts_true_oracle (B : Oracle Query) (n : Nat) (y : List Nat)
    (hacc : @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubM B) (n, y) (fun n => (Polynomial.C 1 + Polynomial.X).eval n)) :
    B (decodeWord (ubEa n y)) = true := by
  by_contra hn
  have hf : B (decodeWord (ubEa n y)) = false := by
    by_cases hb : B (decodeWord (ubEa n y)) = true <;> simp_all
  obtain ⟨cfg', hReach, hHalt, hOut⟩ := hacc
  have hRun : StateTransition.EvalsToInTime (@step Query ubTM inferInstance (ubM B))
      (@initCfg Query ubTM inferInstance (ubM B) (ubEa n y))
      (some (ubRun B (ubEa n y))) 2 :=
    { steps := 2
      evals_in_steps := by
        -- step 1 (the query) routes to the no-branch via the oracle-false
        -- answer; step 2 (on the no-label config) pushes false and halts.
        simp [ubRun, flip, Option.bind_eq_bind, step, initCfg, initList,
          ubM, ubTM, hf]
        congr 1
      steps_le_m := by omega }
  have hEq : cfg' = ubRun B (ubEa n y) :=
    evalsTo_unique_result
      (step_none _ _ hHalt)
      (step_none _ _ (ubRun_halts_no B n y hf))
      hReach.some.toEvalsTo hRun.toEvalsTo
  subst hEq
  -- the reject-run's output tape head is `false`; hOut claims `true`.
  have hSmall : (ubRun B (ubEa n y)).cfg.stk ubTM.k₁ = [false] := by
    unfold ubRun
    rw [step1false_eq B n y hf]
    simp [step, step1cfg, initCfg, initList, ubM, ubTM, hf]
  rw [hSmall] at hOut
  exact absurd hOut (by decide)

/-- The `ubM B` run on an oracle-true word halts in the yes-branch. -/
lemma ubRun_halts_yes (B : Oracle Query) (n : Nat) (y : List Nat)
    (ht : B (decodeWord (ubEa n y)) = true) :
    (ubRun B (ubEa n y)).cfg.l = Option.none ∧
    (ubRun B (ubEa n y)).cfg.stk ubTM.k₁ = [true] := by
  unfold ubRun
  -- the oracle-true answer routes step 1 to the yes-branch; step 2 pushes true-halt
  simp [step, initCfg, initList, ubM, ubTM, ht]

/-- The machine's acceptance depends only on the oracle's answer to the
  encoded query: with answer `true`, `ubM B` accepts (the query step
  routes to the yes-branch; the output head is `true`). -/
lemma accepts_depends_on_answer (B : Oracle Query) (n : Nat) (y : List Nat)
    (hans : B (decodeWord (ubEa n y)) = true) :
    @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubM B) (n, y) (fun _ => 2) := by
  refine ⟨ubRun B (ubEa n y), ⟨⟨2, ?_⟩, by simp⟩, ?halt, ?out⟩
  · simp [ubRun, flip, Option.bind_eq_bind, step, initCfg, initList,
      ubM, ubTM, hans]
    congr 1
  · exact (ubRun_halts_yes B n y hans).1
  · rw [show (ubRun B (ubEa n y)).cfg.stk ubTM.k₁ = [true] from (ubRun_halts_yes B n y hans).2]

/-- `decode (ea (n, encodeList n x)) = ⟨n, x⟩` — the certificate's word
  decodes to exactly the length-tagged witness. -/
lemma decode_ea_encode (n : Nat) (x : Bits n) :
    decodeWord (ubEa n (encodeList n x)) = ⟨n, x⟩ := by
  unfold ubEa
  rw [certBits_encodeList]
  exact decodeWord_encWord n x

/-- Any encoded word for length n has length 2n+1 (independent of the bits). -/
lemma encWord_length (n : Nat) (x : Bits n) :
    (encWord n x).length = 2 * n + 1 := by
  unfold encWord
  simp [List.length_append]
  omega

/-- Certificate bound: |encodeList n x| ≤ (Polynomial.X).eval (|ea(n,[])|). -/
lemma cert_len_le (n : Nat) (x : Bits n) :
    (encodeList n x).length ≤ (Polynomial.X).eval (ubEa n []).length := by
  rw [length_encodeList]
  rw [Polynomial.eval_X]
  rw [ubEa, encWord_length]
  omega

/-- `AcceptsInTime` is monotone in the time bound: a run within `2` steps
  is within `p.eval (|ea (n,y)|)` steps when `p.eval (|ea (n,y)|) ≥ 2`. -/
lemma accepts_time_shift (B : Oracle Query) (n : Nat) (y : List Nat)
    (hacc : @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubM B) (n, y) (fun _ => 2))
    (hp : 2 ≤ (Polynomial.C 1 + Polynomial.X).eval (ubEa n y).length) :
    @AcceptsInTime Query ubTM (Nat × List Nat) inferInstance
      (fun nk => ubEa nk.1 nk.2) (fun b => b)
      (ubM B) (n, y) (fun n => (Polynomial.C 1 + Polynomial.X).eval n) := by
  obtain ⟨cfg', hReach, hHalt, hOut⟩ := hacc
  refine ⟨cfg', ?_, hHalt, hOut⟩
  rcases hReach with ⟨h⟩
  exact ⟨h.toEvalsTo, h.steps_le_m.trans hp⟩

/-- U_B ∈ NP^B (the #36 goal). The certificate is the oracle-witness:
  `y = encodeList n x` and the machine accepts exactly on the yes-answer
  (accepts_depends_on_answer) via the decode roundtrip. -/
theorem U_B_in_NP (B : Oracle Query) :
    U_B B ∈ NP_A (alpha := Nat) B := by
  unfold NP_A
  refine ⟨ubTM, inferInstance, fun nk => ubEa nk.1 nk.2, fun b => b,
    ubM B, Polynomial.C 1 + Polynomial.X, ?_⟩
  intro n
  rw [U_B_iff_witness]
  constructor
  · intro ⟨x, hx⟩
    refine ⟨encodeList n x, ?_bound, rfl, ?_acc⟩
    · rw [length_encodeList]
      simp [ubEa, Polynomial.eval_add, Polynomial.eval_X]
      erw [encWord_length]
      omega
    · exact accepts_time_shift B n (encodeList n x)
        (accepts_depends_on_answer B n (encodeList n x) (by
          rw [decode_ea_encode n x]
          exact hx))
        (by
          simp [ubEa, Polynomial.eval_add, Polynomial.eval_X]
          erw [encWord_length]
          omega)
  · intro ⟨y, _hbound, _horacle, hacc⟩
    -- from acceptance: B (decodeWord (ubEa n y)) = true (accepts_true_oracle)
    have hB : B (decodeWord (ubEa n y)) = true := accepts_true_oracle B n y hacc
    -- the witness is certBits n y
    refine ⟨certBits n y, ?_⟩
    unfold IsWitness
    -- B ⟨n, certBits n y⟩ = true: unfold via decodeWord on (ubEa n y)
    have hD : decodeWord (ubEa n y) = ⟨n, certBits n y⟩ := by
      unfold ubEa
      exact decodeWord_encWord n (certBits n y)
    rw [← hD]
    exact hB

end BGSDiagonal
end Barriers
end PleaNP

/-! #36 completion summary (Pass 3)

`U_B_in_NP` is proved zero-sorry. The assembly used: the certificate
encoding roundtrip (`decodeWord_encWord`), `certBits_encodeList`,
`length_encodeList`, the machine-run-identity bridge
(`accepts_depends_on_answer` + `accepts_true_oracle`), the time-shift
(`accepts_time_shift`), and the polynomial-X+1 time bound. Test spec:
`docs/STATEMENTS/Oracle.v5-repair.spec.md` §5.3-5.5.
-/
