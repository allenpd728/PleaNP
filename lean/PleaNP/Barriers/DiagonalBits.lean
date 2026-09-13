import Mathlib

set_option warningAsError true

/-!
# BGS diagonalization D5: the unqueried-string existence

The tournament's "pick an unqueried n-bit string" step: a stage machine
makes fewer than `2^n` queries, so some n-bit string was never queried and
can be added to the separating oracle `B`.

This module is pure combinatorics over `Bits n = Fin n → Bool` (the same
type as `BGSDiagonal.Bits`); no oracle substrate, substrate-free like the
D1 counting module (`DiagonalCounting.lean`).
-/

namespace PleaNP

namespace Barriers

namespace DiagonalBits

/-- `Bits n` has exactly `2^n` elements — the binary strings of length n. -/
lemma card_bits (n : ℕ) : Fintype.card (Fin n → Bool) = 2 ^ n := by
  rw [Fintype.card_fun, Fintype.card_fin, Fintype.card_bool]

/-- A set of n-bit strings with fewer than `2^n` elements misses one:
  the unqueried-string existence for the BGS tournament. -/
lemma exists_mem_not_mem {n : ℕ} (s : Finset (Fin n → Bool))
    (hs : s.card < 2 ^ n) :
    ∃ x : Fin n → Bool, x ∉ s := by
  by_contra hnon
  -- every string is in s, so s is the whole type: card s = 2^n
  push Not at hnon
  have huniv : s = Finset.univ := by
    apply Finset.eq_univ_iff_forall.mpr
    intro x
    simpa using hnon x
  have hcard : s.card = 2 ^ n := by
    rw [huniv]
    exact card_bits n
  omega

/-- The pigeonhole corollary for the tournament: at most `p(n)` queries from
  a pool of size `2^n` leave an unqueried string when `p(n) < 2^n`. -/
lemma exists_unqueried {n : ℕ} (s : Finset (Fin n → Bool))
    (hs : s.card < 2 ^ n) :
    ∃ x : Fin n → Bool, x ∉ s :=
  exists_mem_not_mem s hs

end DiagonalBits

end Barriers

end PleaNP