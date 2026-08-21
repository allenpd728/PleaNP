import PleaNP.Computability.Oracle
import Mathlib.Computability.TuringMachine.Computable
import Mathlib.Algebra.Polynomial.Basic
set_option warningAsError true

/-!
# Oracle complexity classes (P^A / NP^A) v4

v4 repair (refined in the v4-completion pass): the class parameter
A : Oracle Q must be tied to each machine's query alphabet. Machines
quantify with hΓ : tm'.Γ tm'.k₀ = Q, and the constraint is
M.oracle = hΓ.symm ▸ A. (The v4 headers' bare `M.oracle = A` did not
even typecheck — the build was never green past the substrate sorry,
so the mismatch was unobservable.)

Closes Flaw C with reachability-wired AcceptsInTime applied to (x, y).

v4 completion: P_A_subset_NP_A proved in both directions. Backward
uses determinism (`evalsTo_unique_result`): the halted endpoint of
AcceptsInTime equals that of DecidesInTime on the same input, so the
output bit transfers.
-/

namespace PleaNP

namespace Oracles

open Turing

/-- P^A: languages decidable by a deterministic oracle machine for A
  in polynomial time. `hΓ` ties the machine's query alphabet to Q;
  `M.oracle = hΓ.symm ▸ A` makes the class relative to A. -/
def P_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | ∃ (tm' : FinTM2) (hΓ : tm'.Γ tm'.k₀ = Q) (h : DecidableEq tm'.Λ)
        (ea : alpha → List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ → Bool)
        (M : @Machine (tm'.Γ tm'.k₀) tm' h) (p : Polynomial ℕ),
      M.oracle = hΓ.symm ▸ A ∧ @DecidesInTime tm' alpha h ea oa M L (fun n => p.eval n) }

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
  Certificate y appears in the acceptance conjunct via AcceptsInTime
  on the pair (x, y) -- not x alone. Same hΓ oracle constraint as P_A. -/
def NP_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | ∃ (tm' : FinTM2) (hΓ : tm'.Γ tm'.k₀ = Q) (h : DecidableEq tm'.Λ)
        (ea : alpha × List alpha → List (tm'.Γ tm'.k₀))
        (oa : tm'.Γ tm'.k₁ → Bool)
        (M : @Machine (tm'.Γ tm'.k₀) tm' h) (p : Polynomial ℕ),
      ∀ x : alpha,
        x ∈ L ↔ ∃ y : List alpha,
          y.length ≤ p.eval (ea (x, [])).length
          ∧ M.oracle = hΓ.symm ▸ A
          ∧ @AcceptsInTime tm' (alpha × List alpha) h ea oa M (x, y) (fun n => p.eval n) }

/-- P^A ⊆ NP^A: a decider is a verifier with empty certificate.
  Structural self-check, proved in both directions.

  Forward: the decider's halted endpoint satisfies outputEncodesChi,
  so with x ∈ L the output bit is true — same endpoint, same
  reachability, empty certificate.

  Backward: the accept-run and the decide-run start from the same
  initial config (the pair-encoding ignores the certificate), so by
  determinism (evalsTo_unique_result) they halt at the same endpoint;
  the accept-run's true output bit transfers to outputEncodesChi,
  which yields x ∈ L. -/
theorem P_A_subset_NP_A {Q : Type} (alpha : Type) (A : Oracle Q) :
    P_A (alpha := alpha) A ⊆ NP_A (alpha := alpha) A := by
  rintro L ⟨tm', hΓ, h, ea, oa, M, p, hM, hDecides⟩
  refine ⟨tm', hΓ, h, fun xy => ea xy.1, oa, M, p, ?_⟩
  intro x
  constructor
  · -- (→): x ∈ L → ∃ y, bounded certificate, M accepts (x, y)
    intro hx
    refine ⟨[], Nat.zero_le _, hM, ?_⟩
    obtain ⟨cfg', hReach, hHalt, hEncodes⟩ := hDecides x
    refine ⟨cfg', hReach, hHalt, ?_⟩
    unfold outputEncodesChi at hEncodes
    by_cases hStk : cfg'.cfg.stk tm'.k₁ = []
    · rw [hStk] at hEncodes
      exact False.elim hEncodes
    · obtain ⟨head, tail, hStk'⟩ := List.exists_cons_of_ne_nil hStk
      rw [hStk'] at hEncodes
      have hTrue : oa head = true := hEncodes.2 hx
      rw [hStk']
      exact hTrue
  · -- (←): ∃ y, M accepts (x, y) → x ∈ L
    intro ⟨y, _hbound, _hM₂, hAccepts⟩
    obtain ⟨cfg', hReach, hHalt, hOutput⟩ := hAccepts
    obtain ⟨cfgL', hReachL, hHaltL, hEncodesL⟩ := hDecides x
    -- Both runs start from the same initial config (ea (x, y) = ea x
    -- under the pair-encoding) and halt, so determinism gives cfg' = cfgL'.
    have hEq : cfg' = cfgL' :=
      evalsTo_unique_result
        (step_none M cfg' hHalt) (step_none M cfgL' hHaltL)
        hReach.some.toEvalsTo hReachL.some.toEvalsTo
    rw [hEq] at hOutput
    unfold outputEncodesChi at hEncodesL
    by_cases hStk : cfgL'.cfg.stk tm'.k₁ = []
    · rw [hStk] at hOutput
      exact False.elim hOutput
    · obtain ⟨head, tail, hStk'⟩ := List.exists_cons_of_ne_nil hStk
      rw [hStk'] at hOutput hEncodesL
      exact hEncodesL.1 hOutput

end Oracles

end PleaNP
