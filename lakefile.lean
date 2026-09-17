import Lake
open Lake DSL

/-! # Root package declaration (PleaNP #102)

Downstream Lake projects resolve a dependency's package root at the **repo root**,
so a sibling repo (e.g. Maith) that wants `require PleaNP from git ...` needs a
`lakefile.lean` here. Without it, `lake update` fails with:

    error: PleaNP: no configuration file with a supported extension:
      .lake/packages/PleaNP/lakefile.lean
      .lake/packages/PleaNP/lakefile.toml

PleaNP's own build commands continue to run from `lean/` and are unaffected: Lake
picks the nearest lakefile, so `cd lean && lake build ...` still reads
`lean/lakefile.lean`. That file remains authoritative for tooling, CI, the
devcontainer, and `tooling/elantool.sh` — all of which operate from `lean/`.

`srcDir := "lean"` repoints this package at the existing source tree, so nothing
moves. The library declarations below must mirror `lean/lakefile.lean`; a minimal
shim with only `package`/`srcDir` was tested and does NOT work — consumers fail with
`unknown module prefix 'PleaNP'` because no library is declared, so nothing builds
and no oleans exist. The duplication is therefore unavoidable, and
`tooling/gates/lakefile_sync_check.py` fails CI if the two files drift apart.
-/

package «PleaNP» where
  srcDir := "lean"

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