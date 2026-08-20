import PleaNP.Computability.Oracle
import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Algebra.Polynomial.Basic
set_option warningAsError true

/-!
# Oracle complexity classes (P^A / NP^A) v4

v4 repair: closes Flaw C by wiring AcceptsInTime with reachability
and applying it to the pair (x, y). Adds M.oracle = A constraint.
Removes duplicate binder in P_A_subset_NP_A.
-/

namespace PleaNP

namespace Oracles

open Turing

/-- P^A: languages decidable by a deterministic oracle machine for A
  in polynomial time. M.oracle = A ensures the class is relative to A. -/
def P_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | ∃ (tm' : FinTM2) (h : DecidableEq tm'.Λ)
        (ea : alpha → List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ → Bool)
        (M : @Machine (tm'.Γ tm'.k₀) tm' h) (hM : M.oracle = A) (p : Polynomial ℕ),
      hM ∧ @DecidesInTime tm' alpha h ea oa M L (fun n => p.eval n) }

/-- Per-input acceptance: M started on ea xy reaches a halted config
  within t(|ea xy|) steps AND outputs true (accept).
  v4 fix: ea, M, xy, t are ALL load-bearing via EvalsToInTime. -/
def AcceptsInTime {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha → List (tm.Γ tm.k₀))
    (oa : tm.Γ tm.k₁ → Bool)
    (M : Machine (tm.Γ tm.k₀) tm) (xy : alpha) (t : Nat → Nat) : Prop :=
  ∃ cfg' : Cfg (tm.Γ tm.k₀) tm,
    Nonempty (StateTransition.EvalsToInTime (step M) (initCfg M (ea xy)) (some cfg') (t (ea xy).length))
    ∧ cfg'.cfg.l = Option.none
    ∧ (match cfg'.cfg.stk tm.k₁ with
           | [] => False
           | head :: _ => oa head = true)

/-- NP^A: languages with a polynomial-time verifier relative to A.
  M.oracle = A. Certificate y appears in the acceptance conjunct via
  AcceptsInTime on the pair (x, y) -- not x alone. -/
def NP_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | ∃ (tm' : FinTM2) (h : DecidableEq tm'.Λ)
        (ea : alpha × List alpha → List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ → Bool)
        (M : @Machine (tm'.Γ tm'.k₀) tm' h) (hM : M.oracle = A) (p : Polynomial ℕ),
      ∀ x : alpha,
        x ∈ L ↔ ∃ y : List alpha,
          y.length ≤ p.eval (ea (x, [])).length
          ∧ hM ∧ @AcceptsInTime tm' (alpha × List alpha) h ea oa M (x, y) (fun n => p.eval n) }

/-- P^A ⊆ NP^A: a decider is a verifier with empty certificate.
  Structural self-check. -/
theorem P_A_subset_NP_A {Q : Type} (alpha : Type) (A : Oracle Q) :
    P_A (alpha := alpha) A ⊆ NP_A (alpha := alpha) A := by
  rintro L ⟨tm', h, ea, oa, M, hM, p, hDecides⟩
  -- Use the same machine, with pair-encoding ea'(x,y) = ea(x)
  refine ⟨tm', h, fun xy => ea xy.1, oa, M, hM, p, ?⟩
  intro x
  constructor
  · -- (rightarrow): x ∈ L → ∃ y, AcceptsInTime on (x, y)
    intro hx
    -- Take empty certificate y = []
    refine ⟨[], ?⟩
    refine ⟨?_, ?⟩
    · -- Certificate bound: |[]| = 0 ≤ p.eval (ea (x, [])).length
      simp
    · -- AcceptsInTime on (x, []) follows from DecidesInTime on L
      obtain ⟨cfg', hReach, hHalt, hEncodes⟩ := hDecides x
      refine ⟨cfg', ?_, hHalt, ?_⟩
      · -- Reachability: same initial config (ea(x,[]) = ea(x))
        exact hReach
      · -- Output is true: from outputEncodesChi, oa head = true ↔ x ∈ L
        -- Since x ∈ L, oa head = true
        unfold outputEncodesChi at hEncodes
        sorry
  · -- (leftarrow): ∃ y, AcceptsInTime → x ∈ L
    intro ⟨y, _hy, hAccepts⟩
    obtain ⟨cfg', hReach, hHalt, hOutput⟩ := hAccepts
    obtain ⟨cfgL', hReachL, hHaltL, hEncodesL⟩ := hDecides x
    sorry

/-- P^∅ = P compatibility (statement, proof pending upstream P). -/
theorem P_empty_eq_upstream_P_class {Q : Type} (alpha : Type) :
    P_A (alpha := alpha) (emptyOracle Q) =
    { L | sorry } := by
  sorry

end Oracles

end PleaNP
