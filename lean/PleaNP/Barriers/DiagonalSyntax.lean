import PleaNP.Computability.OracleComplexity
import Mathlib.Logic.Equiv.Basic

set_option warningAsError true

/-!
# BGS (b): the machine-syntax factorization (issue #118)

The documented obstruction to closing BGS clause (b) lives in
`DiagonalBridge.lean` (SORRY_TRACKER #12): "the oracle function space
`Oracle Q = Q → Bool` is NOT countable when `Q` is infinite, hence the raw
`Machine Q tm` type is not countable either, hence a faithful `Machine → Code`
compiler is IMPOSSIBLE and the 'detect P or punt' reduction is REQUIRED."

**That analysis is misplaced for the statement the tournament needs.** The
witnesses of `P_A A` / `NP_A A` carry the oracle as a *pinned equation*
(`M.oracle = A` is an explicit conjunct of the class definitions in
`OracleComplexity.lean`), not as a free field. So when the diagonalization
quantifies over "every poly-time oracle machine with oracle `B`" — exactly what
`U_B ∉ P_A B` means — the oracle is **not** a degree of freedom, and its
uncountability cannot be the obstruction to enumerating those witnesses.

This module makes the corrected picture machine-checked:

- `MachineSyntax tm` — the machine's finite *program* part (its three labels),
  with a `Fintype` instance, so "the machine's code is finite data" is a
  theorem rather than prose.
- `machineEquiv` — a proved factorization
  `Machine Q tm ≃ MachineSyntax tm × Oracle Q × (List (Γ k₀) → Q)`, which
  *localizes* the uncountability in the `oracle`/`decode` factors instead of
  leaving it as an assertion about the whole type.
- `mem_P_A_oracle_pinned` / `mem_NP_A_oracle_pinned` — the oracle-pinned
  extraction lemmas: a `P_A`/`NP_A` witness comes with `M.oracle = A`, so the
  oracle factor of the factorization is fixed by the class, not enumerated.

## What remains (the real, routine task)

The witnesses' genuine degrees of freedom are `tm' : FinTM2` (whose fields
include *types* — `Λ`, `σ`, `K`, `Γ` — so it is not a set to enumerate), plus
`decode`, `ea`, `oa` and the three labels. Enumerating those requires the
standard modeling step: **fix a concrete machine family** (finite `Λ`/`σ`/`K`/`Γ`)
and a canonical `decode`, then enumerate programs. That is a modeling choice
with a routine resolution — not a mathematical impossibility, and "punt slow
codes" is one option among several rather than a requirement.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalSyntax

open PleaNP.Oracles Turing

/-- `FinTM2`'s label type is finite — it is a bundled instance field
  (`tm.ΛFin`). Mathlib exposes the bundled `Fintype K`/`Inhabited σ` for a
  variable `tm` but not this one, so the diagonalization's enumeration needs it
  re-exported. Declared before `MachineSyntax` so the `deriving` can use it. -/
instance (tm : FinTM2) : Fintype tm.Λ := tm.ΛFin

/-- The finite *program* part of an oracle machine: its three distinguished
  labels. This is the machine's "code" in the sense the diagonalization
  enumerates — the part that is genuinely finite data. -/
structure MachineSyntax (tm : FinTM2) where
  queryLabel : tm.Λ
  yesLabel : tm.Λ
  noLabel : tm.Λ

/-- The syntax type is definitionally a triple of labels; this equivalence lets
  the finiteness instance be *transported* from the product type (a `deriving
  Fintype` needs more than the product's instances give for a variable `tm`). -/
def machineSyntaxEquiv (tm : FinTM2) :
    MachineSyntax tm ≃ tm.Λ × tm.Λ × tm.Λ where
  toFun s := (s.queryLabel, s.yesLabel, s.noLabel)
  invFun t := ⟨t.1, t.2.1, t.2.2⟩
  left_inv s := by cases s; rfl
  right_inv t := by rcases t with ⟨a, b, c⟩; rfl

/-- The machine's syntax is finite: a triple of labels, and `tm.Λ` is finite.
  This is the machine-checked form of "a machine program is finite data" — the
  fact the doc-of-record needed and lacked. -/
instance (tm : FinTM2) : Fintype (MachineSyntax tm) :=
  Fintype.ofEquiv (tm.Λ × tm.Λ × tm.Λ) (machineSyntaxEquiv tm).symm

/-- The machine's syntax of a concrete machine. -/
def machineSyntaxOf {Q : Type} {tm : FinTM2} [DecidableEq tm.Λ]
    (M : Machine Q tm) : MachineSyntax tm :=
  ⟨M.queryLabel, M.yesLabel, M.noLabel⟩

/-- **The syntax factorization.** A machine is exactly: a finite label triple,
  an oracle, and a decode function. The `oracle` and `decode` factors are where
  the (possibly uncountable) content lives; the syntax factor is finite.

  This is the precise statement the doc-of-record was missing: the
  uncountability is a property of the `oracle`/`decode` factors, not of the
  machines that `P_A A` quantifies over (those pin `oracle` to `A`). -/
def machineEquiv (Q : Type) (tm : FinTM2) [DecidableEq tm.Λ] :
    Machine Q tm ≃ MachineSyntax tm × Oracle Q × (List (tm.Γ tm.k₀) → Q) where
  toFun M := (machineSyntaxOf M, M.oracle, M.decode)
  invFun t := ⟨t.2.1, t.2.2, t.1.queryLabel, t.1.yesLabel, t.1.noLabel⟩
  left_inv M := by cases M; rfl
  right_inv t := by rcases t with ⟨⟨ql, yl, nl⟩, o, d⟩; rfl

/-- **Oracle-pinned extraction (`P_A`).** A witness of `L ∈ P_A A` comes with
  `M.oracle = A`: the oracle is fixed by the class, so it is not a free
  variable in the diagonalization's enumeration. (Direct from the conjunct in
  `P_A`'s definition — recorded as a named lemma so the diagonalization can
  cite it.) -/
theorem mem_P_A_oracle_pinned {Q alpha : Type} {A : Oracle Q} {L : Set alpha}
    (h : L ∈ P_A A) :
    ∃ (tm' : FinTM2) (hh : DecidableEq tm'.Λ)
      (ea : alpha → List (tm'.Γ tm'.k₀)) (oa : tm'.Γ tm'.k₁ → Bool)
      (M : @Machine Q tm' hh) (p : Polynomial ℕ),
      M.oracle = A ∧ @DecidesInTime Q tm' alpha hh ea oa M L (fun n => p.eval n) := h

/-- **Oracle-pinned extraction (`NP_A`).** Same for the nondeterministic
  class: each per-input witness carries `M.oracle = A`. -/
theorem mem_NP_A_oracle_pinned {Q alpha : Type} {A : Oracle Q} {L : Set alpha}
    (h : L ∈ NP_A A) :
    ∃ (tm' : FinTM2) (hh : DecidableEq tm'.Λ)
      (ea : alpha × List alpha → List (tm'.Γ tm'.k₀))
      (oa : tm'.Γ tm'.k₁ → Bool)
      (M : @Machine Q tm' hh) (p : Polynomial ℕ),
      ∀ x : alpha,
        x ∈ L ↔ ∃ y : List alpha,
          y.length ≤ p.eval (ea (x, [])).length
          ∧ M.oracle = A
          ∧ @AcceptsInTime Q tm' (alpha × List alpha) hh ea oa M (x, y) (fun n => p.eval n) := h

/-- The factorization at a concrete machine: a machine decomposes into its
  finite syntax, its oracle, and its decode — the recorded form of "the
  uncountable content sits in the oracle/decode factors, not the program". -/
example (Q : Type) (tm : FinTM2) [DecidableEq tm.Λ] (M : Machine Q tm) :
    (machineEquiv Q tm) M = (machineSyntaxOf M, M.oracle, M.decode) := rfl

end DiagonalSyntax

end Barriers

end PleaNP
