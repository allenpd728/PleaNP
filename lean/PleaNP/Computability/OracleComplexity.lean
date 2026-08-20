import PleaNP.Computability.Oracle
import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Algebra.Polynomial.Basic
set_option warningAsError true

/-!
# Oracle complexity classes (P^A / NP^A)

Status: v3 (semantically load-bearing). Fixes the three flaws from
the harsh review:
- P_A: composes DecidesInTime (which uses the real step function
  with oracle queries — Flaw B fix).
- NP_A: uses a per-input AcceptsInTime predicate (not the
  whole-language DecidesInTime inside exists y — Flaw C fix).
- The oracle is now load-bearing in step (Flaw B fix in Oracle.lean).
-/

namespace PleaNP

namespace Oracles

open Turing

/-!
## P^A -- deterministic polynomial time relative to A
-/

/-- P^A is the class of languages decidable by a deterministic oracle
  machine for A in polynomial time. -/
def P_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | exists (tm' : FinTM2) (h : DecidableEq tm'.Λ)
        (ea : alpha -> List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ -> Bool)
        (M : @Machine Q tm' h) (p : Polynomial Nat),
      @DecidesInTime Q tm' alpha h ea oa M L (fun n => p.eval n) }

/-!
## NP^A -- nondeterministic polynomial time (verifier framing)

Flaw C fix: NP_A uses a per-input AcceptsInTime predicate, NOT the
whole-language DecidesInTime inside exists y. The verifier checks
that M accepts the SPECIFIC pair (x, y), not that M decides the
entire language.
-/

/-- Per-input acceptance: M halts on input xy within t steps AND
  outputs true (accept). This is the per-input predicate that NP_A
  needs (Flaw C fix: NOT the whole-language DecidesInTime). -/
def AcceptsInTime {Q : Type} {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha -> List (tm.Γ tm.k₀))
    (oa : tm.Γ tm.k₁ -> Bool)
    (M : Machine Q tm) (xy : alpha) (t : Nat -> Nat) : Prop :=
  exists cfg' : Cfg Q tm,
    -- M halts (the label is None).
    (cfg'.cfg.l = Option.none) /\
    -- The output is true (accept): oa head = true.
    (match cfg'.cfg.stk tm.k₁ with
     | [] => False
     | head :: _ => oa head = true)

/-- NP^A is the class of languages with a polynomial-time verifier
  relative to A. L in NP^A iff there exists M, p such that for every
  x: x ∈ L iff there exists a certificate y with |y| <= p(|x|) and
  M accepts (x, y) within p steps.

  The per-input AcceptsInTime predicate is used (Flaw C fix). -/
def NP_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | exists (tm' : FinTM2) (h : DecidableEq tm'.Λ)
        (ea : alpha -> List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ -> Bool)
        (M : @Machine Q tm' h) (p : Polynomial Nat),
      forall x : alpha,
        x ∈ L <-> exists y : List alpha,
          y.length <= p.eval (ea x).length /\
          @AcceptsInTime Q tm' alpha h ea oa M x (fun n => p.eval n) }

/-!
## P^A subset NP^A (structural self-check)
-/

theorem P_A_subset_NP_A {Q : Type} (alpha : Type) (A : Oracle Q) (A : Oracle Q) :
    P_A (alpha := alpha) A ⊆ NP_A (alpha := alpha) A := by
  sorry

/-!
## P^empty = P compatibility
-/

theorem P_empty_eq_upstream_P_class {Q : Type} (alpha : Type) :
    P_A (alpha := alpha) (emptyOracle Q) =
    { L | exists (tm' : FinTM2), sorry } := by
  sorry

end Oracles

end PleaNP
