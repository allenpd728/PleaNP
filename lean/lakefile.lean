import Lake
open Lake DSL

package «PleaNP» where

@[default_target]
lean_lib «PleaNP» where
  globs := #[.andSubmodules `PleaNP]

lean_exe tests where
  root := `tests

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.31.0"
