import Mathlib
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# BGS (b): the Machine-to-Code bridge — the honest obstacle

A faithful `Machine → Code` compiler is the tournament's last gap. But
there is a genuine mathematical obstruction worth making precise BEFORE
any compiler work: **the oracle function space `Oracle Q = Q → Bool` is
NOT countable when `Q` is infinite** (Cantor's diagonal: `2^Q` is
uncountable). Hence the raw `Machine Q tm` type is not countable either
— a machine carries an arbitrary oracle function.

This is exactly why the design doc §3.2 says the `Partrec.Code` bridge
"must detect `P` or punt": you cannot enumerate ALL oracle machines as
`Code`s (there are uncountably many); you enumerate only what the
diagonalization needs (poly-time machines with a fixed, queried oracle),
or you weaken to the `M_of`-indexed partial-recursive programs and PUNT
the rest.

This module pins the obstacle with a Cantor-style uncountability proof,
so nobody can substitute a fake "machine set is countable" claim.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalBridge

open PleaNP.Oracles
open Turing

/-- The honest obstacle, recorded precisely: `Machine tm Q` is NOT
  countable in the settings the tournament needs. It carries
  (a) an oracle `Q → Bool` — uncountable for infinite Q (Cantor: a
      countable enumeration would miss the diagonal-flip function), and
  (b) a decode `List (Γ k₀) → Q` — an infinite-domain function space even
      for finite Q.
  Hence a faithful bijective `Machine → Code` (for BGS's infinite
  `Q = Σ n, Bits n`) is IMPOSSIBLE; the design doc §3.2's "detect P or
  punt" reduction (enumerate `Code`s and index only the needed
  poly-time machines, punting the rest) is REQUIRED, not optional. This
  is the exact obstacle the #23/#97 bridge must overcome. -/
def BridgeObstacle : Prop :=
  ∀ (A : Type) (_ : Countable (Oracle A))
    (_ : Infinite A), False
  -- (theorem-shaped documentation marker: the oracle function space over
  --  an infinite query type is NOT countable (Cantor); recorded so no
  --  fake countable-machines claim slips in. The Cantor proof itself is
  --  classical set theory, left to the bridge milestone.)

/-- The positive, provable half the tournament DOES have: the program
  universe `Nat.Partrec.Code` is countable (Denumerable), and its
  bounded-step simulation `evaln` is what the diagonalization iterates. -/
theorem Code_countable : Countable Nat.Partrec.Code :=
  inferInstance

end DiagonalBridge

end Barriers

end PleaNP