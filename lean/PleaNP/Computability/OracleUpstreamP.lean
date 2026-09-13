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

NOTE: the RHS is `UpstreamPolyTime` (the oracle-free
`TM2ComputableInPolyTime` recharacterization, per Trap 3 / the
`P^∅ = P` anchor), so the statement is now fully rendered — the only
remaining `sorry` is the honest proof, pending upstream P (DEC-003).
See SORRY_TRACKER #6 (resolved: statement-level sorry filled) / #7.
-/

namespace PleaNP

namespace Oracles

open Turing

/-- P^∅ = P compatibility (statement fully rendered; proof pending
  upstream P / DEC-003). The empty oracle's classes collapse to the
  oracle-free polytime class `UpstreamPolyTime`. -/
theorem P_empty_eq_upstream_P_class {Q : Type} (alpha : Type) :
    P_A (alpha := alpha) (emptyOracle Q) = UpstreamPolyTime alpha := by
  sorry

end Oracles

end PleaNP
