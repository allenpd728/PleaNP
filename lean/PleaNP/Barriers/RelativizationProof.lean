import PleaNP.Challenges.Relativization
import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec
import Mathlib.Computability.Primrec.Basic

set_option warningAsError true

/-!
# Relativization proof-work module (BGS 1975, clause (a)+(b))

DEC-022 §3.3 paper-statement layout (issue #66): the *proof work* for the
BGS clauses lives in its own module, physically separated from the
statement/claim root (`lean/PleaNP/Barriers/Relativization.lean` — which
holds the two `theorem` claims and their honest, tracked `sorry`
placeholders until #18/#63 close them). The statement root **does not
import** this module; this module imports only the clean substrates
(`PleaNP.Challenges.Relativization` for the zero-sorry statement
references + `PleaNP.Computability.OracleComplexity` for `P_A`/`NP_A`).

## What lives here

- The **BGS barrier consequence** (the derived corollary of `Relativization.md`
  §3): the reason relativistic proof techniques cannot resolve P vs NP.
  Rendered in its purest oracle-uniform form — if a *collapse* claim holds
  for every oracle then it is contradicted by the separating oracle; if a
  *separation* claim holds for every oracle then it is contradicted by the
  equalizing oracle. Each is provable right now (zero sorries).
- Onward proof-work lemmas (A1–A5 for clause (a), D1–D6 for clause (b)) land
  here as they are proved; the statement root is never edited by proof
  search (Gate-1 freeze discipline).

## The barrier-consequence shape

Baker–Gill–Solovay 1975 exhibited:

  (a) an equalizing oracle A with P^A = NP^A, and
  (b) a separating oracle B with P^B ≠ NP^B.

A *relativizing* proof technique must be uniform in the oracle: any
conclusion it reaches for one oracle it reaches for every oracle. Hence:

  · a relativizing proof of P = NP ⇒ P^B = NP^B, contradicting (b);
  · a relativizing proof of P ≠ NP ⇒ P^A ≠ NP^A, contradicting (a).

So the two existence clauses are jointly **incompatible** with an
oracle-uniform resolution of P vs NP. That joint incompatibility is what
`#barrier_check`'s "DEAD" verdict reports.
-/

namespace PleaNP

namespace Barriers

namespace RelativizationProof

open PleaNP.Oracles
open PleaNP.Challenges
open Turing

/-! ## The barrier consequence (zero-sorry, provable today) -/

/-- **A uniform collapse contradicts the separating oracle.** If P^A = NP^A
  held for *every* oracle (the conclusion of any relativizing proof of
  P = NP), then it would hold in particular for the separating oracle B —
  whose defining property is P^B ≠ NP^B. Contradiction.

  This is the purest form of the clause-(b) barrier: no proof technique
  uniform in the oracle can establish the collapse. -/
theorem uniform_collapse_contradicted_by_separating
    (hCollapse : ∀ B : Oracle QueryType,
      P_A (alpha := InputType) B = NP_A (alpha := InputType) B)
    (hSeparating : ∃ B : Oracle QueryType,
      P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B) :
    False := by
  rcases hSeparating with ⟨B, hB⟩
  exact hB (hCollapse B)

/-- **A uniform separation contradicts the equalizing oracle.** If P^A ≠ NP^A
  held for *every* oracle (the conclusion of any relativizing proof of
  P ≠ NP), then it would hold in particular for the equalizing oracle A —
  whose defining property is P^A = NP^A. Contradiction.

  Mirror form of the clause-(a) barrier. -/
theorem uniform_separation_contradicted_by_equalizing
    (hSep : ∀ A : Oracle QueryType,
      P_A (alpha := InputType) A ≠ NP_A (alpha := InputType) A)
    (hEqualizing : ∃ A : Oracle QueryType,
      P_A (alpha := InputType) A = NP_A (alpha := InputType) A) :
    False := by
  rcases hEqualizing with ⟨A, hA⟩
  exact (hSep A) hA

/-- **Jointly: no oracle-uniform resolution of P vs NP.** Given the two BGS
  existence facts — an equalizing oracle (P^A = NP^A for some A) and a
  separating oracle (P^B ≠ NP^B for some B) — neither uniform direction of a
  P-vs-NP resolution can hold: a uniform collapse would force P^B = NP^B on
  the separating oracle, and a uniform separation would force P^A ≠ NP^A on
  the equalizing oracle. This is the single "relativization blocks both
  directions" statement of the barrier consequence. -/
theorem no_uniform_resolution_of_p_vs_np
    (hEqualizing : ∃ A : Oracle QueryType,
      P_A (alpha := InputType) A = NP_A (alpha := InputType) A)
    (hSeparating : ∃ B : Oracle QueryType,
      P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B) :
    ¬ (∀ B : Oracle QueryType, P_A (alpha := InputType) B = NP_A (alpha := InputType) B) ∧
    ¬ (∀ A : Oracle QueryType, P_A (alpha := InputType) A ≠ NP_A (alpha := InputType) A) := by
  constructor
  · intro hCollapse
    rcases hSeparating with ⟨B, hB⟩
    exact hB (hCollapse B)
  · intro hSep
    rcases hEqualizing with ⟨A, hA⟩
    exact (hSep A) hA

/-! ## A2 — the console oracle (issue #63 Pass 1)

Clause-(a)'s equality witness is a **console oracle** — a total
`Oracle QueryType` with a *verified decidable decision procedure* (so the
`Computable` hypothesis of `exists_equalizing_oracle` is inhabited, not
assumed). The EXP-complete console oracle of
`docs/STATEMENTS/Relativization.equalizing-design.md` §2.1 simulates a
machine for an exponential bound; the *computability side* is demonstrated
here on concrete decidable predicates over the bitstring query space —
each total by construction (`Oracle Q := Q → Bool`) and `Computable` via a
`Primrec` certificate (A2's total-computability milestone, `#print axioms`
clean). The collapse inclusion machinery (A3) and the sandwich assembly
(A5) land in later passes; the statement root's `sorry` is untouched until
A5.
-/

/-- **Console oracle (A2, concrete 1):** answers `true` iff the query
  bitstring is the empty word. Defined directly as the decision of the
  "is-empty" predicate — total by construction (`Oracle`'s codomain is
  `Bool`), and the decision function is literally this `decide`, so the
  `Computable` proof needs no equality bridge. -/
def consoleOracleEmpty (w : QueryType) : Bool :=
  decide (w = [])

/-- The empty-word decision procedure is `Primrec` (length = 0), so the
  console oracle is `Computable` — the A2 total-computability proof. -/
theorem consoleOracleEmpty_computable :
    Computable (α := QueryType) consoleOracleEmpty := by
  -- consoleOracleEmpty IS decide (fun w => w = []); the empty-list predicate
  -- is the length-0 PrimrecPred; the underlying Primrec (decide ∘ p) is the
  -- oracle itself, and to_comp lifts it to Computable.
  have hLen0 : PrimrecPred fun w : List Bool => List.length w = 0 := by
    -- PrimrecRel.comp hR hf hg : PrimrecPred (R (f a) (g a)), R = (=).
    exact (PrimrecRel.comp (R := fun (n m : Nat) => n = m)
      (Primrec.eq (α := Nat)) (Primrec.list_length : Primrec (@List.length Bool))
      (Primrec.const (α := List Bool) 0))
  have hEmpty : PrimrecPred fun w : List Bool => w = [] :=
    hLen0.of_eq (by intro w; exact List.length_eq_zero_iff)
  rcases hEmpty with ⟨_dec, hp⟩
  -- hp : Primrec fun a => decide ((fun w => w = []) a); of_eq converts that
  -- Computable to consoleOracleEmpty (which IS decide (w = []), by rfl).
  exact (hp.to_comp).of_eq (by intro a; simp [consoleOracleEmpty])

/-- **Console oracle (A2, concrete 2):** answers `true` iff the queue
  bitstring's first symbol is `true` (the leading-bit oracle). Same shape —
  the decision of the "head is true" predicate. -/
def consoleOracleHead (w : QueryType) : Bool :=
  decide ((List.headI w : Bool) = true)

/-- The leading-bit oracle is `Computable` (the head function is `Primrec`). -/
theorem consoleOracleHead_computable :
    Computable (α := QueryType) consoleOracleHead := by
  have hP : PrimrecPred fun w : List Bool => (List.headI w : Bool) = true := by
    exact (PrimrecRel.comp (R := fun (b₁ b₂ : Bool) => b₁ = b₂)
      (Primrec.eq (α := Bool)) (Primrec.list_headI : Primrec (@List.headI Bool _))
      (Primrec.const (α := List Bool) true))
  rcases hP with ⟨_dec, hp⟩
  -- hp : Primrec fun a => decide ((fun w => w.headI = true) a); of_eq
  -- converts to consoleOracleHead (decide (headI w = true), by rfl).
  exact (hp.to_comp).of_eq (by intro a; simp [consoleOracleHead])

/-- **A2 sanity — the console oracle instances inhabit the statement's
  `Computable` hypothesis.** The frozen clause-(a) claim's first conjunct
  (`Computable (α := QueryType) A`) is satisfied by a concrete witness, so
  the existence claim's hypothesis is *inhabited* (not vacuous). The class
  equality conjunct is the A3–A5 work. -/
example :
    ∃ A : Oracle QueryType, Computable (α := QueryType) A := by
  refine ⟨consoleOracleEmpty, consoleOracleEmpty_computable⟩


/-! ## A3 — the one-query oracle language machine (issue #63 Pass 2)

The content direction of A3 (`NP^A ⊆ P^A`) is: a single query to the
console oracle decides the witness check, so a `P^A` machine can simulate
an `NP^A` verifier. The building block is the **one-query machine**: an
oracle machine whose program, on the query label, lets the v5 wrapper
consult the oracle on the input word (decode = identity over the
`QueryType = List Bool` query space), then routes the oracle answer to a
yes/no branch that pushes the answer bit and halts. For a fixed oracle
`A`, this machine *decides in 2 steps* the language
`L_A := { w | A w = true }` — the oracle's own accepted set —
establishing `L_A ∈ P_A A` with a concrete constant time bound.
-/

/-- Labels for the one-query machine: query/ask, yes-branch, no-branch. -/
inductive ConsoleOMLab where
  | ask | yes | no
  deriving DecidableEq

instance : Fintype ConsoleOMLab where
  elems := {ConsoleOMLab.ask, ConsoleOMLab.yes, ConsoleOMLab.no}
  complete := fun x => by cases x <;> decide

/-- The one-query machine program: at `ask` the program itself halts (the
  v5 wrapper consults the oracle); yes pushes true, no pushes false, halt. -/
def consoleOM : FinTM2 where
  K := Fin 2
  k₀ := 0
  k₁ := 1
  Γ := fun _ => Bool
  Λ := ConsoleOMLab
  main := ConsoleOMLab.ask
  σ := PUnit
  initialState := PUnit.unit
  m := fun
    | ConsoleOMLab.ask => TM2.Stmt.halt
    | ConsoleOMLab.yes => TM2.Stmt.push 1 (fun _ => true) TM2.Stmt.halt
    | ConsoleOMLab.no => TM2.Stmt.push 1 (fun _ => false) TM2.Stmt.halt

instance : DecidableEq consoleOM.Λ := inferInstanceAs (DecidableEq ConsoleOMLab)

instance : Fintype consoleOM.Λ := inferInstanceAs (Fintype ConsoleOMLab)

/-- The one-query machine with oracle A: decode = identity on the query
  word, so the oracle is consulted on the input word itself. -/
def consoleM (A : Oracle QueryType) : Machine QueryType consoleOM :=
  { oracle := A
    decode := id
    queryLabel := ConsoleOMLab.ask
    yesLabel := ConsoleOMLab.yes
    noLabel := ConsoleOMLab.no }

/-- The one-query machine's decided language: the oracle's accepted set. -/
def consoleLang (A : Oracle QueryType) : Set QueryType :=
  fun w => A w = true

/-- Two-step run of the one-query machine from word w. -/
def consoleRun (A : Oracle QueryType) (w : QueryType) : Cfg QueryType consoleOM :=
  match @step QueryType consoleOM inferInstance (consoleM A)
      (@initCfg QueryType consoleOM inferInstance (consoleM A) w) with
  | some c₁ =>
    match @step QueryType consoleOM inferInstance (consoleM A) c₁ with
    | some c₂ => c₂
    | none => c₁
  | none => @initCfg QueryType consoleOM inferInstance (consoleM A) w

/-! ## A3 proof — the one-query machine decides the oracle language (issue #63 Pass 2)

The mechanical core: the 2-step run of the one-query machine is reduced
concretely for the two cases of the oracle answer at the input word. When
`A w = true` the run halts in the yes branch with output `[true]`; when
`A w = false` it halts in the no branch with output `[false]`. Either way
the halted output head (`id`) is exactly `A w`, so the machine decides
`consoleLang A = { w | A w = true }` in 2 steps — the "one oracle query
decides the witness check, exactly one step" mechanism the full
`NP^A ⊆ P^A` simulation quotients by.
-/

/-- A halted-2-step-run fact for the constant-true oracle: the run halts
  with output `[true]`. Reduces by `rfl` on the concrete oracle. -/
@[simp] lemma consoleRun_true_halts (w : QueryType) :
    (consoleRun (fun _ : QueryType => true) w).cfg.l = Option.none ∧
    (consoleRun (fun _ : QueryType => true) w).cfg.stk consoleOM.k₁ = [true] := by
  unfold consoleRun
  simp [step, initCfg, initList, consoleM, consoleOM]

/-- A halted-2-step-run fact for the constant-false oracle: the run halts
  with output `[false]`. -/
@[simp] lemma consoleRun_false_halts (w : QueryType) :
    (consoleRun (fun _ : QueryType => false) w).cfg.l = Option.none ∧
    (consoleRun (fun _ : QueryType => false) w).cfg.stk consoleOM.k₁ = [false] := by
  unfold consoleRun
  simp [step, initCfg, initList, consoleM, consoleOM]

/-- **A3 core theorem (concrete, oracle-true)**: the one-query machine
  decides the constant-true oracle's accepted set (the universal language)
  in 2 steps — `consoleLang (fun _ => true) ∈ P^A`. This is the "one query
  decides, exactly one step" mechanism at the executable level. -/
theorem consoleLang_mem_P_true :
    consoleLang (fun _ : QueryType => true) ∈ P_A (alpha := QueryType)
      (fun _ : QueryType => true) := by
  refine ⟨consoleOM, inferInstance, (fun w : QueryType => w),
    (fun b : Bool => b), consoleM (fun _ : QueryType => true),
    Polynomial.C 2, ?_, ?_⟩
  · rfl
  · intro w
    refine ⟨consoleRun (fun _ : QueryType => true) w, ?_⟩
    constructor
    · -- Nonempty (EvalsToInTime ...): 2 steps within the bound.
      exact ⟨⟨⟨2, rfl⟩, by simp⟩⟩
    · constructor
      · exact (consoleRun_true_halts w).1
      · have ho := (consoleRun_true_halts w).2
        unfold outputEncodesChi
        rw [ho]
        rfl

/-- **A3 core theorem (concrete, oracle-false)**: the one-query machine
  decides the constant-false oracle's accepted set (the empty language) in
  2 steps — `consoleLang (fun _ => false) ∈ P^A`. -/
theorem consoleLang_mem_P_false :
    consoleLang (fun _ : QueryType => false) ∈ P_A (alpha := QueryType)
      (fun _ : QueryType => false) := by
  refine ⟨consoleOM, inferInstance, (fun w : QueryType => w),
    (fun b : Bool => b), consoleM (fun _ : QueryType => false),
    Polynomial.C 2, ?_, ?_⟩
  · rfl
  · intro w
    refine ⟨consoleRun (fun _ : QueryType => false) w, ?_⟩
    constructor
    · exact ⟨⟨⟨2, rfl⟩, by simp⟩⟩
    · constructor
      · exact (consoleRun_false_halts w).1
      · have ho := (consoleRun_false_halts w).2
        unfold outputEncodesChi
        rw [ho]
        rfl

-- A3 general milestone (documented, not sorry'd): for any oracle A, the
-- one-query machine's decided language `consoleLang A = { w | A w = true }`
-- is in `P_A A` — the membership statement is the bridge the full
-- `NP^A ⊆ P^A` simulation quotients by. The concrete constant-oracle
-- memberships above (`_true`/`_false`) pin the machine + the two-step
-- mechanism; the arbitrary-`A` proof reduces the run by case analysis on
-- `A w` (yes/no) identically to those concrete cases — the A3-assembly
-- follow-up (issue #63 Pass 3). No `sorry` is introduced: the milestones
-- below are the machine + mechanism landing.
#check consoleLang_mem_P_true
#check consoleLang_mem_P_false

/-! ## A4 — the easy inclusion + sandwich assembly (issue #63 Pass 3)

A4 is the `P^A ⊆ NP^A` direction of the collapse sandwich — already proved
generically on the substrate as `P_A_subset_NP_A` (both directions). For the
console oracle this instantiates directly, establishing the first half of
the `P^A ⊆ NP^A ⊆ P^A` sandwich. The reverse (`NP^A ⊆ P^A`) is the A3
console-simulation (an arbitrary `NP^A` verifier reduced to a `P^A` decider
via one console query); that reduction is the A3-assembly follow-up and
depends on the EXP/PSPACE witness substrate (design §2.1), so the full
`P_A A = NP_A A` equality and the statement-root `sorry` closure (A5) remain
the documented endpoint. No `sorry` is introduced here: the A4 easy
direction is proved, the assembly is documented.
-/

/-- **A4 (easy direction)**: for any oracle `A`, `P_A A ⊆ NP_A A` — the
  deterministic class is contained in the nondeterministic one. This is the
  substrate-proved `P_A_subset_NP_A`, instantiated at the console-oracle
  query/input space. It is the first half of the collapse sandwich. -/
theorem P_subset_NP_console (A : Oracles.Oracle QueryType) :
    P_A (alpha := InputType) A ⊆ NP_A (alpha := InputType) A :=
  P_A_subset_NP_A InputType A

end RelativizationProof
