/-
The PleaNP barrier library.

This directory contains the formalizations of the three known barriers to
resolving P vs NP:

  - `Relativization.lean`  : Baker–Gill–Solovay (1975)
  - `NaturalProofs.lean`   : Razborov–Rudich (1994)
  - `Algebrization.lean`   : Aaronson–Wigderson (2008)

Each requires its own substrate (oracle machines; circuit complexity +
pseudorandom functions; oracles + finite fields respectively). See
`docs/GAP_AUDIT.md` for the dependency structure and current Mathlib gaps.

These are stubs pending Rung 3 (see `docs/ROADMAP.md`).
-/
