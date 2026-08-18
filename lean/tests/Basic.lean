import PleaNP.Basic
set_option warningAsError true

/-!
# Basic sanity tests

These tests verify that the PleaNP library imports correctly and that the
project scaffolding is sound. Real tests are added as the library develops.
-/

-- Smoke test: the project compiles and Mathlib is available.
example : True := trivial

-- Entry point for `lake exe tests`.
def main (_ : List String) : IO Unit := pure ()
