import PleaNP.Barriers.LowerBoundCompiler

set_option warningAsError true

/-!
# Lower-Bound Compiler — contract-guard tests (issue #80 Pass 2)

`PleaNP.Barriers.LowerBoundCompiler` refuses a `#lower_bound_compile`
contract that is the wrong shape, rests on `sorryAx`, or does not exist.
These tests pin those rejections as build-time failures, so a regression
that loosened a guard cannot land silently: each `#guard_msgs` block
asserts the exact error, and a changed (or missing) error is a build error.

The module lives in the `tests` lib, not the clean build set: the
`sorry`-carried decoy contract below is a genuine `sorry`, and the clean
modules are scanned with `hygiene_scan.py --prove-stage`.

The **accept** path (a valid, `sorry`-free contract → emission) is specified
separately in `docs/STATEMENTS/LowerBoundCompilerAcceptPath.spec.md`
(issue #109); it is unreachable until #98 supplies a `SubExpCircuitSATT`
proof, so its spec — not a runnable test — is the deliverable today.
-/

namespace PleaNP

namespace Barriers

namespace Williams

/-- A decoy of the wrong shape: any old `Prop`, not the sub-exponential
  CircuitSAT contract the compiler consumes. -/
def notAContract : Prop := True

/--
error: lower_bound_compile: contract 'PleaNP.Barriers.Williams.notAContract' does not prove `SubExpCircuitSATT`; the input contract must be the sub-exponential CircuitSAT witness (design note §2).
-/
#guard_msgs in
#lower_bound_compile notAContract as rejectedShape

/- A contract of the right shape whose proof rests on `sorryAx`: the
  "no asserted runtime" anti-requirement must reject it (a `sorry`-carried
  runtime would make the emitted lower bound only as strong as the sorry).

  `warningAsError` is locally disabled for the decoy so its `sorry` reports
  as `sorryAx` (the thing under test) instead of failing the build first. -/

set_option warningAsError false in
theorem sorryContract : SubExpCircuitSATT := by sorry

/--
error: lower_bound_compile: input contract 'PleaNP.Barriers.Williams.sorryContract' depends on `sorryAx`. A placeholder-carried runtime is a REJECTED contract (design note §2, anti-requirement 'no asserted runtime').
-/
#guard_msgs in
#lower_bound_compile sorryContract as rejectedSorry

/- A missing contract is a clear error, never a silent no-op. -/

/--
error: lower_bound_compile: unknown declaration 'PleaNP.Barriers.Williams.noSuchContract'
-/
#guard_msgs in
#lower_bound_compile noSuchContract as rejectedMissing

/- The conditional emission is idempotent-safe: re-emitting a name that
  already exists is rejected rather than silently shadowing it. -/

/--
error: `PleaNP.Barriers.Williams.williams_lower_bound_compiled` has already been declared
-/
#guard_msgs in
#lower_bound_compile_cond williams_lower_bound_compiled

end Williams

end Barriers

end PleaNP