import tests.OracleV5
set_option warningAsError true

/-!
# Basic sanity tests

These tests verify that the PleaNP library imports correctly and that
the project scaffolding is sound. The v5 oracle-substrate tests
(`tests.OracleV5`, issue #40) are imported here so the `test` exe
(root `tests.Basic`, built by `lake build test`) links them; the
suite is compiled by `lake build tests` (the `tests` lib).
-/

-- Smoke test: the project compiles and Mathlib is available.
example : True := trivial

-- Entry point for the `test` exe (`lake build test`).
def main (_ : List String) : IO Unit := pure ()
