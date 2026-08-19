import Mathlib

/-
# PleaNP

A Lean 4 / Mathlib project formalizing the barrier landscape of computational
complexity theory — the meta-theorems (relativization, natural proofs,
algebrization) showing which proof techniques provably cannot resolve P vs NP.

See `README.md` and `docs/ROADMAP.md` for the project overview and rung ladder.
See `docs/GAP_AUDIT.md` for the current status of Mathlib's complexity coverage.

Project-specific declarations live under the `PleaNP` namespace.
Complexity classes (P, NP, reductions) are imported from upstream Mathlib
once they land (see `docs/UPSTREAM_TRACKING.md`); oracle machines and the
barrier theorems are defined here.
-/
