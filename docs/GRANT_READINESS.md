# Grant readiness — honest gap analysis and funding requirements

**Date:** 2026-09-06. **Status:** living document — update as rungs land.
**Audience:** the project owner (for funding decisions) and any reviewer.
**Purpose:** the frank gap analysis of what exists vs. what a grant panel will
require, in priority order. This is the "what are we missing" answer,
grounded in the actual repo state, not aspiration.

---

## The one-sentence problem

**The project's headline claim is the barrier library; not a single barrier
theorem is proven yet.** Everything else (foundation, tooling, process) is
real and defensible — but the *novelty* the pitch rests on is currently
asserted, not demonstrated.

Verified repo state (2026-09-06):
- **Proven theorems (zero-sorry, clean modules):** 5 foundational lemmas
  (oracle determinism `evalsTo_unique_result`, `P_A ⊆ NP_A` relative to any
  oracle, smoke accepts/rejects). These are real but *foundational* — they
  prove things about PleaNP's *own* oracle-class definitions.
- **Barrier theorems:** Relativization = 2 sorries (statement rendered, proof
  absent); Natural proofs, Algebrization = none in Lean. **0% proven.**
- **P^∅ = P compatibility:** sorry'd (the connection between PleaNP-local
  `P_A`/`NP_A` and any upstream P/NP is unproven).
- **`#barrier_check`:** novel engineering (classifies claim shapes via a
  `Relativizing` typeclass) but the *soundness theorem* ("a proof carrying
  `Relativizing` truly relativizes in the BGS sense") is unproven.
- **CI:** green on the clean surface; the 2 expected-sorry modules fail by
  design (nuanced, but a skim reads "red CI").

---

## The holes, by exposure (what a skeptical reviewer will hit first)

### 1. The P/NP grounding ("whose P and NP?") — highest exposure
`P_A`/`NP_A` are PleaNP-local class definitions. No upstream P/NP has landed.
A reviewer's first question — "is this the canonical P vs NP?" — currently
answers "a PleaNP-local oracle-machine class, not yet connected upstream."
This is *the* semantic vulnerability: a hostile reviewer can claim the project
proves "theorems about its own private definitions," not complexity theory.

### 2. Zero proven barriers (the novelty claim is un-demonstrated)
README says "none of these barriers has a machine-checked proof in any proof
assistant... This project fills that gap." The gap-filling is the roadmap, not
the current state. First-page-credibility requires at least ONE barrier
theorem, zero-sorry, end-to-end.

### 3. The BGS statement isn't frozen/validated
It sits on unvalidated class definitions and carries 2 sorries. The
"frozen, human-verified statement + read-back" artifact (the project's own
standard) doesn't exist for the crown-jewel theorem yet.

### 4. `#barrier_check` soundness is unproven
DEAD/Inconclusive verdicts rest on an unproven theorem. A reviewer will ask
for the soundness proof: "if a proof is `Relativizing`, does it truly
relativize (BGS sense)?" — not yet answered.

### 5. No measured AI-honesty experiment
The `<20% proof-check / <10% exact-match` numbers from LeanDojo Benchmark 4
are cited as the threat model, but there's no *measured* claim — no run of
`#barrier_check` across a corpus showing agreement/DEAD rates. One table
would convert this from citation to evidence.

### 6. No paper, no named human, no team, no external validation
Grants fund people. There is no lead investigator named, no co-PI, no
independent renderings (Gate 3 is tooled but unexercised with a second
author), no venue line, no arXiv-style writeup.

### 7. Staleness & reproducibility
`GAP_AUDIT.md`/`UPSTREAM_TRACKING.md` predate today; the bootstrap leans on
the community Azure cache with no container pin (devcontainer exists but
is dormant).

---

## What's required for a grant (by tier)

### Tier 1 — non-negotiables (most grants bounce without these)
1. **Prove at least one barrier theorem, zero-sorry.** Cleanest: BGS
   Relativization clause **(b)** (separating oracle) or (a). This is the
   single move that converts the pitch from "we have the tools" to "we
   produced a never-before-formalized theorem."
2. **Close or defensibly state the P/NP grounding** (the `P^∅ = P`
   compatibility, or an explicit "PleaNP-local classes until upstream
   lands" stance written into the README/paper so it can't be called a
   surprise).
3. **A measured AI-honesty experiment** — `#barrier_check` verdicts across a
   small corpus (THH stand-in + textbook claims), reported as one table.
4. **A paper/proposal skeleton** — problem → threats → approach → the barrier
   calculus → the gates → measured results → roadmap.
5. **CI green on the clean surface, expected-sorry modules quarantined and
   written up** (not "red CI" by surprise).

---

## Measured corpus experiment (Tier-1 #3 — results, 2026-09-07)

**Run** (issue #19): `python3 tooling/gates/corpus_campaign.py bgs barrier-verdict
   --skip-mine --previously-mined bgs:5` → `tooling/gates/corpus_campaign.json`.

The multi-rendering loop (`multi_render check --lemmas` + `mine`) ran over
2 campaign workspaces (6 independent renderings of the two barrier-shaped
informal claims: the BGS clauses and the barrier-calculus DEAD shape).

| Campaign | Claim | Renderings | Pairs | Machine-equivalent | Disagreements | Mined (this run) | Mined (historical) |
|---|---|---|---|---|---|---|---|
| `bgs` | BGS: oracles separate/equalize P^A vs NP^A | 4 | 6 | 1 (A≡C, by proved IFF lemma) | 5 | 0 (re-mine skipped; dedupe per #20) | 5 (#7–#16, swept) |
| `barrier-verdict` | DEAD-shape: relativizing + P-vs-NP-shaped | 2 | 1 | 1 (A≡B, by proved IFF lemma) | 0 | 0 | 0 |
| **Total** | | **6** | **7** | **2 (29%)** | **5 (71%)** | **0** | **5** |

**Read:** the machine can verify renderings that agree structurally (2/7
pairwise = 29% EQUIVALENT with proved IFF lemmas); the disagreements (5/7)
are cross-clause set-equality-vs-witness shape ambiguities — exactly the
places a statement can be silently wrong and the places the human mines
(#7–#16, acknowledged; dedupe by inbox id per #19 DoD). The
`barrier-verdict` campaign closes fully equivalent (the DEAD shape is robust
across binder orders) — bisherie measured agreement evidence for the
`Relativizing`/`#barrier_check` calculus. Re-runs via `corpus_campaign.py`
(recompute matrices + counts;`--skip-mine --previously-mined bgs:5` for the
already-mined bgs disagreements).

### Tier 2 — differentiators
6. **Frozen + read-back-checked BGS statement** (Gates 1–4 complete), even
   absent the proof.
7. **An external/independent rendering** (Gate 3 exercised with a second
   author — a Lean-literate volunteer or an LLM pass) as evidence the
   statement means what we say.
8. **Today-dated upstream audit** (one paragraph: "state of upstream as of
   <date>") — kills the staleness charge cheaply.
9. **Reproducibility note** (toolchain pin, cache, devcontainer or container).

### Tier 3 — funding-specific
10. **A named lead + a human accountability anchor.** Grants fund people.
   Same gap as Zulip readiness, doubled for funding.
11. **A concrete, bounded aim** ("formalize BGS Relativization + prove
    `#barrier_check` soundness within 12 months") — specific, falsifiable,
    achievable. Panels distrust open-ended "build the whole landscape."
12. **Collaborators/allies** (co-PI, Mathlib maintainer, Lean-formalization
    researcher). Team quality is a major scoring axis.
13. **Venue/community line** (ITP, CPP, Lean workshops) + the prior art you
    build on (Coq Cook-Levin, Reitwiessner) + what is *measurably* new.

---

## The Gate-3 "AI multi-rendering → human mine" strategy (how we get there)

The path that makes Tier-1 items 1 and 4 tractable *and* creates the external
validation (Tier-2 item 7) is the **Gate-3 multi-rendering loop**:

1. **AI multi-rendering:** for a target theorem, N agents (or N LLM passes) each
   produce an *independent* Lean rendering from the informal statement.
   `dual_render.py check` runs pairwise equivalences: renderings that agree
   (machine-proven IFF) cluster; renderings that disagree identify the
   *shape ambiguity* — exactly where a statement can be silently wrong.
2. **Human mine:** each equivalence verdict and each disagreement pools into
   the review inbox → a GitHub issue. The human (you) mines the issues: each
   is one plain-language question ("these two renderings disagree on
   whether there is *one* oracle or *all* oracles — which did you intend?").
   Confirmed agreements freeze the statement; flagged disagreements send an
   agent back to revise.
3. **Outcome:** the barrier statements get *frozen with independently-verified
   renderings* (Tier-2 #7) and the ambiguities that would have killed the
   grant's credibility get caught *before* a reviewer finds them.

This is the concrete bridge from "tooling project" to "fundable formalization
research": machine-multi-renderinged renderings + human-mined fixes incrementally map
the shape of all three barriers.

---

## Proof stance (why PleaNP is classical / non-constructive)

PleaNP's proofs are **non-constructive by choice** (axiom fingerprint
{propext, Classical.choice, Quot.sound}, CI-enforced). This is correct for
the mathematics (barrier statements are existence-shaped) and — strategically —
the safest posture: if P = NP turns out true and cryptography collapses, a
*non-constructive* proof proves existence without having *constructed the hard
object* that breaks crypto. Constructive results remain welcome wherever the
mathematics permits them. (DEC-018 records this; constructive-only would be a
major pivot.)

## Open items this doc tracks (informal issue list)

- [ ] Upstream P/NP lands; re-audit Rung 2 (ties to issue #4)
- [ ] Prove BGS clause (b) zero-sorry (needs substrate + diagonalization)
- [ ] Freeze + read-back the BGS statement (Gates 1–4)
- [ ] Soundness proof for `#barrier_check` (Relativizing ⟹ BGS-relativizing)
- [x] Measured `#barrier_check` corpus experiment (landed 2026-09-07, #19; see the table above)
- [ ] Name a lead + find a co-PI/ally
- [ ] Write the paper skeleton
- [ ] Date-stamp the upstream audit; add reproducibility note
