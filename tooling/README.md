# Tooling

The AI + integrity layer of PleaNP. Python-based.

- **`retrieval/`** — Premise selection / representation experiments. (Rung 6.)
  This is where any Maith-IR-style retrieval experiments would live, *if*
  Maith's H6 (retrieval) hypothesis resolves positive. Independent of the
  formalization library.
- **`gates/`** — The integrity pipeline. (See `../docs/ARCHITECTURE.md`.)
  Statement-freeze, model-consistency, statement-fidelity, read-back,
  non-triviality, hygiene checks. These run *around* proof search, not as
  part of it.
- **`audit/`** — Gap-audit tooling. (Rung 1.) Scripts for inspecting
  Mathlib's complexity coverage programmatically.

This layer is deliberately separate from `lean/`: the integrity gates check
the *statement* and the *process*; the Lean kernel checks the *proof*.
Three different trust boundaries, kept separate.
