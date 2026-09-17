import Mathlib
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# BGS (b): the Machine-to-Code bridge — the obstacle, localized (issue #118)

A faithful `Machine → Code` compiler is the tournament's last gap. This module
used to record the obstruction as "*the raw `Machine Q tm` type carries an
arbitrary oracle `Q → Bool`, uncountable for infinite `Q`, so a faithful
bijective `Machine → Code` is IMPOSSIBLE and 'detect P or punt' is REQUIRED*".

**That analysis is misplaced for the statement the tournament needs**, and
`DiagonalSyntax` (#118) records the correction with proofs:

- The witnesses of `P_A A` / `NP_A A` pin the oracle by an explicit conjunct
  (`M.oracle = A` in `OracleComplexity.lean`), so the oracle is **not** a
  degree of freedom when the diagonalization quantifies over "every poly-time
  machine with oracle `B`" (which is what `U_B ∉ P_A B` means). Its
  uncountability cannot be the obstruction to enumerating *those* witnesses.
- `DiagonalSyntax.machineEquiv` factors a machine as
  `Machine Q tm ≃ MachineSyntax tm × Oracle Q × (List (Γ k₀) → Q)`. This
  **localizes** the (possibly uncountable) content in the `oracle`/`decode`
  factors; the `MachineSyntax` factor is finite (`Fintype` proved).
- `DiagonalSyntax.mem_P_A_oracle_pinned` makes the pinning explicit.

What actually remains is a *routine modeling step*, not an impossibility: the
witnesses also carry `tm' : FinTM2` (whose fields include types `Λ`, `σ`, `K`,
`Γ`, so `FinTM2` is not itself a set to enumerate) plus `decode`, `ea`, `oa`.
Enumerating those means **fixing a concrete machine family and a canonical
`decode`** — a modeling choice with a routine resolution. "Punt slow codes" is
one option among several, not a requirement.

(Historical note: the Cantor fact below is still true about the *bundled*
`Machine` type; it is simply not the obstruction it was recorded as being.)
-/

namespace PleaNP

namespace Barriers

namespace DiagonalBridge

open PleaNP.Oracles
open Turing

/-- The Cantor fact, recorded precisely: the *bundled* `Machine Q tm` type
  carries an oracle `Q → Bool` — uncountable for infinite Q (Cantor: a
  countable enumeration would miss the diagonal-flip function) — and a decode
  `List (Γ k₀) → Q`, an infinite-domain function space even for finite Q.

  So the bundled `Machine` type is not countable. **But** this is about the
  bundled type, NOT about the `P_A`/`NP_A` witnesses the tournament
  enumerates: those pin `oracle = A` (see `DiagonalSyntax`), so they do not
  range over the `oracle` factor at all. The earlier reading of this fact as
  "the bridge is impossible" was wrong for the statement at hand (#118). -/
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