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

end RelativizationProof

end Barriers

end PleaNP
