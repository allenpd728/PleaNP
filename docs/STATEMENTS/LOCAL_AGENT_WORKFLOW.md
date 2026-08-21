# Local agent workflow: test-as-you-go validation

**Audience:** the OpenHands (or human) agent running on the local machine with the Lean toolchain, where `lake build` is available. This document is *not* a spec of a theorem — it is the **operating procedure** for how an agent turns the statement specs in this directory into validated Lean without violating the integrity gates (`docs/ARCHITECTURE.md`).

The remote authoring agent (which writes docs but cannot run `lake build`) and the local agent (which can) are **different trust boundaries** — see `docs/ARCHITECTURE.md`, "Trust boundaries," and DEC-007.

---

## Why this process exists

The failure audit (`docs/FAILURE_AUDIT.md`) is explicit: the #1 failure mode is a compiling proof of the *wrong statement*. The gates exist to prevent that. But the gates are only effective if the local agent follows a disciplined loop that *separates* statement-freeze from proof search. This document defines that loop so that:

- the remote agent writes the frozen spec (done — these `STATEMENTS/*.md` files);
- the local agent renders the spec into Lean and **validates the statement** (not yet the proof) against `lake build` and the Gate 4 read-back;
- only after the statement is frozen and read-back-validated does any proof search begin.

---

## The test-as-you-go loop

For each statement spec (`Relativization.md`, `NaturalProofs.md`, `Algebrization.md`), the local agent works in this order. **Each numbered step produces a checkable artifact before the next runs.**

### Step 0 — Confirm the substrate exists (do not skip)

Before rendering *any* statement, do two lookups:

1. **The playbook** (`docs/PLAYBOOK.md`, the row for this rung): is there prior groundwork to *import* (e.g. complexitylib for Rung 4), *imitate* (e.g. Cook–Levin for the diagonalization), or *consult for statement strength* (e.g. bounded arithmetic for 3b)? Doing this now changes whether the step is "build" or "wire" — skipping it is how dead ends get rediscovered.
2. **The dependencies** (`§2` of the spec): confirm they are present:

- For relativization (3a): is `PleaNP.Oracles.Oracle` and an oracle-machine type defined? Are upstream `P`/`NP` imported (or is Rung 2 still blocked)?
- For natural proofs (3b): is `PleaNP.Circuits` / `P/poly` defined? (If not, 3b is blocked on Rung 4 — stop here and surface the blocker, don't fake it.)
- For algebrization (3c): are `PleaNP.Oracles` (from 3a) and the finite-field extension machinery both present?

**Check:** `lake build PleaNP.Oracles` (etc.) succeeds with zero `sorry` in the dependency files. If a dependency is a `sorry`-stub, the statement is *not* renderable yet — log the blocker and stop.

### Step 1 — Render the statement (statement only, `sorry`-free definition of the *claim*)

Write the Lean statement into the appropriate file (e.g. `lean/PleaNP/Barriers/Relativization.lean`) following the *logical shape* and acceptance criteria in `§3` of the spec. **Render only the statement (`theorem ... := by sorry` is acceptable at this step as a placeholder for the proof), not the proof.** The statement itself must type-check.

**Check:** `lake build` compiles the file. The statement type-checks. Record the exact statement text (commit it).

### Step 2 — Hygiene scan (Gate 6, partial)

Run the hygiene scanner on the new file: confirm the only `sorry`/`admit` is the proof placeholder, and there are no custom `axiom`s, no `by decide`-abuse, no `sorry` smuggled via meta-programs. (A hygiene scanner is `tooling/gates/` work — if it doesn't exist yet, a `grep -nE 'sorry|admit|axiom'` on the file is the minimum.)

**Check:** no unexpected `sorry`/`axiom` outside the single proof placeholder.

### Step 3 — Model-consistency check (Gate 2)

Verify the statement references the canonical upstream `P`/`NP` and the canonical `PleaNP.Oracles.Oracle`/`PleaNP.Circuits.*` types — *not* local redefinitions. This is the encoding trap (e.g. partial-vs-total oracle for 3a; OWF-as-axiom-vs-hypothesis for 3b; low-degree-extension-collapsed-to-identity for 3c).

**Check:** the acceptance criteria in `§3` of the spec are each satisfied. If any fails, the statement is *not* the spec's statement — revise and re-render.

### Step 4 — Read-back (Gate 4 — the strong one)

Auto-generate (or manually write) a natural-language rendering of the *formal Lean statement just committed*, and compare it to the `§5` "Read-back check" sentence in the spec.

**Check:** the read-back matches the spec's §5 sentence, with none of the §5 "dropping X is a fail" omissions. **If the read-back disagrees, the statement is wrong — do not proceed to proof search.** Revise the statement and repeat from Step 1.

### Step 5 — Freeze (Gate 1)

Once Steps 1–4 pass, the statement is **frozen**: mark the file read-only to the proof-search component (the git workflow / file-permission mechanism Gate 1 specifies). From here, proof search may run against this statement but may **not** edit it. Any statement change requires a new spec revision (in this directory) and re-running Steps 1–4.

### Step 6 — (Later) Proof search (Gate 7)

Only after Steps 0–5 are complete for a statement does proof search begin. This is Rung 6 work and lives in a separate pipeline. The local agent's job at that stage is to produce proof terms the kernel checks — but the *trust* in those terms is bounded by how strictly Steps 1–5 were followed.

---

## What the local agent must NOT do

- **Do not edit a spec (`STATEMENTS/*.md`) to match a Lean rendering that happened to compile.** The spec is the source of truth; the Lean conforms to it. If the Lean can't express the spec, the spec isn't wrong — either the substrate is missing (Step 0 blocker) or the rendering is wrong (revise).
- **Do not run proof search against a statement that hasn't passed Steps 1–5.** That is the failure mode the whole architecture exists to prevent (`FAILURE_AUDIT.md` Pattern A/C).
- **Do not trust a green `lake build` as proof the statement is correct.** The kernel checks the *proof*; the gates check the *statement*. A compiling-but-wrong statement is the central risk — that's why Step 4 (read-back) is mandatory and non-automatable in spirit.
- **Do not fold in a v2 refinement.** Each spec pins a dated v1 (e.g. AW09 multiquadratic for 3c). The ITCS 2026 multilinear strengthening is a *separate* future spec, not a silent edit to the v1 statement.

---

## Status tracking

The local agent should update the spec's **Status** line (top of each `STATEMENTS/*.md`) as it progresses:

- `Draft — scaffold` (current state of all three)
- `Substrate confirmed` (Step 0 passed)
- `Statement rendered, type-checks` (Step 1 passed)
- `Gates 2/4/6 passed, frozen` (Steps 2–5 passed — statement is frozen)
- `Proof search in progress` (Step 6, Rung 6)
- `Proven, zero sorry` (done)

This makes the state of each barrier inspectable from the docs without reading the Lean.
