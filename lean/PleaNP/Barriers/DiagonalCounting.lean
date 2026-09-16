import Mathlib

set_option warningAsError true

/-!
# BGS diagonalization D1: counting lemma

`poly_lt_two_pow`: for every polynomial `p : Polynomial ℕ`, there is an
`n` with `p.eval n < 2 ^ n`. This fuels the BGS tournament's
"unqueried n-bit string exists" step.

Pure arithmetic — no oracle substrate involved,so this module stays
substrate-free.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalCounting

/-- `2 ^ n` is unbounded above: any fixed `c` is eventually below it. -/
lemma exists_lt_two_pow (c : ℕ) : ∃ n, c < 2 ^ n :=
  ⟨c, Nat.lt_pow_self (by norm_num : (1 : ℕ) < 2)⟩

/-- `K.factorial * n.choose K` is eventually bounded by `2 ^ (n + 1 + t)`;
  the shift `t` absorbs the fixed factorial constant. -/
lemma choose_mul_factorial_le_two_pow (K : ℕ) : ∃ t : ℕ, ∀ n : ℕ,
    K.factorial * n.choose K ≤ 2 ^ (n + 1 + t) := by
  obtain ⟨t, ht⟩ := exists_lt_two_pow K.factorial
  refine ⟨t, fun n => ?_⟩
  calc
    K.factorial * n.choose K ≤ K.factorial * 2 ^ n := Nat.mul_le_mul_left K.factorial (Nat.choose_le_two_pow n K)
    _ ≤ (2 ^ t) * (2 ^ n) := Nat.mul_le_mul_right (2 ^ n) ht.le
    _ = 2 ^ (t + n) := by rw [← Nat.pow_add]
    _ ≤ 2 ^ (n + 1 + t) := pow_le_pow_right₀ (by norm_num) (by omega)

/-- `(n+K) ^ K ≤ 2 ^ (n + K + 1 + t)`: the shift `t` absorbs all
  constants (via `choose`, the descending factorial, and `2^n`). -/
lemma pow_add_le_two_pow_shift (K : ℕ) : ∃ t : ℕ, ∀ n : ℕ,
    (n + K) ^ K ≤ 2 ^ (n + K + 1 + t) := by
  obtain ⟨t₁, ht₁⟩ := choose_mul_factorial_le_two_pow K
  refine ⟨K + t₁, fun n => ?_⟩
  calc
    (n + K) ^ K ≤ (n + K + 1) ^ K :=
      pow_le_pow_left₀ (by omega) (by omega) K
    _ = ((n + 2 * K) + 1 - K) ^ K := by
      congr 1
      omega
    _ ≤ (n + 2 * K).descFactorial K := Nat.pow_sub_le_descFactorial (n + 2 * K) K
    _ = K.factorial * (n + 2 * K).choose K := (Nat.descFactorial_eq_factorial_mul_choose (n + 2 * K) K)
    _ ≤ 2 ^ ((n + 2 * K) + 1 + t₁) := ht₁ (n + 2 * K)
    _ = 2 ^ (n + K + 1 + (K + t₁)) := by
      congr 1
      omega

/-- `c * n ^ d < 2 ^ n` for all sufficiently large `n` — exponential beats
  fixed-coefficient polynomials. -/
lemma poly_bound_lt_two_pow (c d : ℕ) : ∃ N : ℕ, ∀ n : ℕ, n ≥ N → c * n ^ d < 2 ^ n := by
  induction d with
  | zero =>
      obtain ⟨N₀, hN₀⟩ := exists_lt_two_pow c
      refine ⟨N₀, fun n hn => ?_⟩
      calc
        c * n ^ 0 = c := by simp
        _ < 2 ^ N₀ := hN₀
        _ ≤ 2 ^ n := pow_le_pow_right₀ (by norm_num) hn
  | succ d ih =>
      let J := d + 1
      let K := J + 1
      obtain ⟨t, ht⟩ := pow_add_le_two_pow_shift K
      let N₁ := max (K + 2 + t) (c * 2 ^ J)
      refine ⟨N₁ + K + 1 + t, fun n hn => ?_⟩
      let m := n - (K + 1 + t)
      have hmN₁ : N₁ ≤ m := by
        dsimp [m]
        omega
      have hmbig : K + 1 + t < m := by
        -- N₁ ≥ K+2+t and m ≥ N₁, so K+1+t < m
        dsimp [m]
        omega
      have hmc : c * 2 ^ J ≤ m := le_trans (le_max_right _ _) hmN₁
      have hn_eq : m + K + 1 + t = n := by
        dsimp [m]
        omega
      have hchoose : (m + K) ^ K ≤ 2 ^ (m + K + 1 + t) := ht m
      by_cases hc : c = 0
      · -- c = 0: trivial
        simp [hc]
      · -- c > 0
        have hcpos : 0 < c := Nat.pos_of_ne_zero hc
        have hm2 : m + K + 1 + t < 2 * m := by omega
        calc
          c * n ^ (d + 1) = c * (m + K + 1 + t) ^ (d + 1) := by rw [hn_eq]
          _ = c * (m + K + 1 + t) ^ J := by
            simp [J]
          _ < c * (2 * m) ^ J := by
            exact (Nat.mul_lt_mul_of_pos_left (Nat.pow_lt_pow_left hm2 (by omega)) hcpos)
          _ = (c * 2 ^ J) * m ^ J := by
            rw [Nat.mul_pow, Nat.mul_assoc]
          _ ≤ m * m ^ J := Nat.mul_le_mul_right (m ^ J) hmc
          _ = m ^ (J + 1) := by rw [← Nat.pow_succ']
          _ = m ^ K := by
            rfl
          _ ≤ (m + K) ^ K := pow_le_pow_left₀ (by omega) (by omega) K
          _ ≤ 2 ^ (m + K + 1 + t) := hchoose
          _ = 2 ^ n := by rw [hn_eq]

/-- The BGS D1 counting lemma. -/
theorem poly_lt_two_pow (p : Polynomial ℕ) : ∃ n, p.eval n < 2 ^ n := by
  let d := p.natDegree
  let C := ∑ i ∈ Finset.range (d + 1), p.coeff i
  obtain ⟨N₀, hN₀⟩ := poly_bound_lt_two_pow C d
  refine ⟨max N₀ 1, ?_⟩
  calc
    p.eval (max N₀ 1) = ∑ i ∈ Finset.range (p.natDegree + 1), p.coeff i * (max N₀ 1) ^ i := (Polynomial.eval_eq_sum_range (max N₀ 1))
    _ = ∑ i ∈ Finset.range (d + 1), p.coeff i * (max N₀ 1) ^ i := by
      congr 1
    _ ≤ ∑ i ∈ Finset.range (d + 1), p.coeff i * (max N₀ 1) ^ d := Finset.sum_le_sum (by
        intro i hi
        have hi' : i ≤ d := Nat.lt_succ_iff.mp (Finset.mem_range.mp hi)
        exact Nat.mul_le_mul_left (p.coeff i) (pow_le_pow_right₀ (by omega) hi'))
    _ = C * (max N₀ 1) ^ d := by
      dsimp [C]
      rw [← Finset.sum_mul]
    _ < 2 ^ (max N₀ 1) := hN₀ (max N₀ 1) (le_max_left N₀ 1)
