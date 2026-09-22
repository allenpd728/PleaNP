import Mathlib
import PleaNP.Barriers.BGSDiagonal
import PleaNP.Barriers.DiagonalBits
import PleaNP.Barriers.DiagonalStages

set_option warningAsError true

/-!
# BGS diagonalization D5 assembly: the tournament step

Ties the combinatorial core together for the BGS clause-(b) tournament:

- `DiagonalCounting` (D1): `2^n` beats any polynomial — so a poly-time
  stage machine queries strictly fewer than `2^n` length-n strings.
- `DiagonalBits` (D5): a query set of size `< 2^n` leaves an **unqueried**
  string `x : Bits n`.
- `DiagonalStages` (D4): the monotone stage construction — we can ADD `x`
  to the oracle without undoing earlier stages.

This file proves the tournament *flip*: after the monotone add of an
unqueried string `x`, the unary language `U_B` gains `n` (`U_B` becomes
true at length n) because `x` is now a witness — while the stage machine
that never queried `x` cannot change its answer. That is the
"accepts -> leave empty; rejects -> add an unqueried string" step.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalTournament

open PleaNP.Oracles
open PleaNP.Barriers.BGSDiagonal

/-- The oracle that extends `B` by declaring `q₀` to be in the set: only
  `q₀` (and whatever was already in `B`) answers true. This is the
  "add exactly one string" tournament step. -/
def addPoint (B : Oracle Query) (q₀ : Query) : Oracle Query :=
  fun q => if q = q₀ then true else B q

/-- Adding a point never removes membership (monotone in the set sense). -/
lemma addPoint_mono (B : Oracle Query) (q₀ : Query) (q : Query)
    (h : B q = true) : addPoint B q₀ q = true := by
  by_cases hq : q = q₀ <;> simp [addPoint, hq, h]

/-- After adding `⟨n, x⟩`, the string `x` is a witness for `U_B` at length
  n: `n ∈ U_B (addPoint B ⟨n, x⟩)`. This is the tournament's "reject ->
  add an unqueried string" outcome. -/
lemma U_B_add_witness (B : Oracle Query) (n : Nat) (x : Bits n) :
    n ∈ U_B (addPoint B ⟨n, x⟩) := by
  unfold U_B
  refine ⟨x, ?_⟩
  simp [addPoint]

/-- The flip: if NO length-n string was in `B` (the strong reject side),
  then `U_B` was false at n and adding an unqueried string `x` makes it
  true. The premise `∀ x, B ⟨n, x⟩ = false` is load-bearing: it is exactly
  the tournament's "machine ran with all-false answers" stage state. -/
lemma U_B_flip_on_add (B : Oracle Query) (n : Nat) (x : Bits n)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false) :
    n ∉ U_B B ∧ n ∈ U_B (addPoint B ⟨n, x⟩) := by
  constructor
  · intro h
    rcases h with ⟨y, hy⟩
    simp [hB y] at hy
  · exact U_B_add_witness B n x

/-- The empty-oracle start: before any diagonalization, `U_∅` has no
  length-n witness (all-false oracle => no string is in the set). This is
  the base stage the tournament needs. -/
lemma U_empty_false (n : Nat) : n ∉ U_B (emptyOracle Query) := by
  intro h
  rcases h with ⟨x, hx⟩
  simp [emptyOracle] at hx

/-- Stage-machine agreement under the add: a machine that never queried
  `x` sees the same oracle answer before and after adding `x`. Here we
  state the oracle-level agreement: for every query OTHER than `⟨n, x⟩`,
  `addPoint` agrees with `B`. This is what lets the tournament claim the
  stage machine's behavior is unchanged by the add. -/
lemma addPoint_agree_other (B : Oracle Query) (n : Nat) (x : Bits n)
    (q : Query) (hq : q ≠ ⟨n, x⟩) : addPoint B ⟨n, x⟩ q = B q := by
  simp [addPoint, hq]

/-- The tournament decision in one lemma (reject side): if the stage
  machine's queries at length n are all answered "no" (so `B` is all-false
  on length n — the strong all-no stage state) and the query set `s` has
  fewer than `2^n` elements, then some length-n string `x` was never
  queried, and adding it flips `U_B` from false to true at n. This is the
  D1 (2^n > poly) + D5 (unqueried exists) + D4 (monotone add) + U_B
  assembly of the diagonalization. -/
lemma tournament_flip {n : Nat} (s : Finset (Bits n))
    (hs : s.card < 2 ^ n) (B : Oracle Query)
    (hB : ∀ y : Bits n, B ⟨n, y⟩ = false) :
    ∃ x : Bits n, x ∉ s ∧ n ∉ U_B B ∧ n ∈ U_B (addPoint B ⟨n, x⟩) := by
  obtain ⟨x, hxnin⟩ := DiagonalBits.exists_unqueried s hs
  have hflip := U_B_flip_on_add B n x hB
  refine ⟨x, hxnin, hflip.1, hflip.2⟩

/-- The tournament's oracle built as a stage chain: start from `B` and add the
  chosen query at each stage. Because `addPoint` only ever turns a point true,
  the chain is monotone in D4's sense — this instantiates `DiagonalStages`'s
  abstract invariant on the actual D5 tournament step, which is the missing
  link between the two modules. -/
def addChain (B : Oracle Query) (xs : Nat → Query) : Nat → Oracle Query
  | 0 => B
  | k + 1 => addPoint (addChain B xs k) (xs k)

/-- The `addPoint` chain is monotone: nothing added is ever removed. -/
lemma addChain_monotone (B : Oracle Query) (xs : Nat → Query) :
    DiagonalStages.MonotoneChain (addChain B xs) := by
  intro k q hq
  exact addPoint_mono (addChain B xs k) (xs k) q hq

/-- Once `U_B` holds at `n` in some stage of the chain, it holds in every
  later stage — the diagonalization is not undone by later stages. Directly
  produces the separating oracle's consistency invariant: each stage's witness
  survives to the limit. -/
lemma U_B_persists (B : Oracle Query) (xs : Nat → Query) {k j : Nat}
    (hkj : k ≤ j) {n : Nat} (h : n ∈ U_B (addChain B xs k)) :
    n ∈ U_B (addChain B xs j) := by
  obtain ⟨x, hx⟩ := h
  exact ⟨x, DiagonalStages.mem_preserved (addChain_monotone B xs) k hkj ⟨n, x⟩ hx⟩

end DiagonalTournament

end Barriers

end PleaNP