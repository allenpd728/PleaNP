import PleaNP.Basic

/-!
# Basic sanity tests

These tests verify that the PleaNP library imports correctly and that the
project scaffolding is sound. Real tests are added as the library develops.
-/

-- Smoke test: the project compiles and Mathlib is available.
#guard_msgs (whitespace := exact) ""
