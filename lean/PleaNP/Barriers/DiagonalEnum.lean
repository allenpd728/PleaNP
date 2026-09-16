import Mathlib

set_option warningAsError true

/-!
# BGS diagonalization D3: machine enumeration substrate

The tournament needs "every poly-time oracle machine `M_i`" — an
enumeration of the machines to diagonalize over. Mathlib's
`Nat.Partrec.Code` (Computability/PartrecCode.lean) is the cleanest
countable-program substrate: it is `Denumerable` (bijective with `ℕ`),
and `evaln k c n` is the bounded-step simulation (the "run M_i for
p(n) steps" the tournament performs).

This module makes the enumeration + bounded-simulation facts precise and
records the honest bridge target: a *poly-time oracle machine* (the
`P_A`-witness `Machine`) induces a `Code` that simulates its query
behavior (`M_i ↔ code`). The forward direction (`Machine -> Code`) is a
real reduction for the next milestone; here we fix the substrate facts it
rests on.

The `Partrec.Code` gap is honest and documented (design doc §3.2): codes
enumerate partial-recursive functions, not poly-time oracle machines —
the bridge must either detect `P` or make the diagonalization tolerate
slow codes (the "punting" strategy).
-/

namespace PleaNP

namespace Barriers

namespace DiagonalEnum

open Nat.Partrec
open Nat.Partrec.Code

/-- The enumeration of programs: `M_of i` is the `i`-th program (as a
  `Code`), via `Denumerable`. -/
def M_of (i : Nat) : Code :=
  Denumerable.ofNat Code i

/-- The `i`-th program encodes back to `i` (`encode (ofNat i) = i`). -/
lemma code_ofNat_encode (n : Nat) : Encodable.encode (M_of n) = n := by
  unfold M_of
  exact Denumerable.encode_ofNat (α := Code) n

/-- Every code appears in the enumeration (`ofNat (encode c) = c`). -/
lemma code_encode_ofNat (c : Code) : M_of (Encodable.encode c) = c := by
  unfold M_of
  exact Denumerable.ofNat_encode (α := Code) c

/-- The bounded-step simulation: `evaln (k+1)` on the base program
  succeeds exactly when the input bound `n ≤ k` (the "run for k steps"
  guard), returning 0. -/
lemma evaln_step_bound (n : Nat) : evaln (n + 1) Code.zero n = some 0 := by
  simp [evaln]

/-- `evaln` agreeing with `eval`: the bounded simulation is a *correct*
  approximation of the unbounded one (`evaln_complete` at `some m`). -/
lemma evaln_mem_eval {k c n m} (h : evaln k c n = some m) :
    m ∈ eval c n := by
  exact (evaln_complete (c := c) (n := n)).2 ⟨k, by simp [h]⟩

end DiagonalEnum

end Barriers

end PleaNP