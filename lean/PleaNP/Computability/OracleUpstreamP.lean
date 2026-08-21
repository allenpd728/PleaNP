import PleaNP.Computability.OracleComplexity
set_option warningAsError true

/-!
# Upstream-P tracking anchor

Holds the P^∅ = P compatibility statement that is genuinely blocked
on upstream Mathlib landing a complexity-class P (DEC-003). Kept in
its own leaf module so that `warningAsError` (Gate 6: sorry is a
build error) does not cascade into OracleComplexity and everything
downstream of it. This module is EXPECTED to fail the build until
upstream P lands; its sorries are tracked in docs/SORRY_TRACKER.md.

NOTE: the set-comprehension RHS is itself a statement-level sorry —
the theorem does not yet fully say what it proves. That is a known
Gate-5 concern and the next thing to fix when upstream P becomes
available (or when the class gets an oracle-free recharacterization).
-/

namespace PleaNP

namespace Oracles

open Turing

/-- P^∅ = P compatibility (statement, proof pending upstream P). -/
theorem P_empty_eq_upstream_P_class {Q : Type} (alpha : Type) :
    P_A (alpha := alpha) (emptyOracle Q) =
    { L | sorry } := by
  sorry

end Oracles

end PleaNP
