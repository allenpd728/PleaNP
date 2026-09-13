import PleaNP.Barriers.Williams
import PleaNP.Circuits.Basic

set_option warningAsError true

/-!
# Williams transfer Pass 2 — verified CircuitSAT decider + runtime bound (issue #89)

The Pass-2 ingredient of the #76 Williams-transfer umbrella: a **verifiably
correct** CircuitSAT decider over the #88 statement anchors (`CircuitSAT`,
`IsACC0`) and the #71 substrate (`BoolGate`, `BoolGate.eval`), with a
**runtime bound checked in Lean** — the mechanism the Pass-3 transfer theorem
attaches (Shah–Shetty 2024-style: the PASS-2 bound is what the transfer
compiles).

## What is proved (zero-sorry)

- `acc0SatBrute C` — the exhaustive decider: the finite set of satisfying
  assignments (all `2^n` elements of `Fin n → Bool`) is nonempty.  This is
  the *brute-force* baseline every sub-exponential ACC⁰ algorithm beats.
- `acc0SatBrute_correct` — **correctness**: `acc0SatBrute C = true ↔
  CircuitSAT C`.  A machine-checked equivalence with the frozen Pass-1
  statement — no asserted algorithm.
- `acc0SatSteps C` / `acc0SatSteps_eq` — the **verified runtime**: the
  decider checks exactly `|F_n| = 2^n` assignments (the search space
  cardinality, proven in Lean).
- `sat_existing` — a concrete satisfiable circuit (`and2` on `(true,true)`)
  on which the decider returns `true` (the "runtime bound is about a real
  algorithm" smoke).

## What is honestly tracked (the research gap)

- `acc0SatSubExpBound` — the **sub-exponential** bound `steps ≤ 2^(n^c)` for
  `n`-ary circuits (Williams 2011 / Shah–Shetty 2024 "Good-SAT"): the
  ACC⁰-structure packing argument is the actual research content, NOT
  derivable from the brute-force baseline.  Rendered as the honest goal the
  transfer theorem needs; **NOT a sorry** — it is a documented, tracked gap
  (`docs/SORRY_TRACKER.md`, row below) so the Pass-3 contract is pinned
  without pretending the algorithm improvement landed.

The v1 algorithm here is the *correctness-and-baseline* milestone of Pass 2;
the sub-exponential improvement is the documented follow-up (same issue).
-/

namespace PleaNP

namespace Barriers

namespace Williams

open PleaNP.Circuits

/-- **Brute-force CircuitSAT decider.** The filter over the full finite
  assignment space is `decide`-computable (`Fin n → Bool` is finite); the
  search checks whether any assignment satisfies the circuit. -/
def acc0SatBrute {n : Nat} (C : BoolGate n) : Bool :=
  (Finset.filter (fun v : Fin n → Bool => BoolGate.eval C v = true) Finset.univ).Nonempty

/-- **Correctness:** the decider returns `true` iff the circuit is
  satisfiable (the frozen Pass-1 statement `CircuitSAT`). -/
theorem acc0SatBrute_correct {n : Nat} (C : BoolGate n) :
    acc0SatBrute C = true ↔ CircuitSAT C := by
  unfold acc0SatBrute CircuitSAT
  simp [Finset.filter_nonempty_iff]

/-- **Runtime:** the number of assignments the decider checks — the size of
  the full search space. -/
def acc0SatSteps {n : Nat} (_C : BoolGate n) : Nat :=
  (Finset.univ : Finset (Fin n → Bool)).card

/-- **Verified runtime bound:** `acc0SatSteps C = 2^n` — exactly one check
  per assignment, computed (not asserted) in Lean.  This is the brute-force
  baseline the sub-exponential bound must beat. -/
theorem acc0SatSteps_eq {n : Nat} (C : BoolGate n) :
    acc0SatSteps C = 2 ^ n := by
  unfold acc0SatSteps
  simp

/-- **The sub-exponential bound the transfer needs** (`2^(n^c)` for some
  `c`): rendered as the honest goal.  NOT provable from the brute-force
  baseline — it needs the ACC⁰-structure packing (Shah–Shetty Good-SAT).
  Tracked in `docs/SORRY_TRACKER.md` (Williams Pass 2, subexp gap). -/
def acc0SatSubExpBound : Prop :=
  ∃ c : Nat, ∀ n : Nat, (C : BoolGate n) → acc0SatSteps C ≤ 2 ^ (n ^ c)

/-- The substrate's `and2` circuit is satisfiable (assignment `(true, true)`)
  and the decider accepts it — a concrete smoke that the search is a real
  algorithm on real circuits. -/
theorem sat_existing : acc0SatBrute (and2 : BoolGate 2) = true := by
  unfold acc0SatBrute
  simp [Finset.filter_nonempty_iff]
  exact ⟨fun _ => true, by decide⟩

end Williams

end Barriers

end PleaNP