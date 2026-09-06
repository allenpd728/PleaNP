# CONTRIBUTIONS.md — community contributions to PleaNP (Zulip friendly)

How external contributors (especially Lean/Mathlib Zulip community members)
can contribute to PleaNP, and how those contributions are triaged, gated, and
merged. This is the public face of the multi-agent workflow
(`docs/MULTI_AGENT_WORKFLOW.md`).

> **TL;DR:** contributions come in as GitHub **issues** (ideas/bugs) or
> **pull requests** (code). An agent (or the maintainer) triages them into the
> issue queue, runs the integrity gates, and merges. You don't need to know the
> gate details to contribute — the repo's agents and CI enforce them.

## Maintainer model (be transparent, not apologetic)

This repo is maintained by **one human + OpenHands agents**. The human is not
Lean-literate and does not (yet) participate in the Lean/Mathlib Zulip. That
is a deliberate, documented choice (DEC-015): **the artifact speaks first.**
Concretely:

- All formal claims pass the integrity gates mechanically (hygiene, vacuity,
  model-consistency, lethality, `#barrier_check`), so "agents did it" is
  auditable — every step is a gate-verified commit on a public branch.
- If you're considering contributing and feeling unsure about the human-in-the-
  loop: a PR is reviewed by an agent + CI, and **anything gated is verified by
  machine regardless of who wrote it**. You are not implicitly endorsing an
  unaudited agent claim by contributing here.
- The human's role is accountability: decision log, scope, and knowing what is
  and isn't an anchor. If you want a more classic maintainer relationship
  (e.g. a Lean-literate co-maintainer), that is a known, welcomed gap — issue
  `CONTRIBUTIONS: co-maintainer` would be the fastest way to open it.

This page documents the *mechanics*; the honesty is the repo's actual
mechanism for trust.

## Why we want community contributions

- No proof assistant has formalized the complexity barriers (relativization,
  natural proofs, algebrization) — this is genuinely open ground, and the
  Lean/Mathlib community is the likely source of the substrate know-how
  (oracle machines, step counting, circuit complexity).
- PleaNP deliberately defers P/NP definitions to upstream Mathlib
  (DEC-003, `docs/UPSTREAM_TRACKING.md`). Community members tracking those
  upstream efforts can help PleaNP stay aligned.
- The Rung-5 Barrier Calculus (`#barrier_check`) is a natural target for
  curiosity-driven contributions: it's self-contained, meta-level, and
  doesn't require the (blocked) P/NP substrate.

## How to contribute

### 1. Ask first (Zulip, issues, or a draft PR)
The fastest path is an **issue** describing what you want to do. An agent (or
the maintainer) will reply and, if it's in scope, file/label a task.

In scope (from `README.md` / `docs/ROADMAP.md`):
- Barrier Calculus: `Relativizing` instances, new propagation rules,
  `#barrier_check` extensions, unit tests
- Oracle-machine substrate (PleaNP-local, Rung 2): v4 repair follow-ups,
  `EvalsToInTime` reachability, smoke tests
- Statement specs (`docs/STATEMENTS/`) — *prose only*, Gate-1 anchors
- Circuit complexity (`PleaNP.Circuits`), proof complexity — Rung 4+ groundwork

Deliberately out of scope (README "Out of scope"):
- Defining P/NP/reductions locally (upstream's job; see DEC-003)
- Claims to resolve P vs NP (see `docs/FAILURE_AUDIT.md` for why these fail)

### 2. Contribute an issue (idea, bug, gap)
- File it with a **summary**, a **definition of done** (what would count as
  resolved), and **context** (links to specs/upstream).
- An agent will label it (`status:available`, `community-ready`,
  `needs-gate`, or a blocker if it needs maintainer input) and it enters the
  queue.

### 3. Contribute a PR (code)
- **Work on a branch, not `dev`/`main` directly.** Open a PR against `dev`.
- The PR will be picked up by an agent (or reviewed by the maintainer), who:
  1. Checks it against `docs/ROADMAP.md` / the relevant statement spec
  2. Runs the integrity gates (below)
  3. Merges to `dev` (review is retrospective, per the multi-agent flow)
- Minimal expectations on your PR:
  - Follow Mathlib conventions (`PleaNP.*` namespace — DEC-002)
  - No `sorry`/`admit`/custom `axiom` in a claimed-complete proof
  - A test (or test spec) for anything non-trivial
  - A one-line note in the PR of which rung/component it serves

## The gates (what happens to your contribution)

PleaNP's integrity pipeline (`docs/ARCHITECTURE.md`) is designed to catch the
#1 failure mode of P-vs-NP formalization: a compiling proof of the *wrong
statement*. Contributions pass through, in order:

1. **Statement-fidelity (Gates 1/3/4)** — the formal claim matches the frozen
   informal spec (for new theorems); Gate 4 read-back.
2. **Model-consistency (Gate 2)** — uses canonical P/NP (upstream), not a
   local redefinition; `PleaNP.*` namespace.
3. **Non-triviality (Gate 5)** — no vacuous `True`/`↔ True`/`:= none` bodies.
4. **Hygiene (Gate 6)** — no `sorry`/`admit`/`axiom`; CI enforces
   `warningAsError`.
5. **Lethality (Gate 5 Tier 1b)** — every parameter/binder is load-bearing.
6. **Barrier triage (Rung 5)** — P-vs-NP-shaped claims go through
   `#barrier_check`; a **DEAD** verdict means the claim cannot resolve P vs NP.

CI (`.github/workflows/ci.yml`) runs gates 4–6 on every PR. If your PR is
"just" a statement rendering or a calculus helper, most of this is automatic.

## For Zulip community members specifically

- The most valuable, least-friction contributions: **break the monolith**.
  - Comment on `PleaNP.Circuits` / `PleaNP.Calculus` API design
  - Contribute an independent rendering of a `docs/STATEMENTS/*.md` spec
    (this is literally Gate 3 — statement fidelity — two independent
    formalizations checked for equivalence)
  - Spot-check the v4 oracle substrate (`Oracle.lean`) against Mathlib
    conventions
- If you track upstream P/NP efforts (`docs/UPSTREAM_TRACKING.md`), an issue
  saying "upstream X just landed, here's what changes for PleaNP" is gold.

## Triage algorithm for agents/maintainer (reference)

An incoming issue/PR follows this decision path:

1. Is it in scope (README out-of-scope list)? If not → close with a pointer to
   the right place (e.g. Mathlib, complexitylib, upstream).
2. Is it already covered by an open issue/task? If yes → link as duplicate.
3. Does it need maintainer input before it can be *defined*? If yes →
   `status:blocked-needs-input` + a question comment.
4. Otherwise → label `status:available` (+ `community-ready` if suitable for
   a first-time contributor, `priority:high` if it unblocks the critical
   path), and it enters the agent queue.
5. PRs bypass the claim step (they're already "done" work): run the gates,
   request changes if needed, merge to `dev` when green.