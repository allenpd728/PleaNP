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
- **`galaxy/`** — The Galaxy visualization (issues #86/#87). A stdlib-only
  data layer (`galaxy_data.py`) extracts the repo's negative-space artifacts
  — `formalization.yaml` barriers, `churn/*/matrix.json` blocked pairs,
  `blockers/`, `docs/SORRY_TRACKER.md`, `reviews/pending/` — into a Galaxy
  model (black holes = barrier families, event horizons = provability
  boundaries, asteroids = failed/blocked attempts colored by rejecting gate).
  A renderer (`galaxy.py`) emits a self-contained static `galaxy.html`
  (vanilla Canvas 2D, no CDN, opens offline) with orbit-drag, hover tooltips,
  and a legend. Regenerate with:
  `python3 tooling/galaxy/galaxy.py --repo . --out tooling/galaxy/galaxy.html`
  Or preview on demand: `--serve 8000` (or copy the HTML into a served dir).
  Unit tests: `python3 tooling/galaxy/tests/test_galaxy_data.py` and
  `python3 tooling/galaxy/tests/test_galaxy_render.py` (stdlib, no network).

This layer is deliberately separate from `lean/`: the integrity gates check
the *statement* and the *process*; the Lean kernel checks the *proof*.
Three different trust boundaries, kept separate.
