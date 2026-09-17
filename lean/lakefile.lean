import Lake
open Lake DSL

package «PleaNP» where

@[default_target]
lean_lib «PleaNP» where
  globs := #[.andSubmodules `PleaNP]

/-- The `tests` library: the test-suite modules (e.g. `tests.OracleV5`,
  the v5 oracle-substrate tests from issue #40; `Basic` is the exe
  root). Root names are fully qualified module names. `lake build tests`
  builds the suite; the runnable `test` exe (root `tests.Basic`,
  depends on this lib) links it. -/
lean_lib tests where
  roots := #[`tests.OracleV5, `tests.BarrierCalculusFuneq,
    `tests.LowerBoundCompilerGuards]

lean_exe test where
  root := `tests.Basic
  deps := #[`tests]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.31.0"
