# Submitting PleaNP work to Mathlib — process, rejection handling, and the honest plan

**Purpose:** prepare for the real process of contributing PleaNP's modules to
Mathlib (the standard Lean 4 math library), including the realistic risk of
rejection and how to handle it without reputational damage. This is a living
playbook, not a promise.

---

## The honest starting point

- **PleaNP is not ready to submit anything to Mathlib yet.** The P/NP
  substrate is still contested upstream (see `docs/UPSTREAM_TRACKING.md`), and
  PleaNP's own modules (oracle machines, circuits) are PleaNP-local and
  unvalidated against a landed upstream model.
- **The only thing PleaNP might eventually submit is its *oracle-machine
  layer* (Rung 2 local)** — the gap audit says no upstream effort provides
  time-bounded oracle computation, so it's a genuinely useful, upstreamable
  module. The barrier theorems themselves (Rung 3) are PleaNP's research
  contribution — they may be publishable as papers, but they are *not* Mathlib
  modules (they depend on the contested substrate).
- **Rejection is the default expectation, not a failure.** Mathlib is a
  high-bar, heavily-reviewed library. Most submissions go through multiple
  review rounds; many are declined or require major rework. That is normal and
  does not reflect on the work's value.

---

## The Mathlib submission process (what actually happens)

1. **Before submitting — community alignment.** Mathlib work happens on
   GitHub PRs + the Zulip chat. The accepted path is: raise the idea on Zulip
   first, get maintainer/community feedback on the *approach*, then open a PR.
   A PR that appears without prior discussion is far more likely to be
   declined or ignored.
2. **The PR.** Fork mathlib, open a PR against `master` with a clear title and
   description. Mathlib uses **bors** (merge queue) and has strict CI: every
   file must pass `lint`, style checks, and the full build.
3. **Review.** Maintainers and community review the PR. Expect: style nits,
   naming suggestions, requests to match Mathlib conventions, requests to split
   into smaller PRs, and substantive design feedback.
4. **Merge.** Only after CI green + maintainer approval. This can take weeks
   to months for a nontrivial module.

---

## The realistic rejection paths (and how to handle each)

### Path A — "Not ready / too early" (most likely now)
The substrate is contested; maintainers may say "wait until the P/NP model
lands" or "this overlaps with effort X."

**Handle:** agree, document the dependency, and keep the work PleaNP-local
until the substrate lands. This is *not* a rejection of the work — it's a
timing call. Record it in `UPSTREAM_TRACKING.md` and re-attempt when the
substrate is settled.

### Path B — "Split it / too big"
The oracle layer is too large for one PR; maintainers want it decomposed.

**Handle:** split into the smallest reviewable units (e.g. oracle type →
machine → step → time-bound → classes). PleaNP's own sub-task discipline
(#21-#25) already models this. A split is *progress*, not rejection.

### Path C — "Wrong approach / design objection"
Maintainers disagree with the design (e.g. totality discipline, the
oracle-as-function choice, the namespace).

**Handle:** engage seriously. Mathlib maintainers are expert; a design
objection is the highest-value feedback available. If the objection is sound,
adapt. If it's a genuine disagreement, make the case on Zulip with evidence.
**Never** respond defensively or argue without data. The goal is the best
design, not "winning."

### Path D — "Duplicate of effort X"
Another effort already provides the module.

**Handle:** if a landed upstream module supersedes PleaNP's, import it
(DEC-003) and redirect PleaNP's contribution to the *gaps* that remain (the
barriers, the missing pieces). A duplicate finding means the ecosystem moved
faster — PleaNP's value shifts to what it uniquely adds.

### Path E — "Rejected with substantive criticism"
The work is declined on quality/design grounds after review.

**Handle:** treat it as the most valuable feedback available. Address the
criticism in the code, re-submit if appropriate, or document why the criticism
is wrong (with evidence). **The project's entire integrity architecture is
built for exactly this** — the gates, the read-back, the review loop — so a
rejection can be turned into a concrete fix list rather than a dead end.

---

## The non-negotiables (what protects PleaNP's reputation)

1. **Never submit a `sorry`.** Mathlib rejects `sorry` outright. PleaNP's
   honesty gates (hygiene, vacuity, axiom check) already enforce this — the
   submission must be zero-`sorry` on the submitted surface.
2. **Never submit the barrier theorems as Mathlib modules.** They depend on
   the contested substrate and are PleaNP's research contribution, not library
   code. Submit the *substrate* (oracle machines); publish the *theorems* as
   papers.
3. **Cite prior art.** `docs/PRIOR_ART.md` documents the citation duty — a
   submission that ignores the bounded-arithmetic tradition or the existing
   P/NP efforts will (correctly) be rejected on scholarship grounds.
4. **Follow the community process.** Zulip-first, small PRs, match conventions,
   engage review. A process-violating submission is a self-inflicted rejection.
5. **One human accountability anchor.** Mathlib review is human; PleaNP needs
   a named human (owner or a Lean-literate ally) who can engage the community
   — the same gap flagged for Zulip and funding. This is the load-bearing
   prerequisite for any submission.

---

## The concrete plan (when we're ready)

1. **Now (pre-submission):** keep PleaNP-local modules clean, gated, and
   documented; track the upstream contest (`UPSTREAM_TRACKING.md`); identify
   the human anchor.
2. **When upstream P/NP lands:** import it (DEC-003), reconcile PleaNP's oracle
   layer against it, and validate.
3. **Then:** raise the oracle-machine module on Zulip, get approach feedback,
   open a small PR, iterate through review.
4. **On rejection:** follow the Path A–E handling above; record the outcome in
   the decision log; re-attempt when the blocker clears.

---

## Status

2026-09-06 — playbook documented. No submission is planned until the upstream
substrate lands and a human anchor exists. This document is the preparation:
process known, rejection paths mapped, reputation rules fixed.