# Review inbox — the human review surface (non-blocking, async)

**Audience:** the project owner (non-Lean-literate). **Purpose:** how you
review the *semantic* checkpoints that the machines and agents produce —
**without ever blocking the multi-agent stream**, and in a way that scales
across parallel agents and multiple work streams.

---

## ⭐ The GitHub-issues surface (your comment-based flow — no scripts)

**This is the interface you actually use.** Review points appear as GitHub
issues (labelled `review:pending`), one claim per issue, one question in the
body. You review them in the Issues list and answer with a **comment**:

- comment `confirm` → the issue is labelled `review:confirmed` and closed.
- comment `flag <reason>` → the issue is labelled `review:flagged` and stays
  open (the claim reopens; agents sweep flagged).

A free GitHub Actions workflow (`.github/workflows/review-issue.yml`) does all
of it — you never run a script. When an agent files a review point
(`reviews/pending/*.yaml`), the workflow auto-creates the issue. Your comment
is the whole interaction.

> **How to find your review list:** GitHub → Issues → filter by the
> `review:pending` label. That is your dedicated review queue.

---

## The one idea

A **review point** is a single claim + a single plain-language question.
Agents file review points **and keep working** — they never wait for you.
Your answers land asynchronously; a `flag` re-opens a claim *retrospectively*
(matching how the repo already reviews `dev` retrospectively). **Nothing
stalls.** This is the "inbox, not a gate" model.

## Where the interface lives

- **`reviews/INBOX.md`** — the one file you read. It is auto-generated and
  lists every pending review point, oldest first, batched from all agents.
  Everything you need to answer is on that single page.
- **`reviews/pending/`, `reviews/confirmed/`, `reviews/flagged/`** — the
  machine store (YAML files, one per point). You normally never touch these
  directly; the tool does.

## What a review point looks like (example)

```
### 20260906-163042-d97e
- claim: P_A subset NP_A for every oracle
- decl: `PleaNP.Oracles.P_A_subset_NP_A`
- machine summary: A statement about [P_A, NP_A] with oracle dependence
  relating by containment/subset (⊆).
- informal (what we wanted): For every oracle A, P^A is a subset of NP^A.
- **QUESTION: The machine says the statement is 'about containment of P_A in
  NP_A, over oracles'. Is that what you intended?**
- expected answer: yes
- run: `20260906-1530-a1b2`  agent: agent-A
```

You only ever answer the **bold QUESTION** — one fact, intro-level level.
The "machine summary" is generated from the Lean itself (statement_lint), so
the question is asking *you* to confirm the machine's reading matches your
intention — the irreducible last hop.

## How you answer

**Primary (comment-based — no scripts):** on the review issue, comment:

```
confirm
# or
flag <why it's wrong>
```

The workflow labels the issue (`review:confirmed`+close / `review:flagged`+open)
and records it. That's the whole interaction.

**Fallback / machine store (for agents, or if you ever prefer the local
inbox):** the local `reviews/INBOX.md` + `tooling/reviews/review_inbox.py`
remain the machine-readable store. Agents use them; you generally won't need
to. (Commands documented below for completeness.)

```bash
python3 tooling/reviews/review_inbox.py confirm <id>
python3 tooling/reviews/review_inbox.py flag <id> "why it's wrong"
python3 tooling/reviews/review_inbox.py index
```

## Why this improves async-multistream / multi-agent work

- **No blockers.** Agents append and continue; the pipeline never waits on a
  human.
- **Shared, merged stream.** Points from *all* parallel agents land in one
  inbox, deduplicated by construction (one file per claim), oldest-first.
  You see the whole landscape in one read, not per-agent noise.
- **Batching.** Reviewing 5–10 points in one sitting is the norm; each point
  is independent.
- **Retrospective, not gating.** A `flag` reopens a claim for the owning
  agent to fix — no one is stuck, and the fix happens on dev like any other
  review finding.
- **Auditable.** Each point carries its run-id, agent, commit refs, and the
  machine summary — so a `confirm`/`flag` always traces back to exactly what
  was reviewed.

## Status vocabulary

| Status | Meaning | Who sets it |
|---|---|---|
| `pending` | filed, awaiting the human | agent |
| `confirmed` | human confirmed the machine summary matches intention | human (or agent on human's instruction) |
| `flagged` | human says it does not match — claim reopens | human |

## Rules (so the inbox stays honest)

0. **Semantic forks only — not notation forks.** The mailbox escalates a
   decision *only* when the two readings would make the claim *differently true*
   (a real semantic fork: quantifier direction, subset direction, existence
   bounds) — in which case the question "which reading did you intend" needs
   you. It does NOT escalate a choice that merely *pins down syntax* (e.g.
   whether an interface helper is partial vs. total over a
   definitionally-irrelevant corner, or which spelling of an encoding to commit
   to): those are notation forks — the agent picks the more general/cleaner one
   by Occam, and moves on. Muting notation forks for the human (who should
   spend attention only where the theorem's truth is at stake) is a process
   requirement, not a kindness.
1. **One point = one claim = one question.** Agents must not bundle.
2. **Expected answers come from the Lean, not the wish-list** (see
   HUMAN_REVIEW_LAYERS: bias-guard).
3. **Missing gate evidence is not a flag — it is a process failure.** If a
   review point lacks the machine summary or the informal claim, file it back
   as a process violation, not a semantic one.
4. **Never block.** No agent may wait on a review answer before continuing
   unrelated work; a flag is handled in the next sweep, like any review
   finding on dev.
5. **End-of-session report** includes the inbox: new points filed, confirmed,
   flagged (see MULTI_AGENT_WORKFLOW end-of-session).

## How to decide a "disagreement" in plain words (Boolean logic style)

## Rendering disagreements ARE probe checklists

Since 2026-09-07 (#28),a multi-rendering disagreement is no longer reviewed
as an open-ended "what did you intend" question. It arrives as a **probe
checklist**: 3-5 tiny, independent, single-choice probes derived mechanically
from the Lean renderings, each with:

- a concrete `question` (one small fact you can reason about),
- labeled `choices` (pick one),
- a `hint` / inline `gloss` (plain-language, intro-level),
- the machine-derived `expected` answer (from the Lean, not the informal wish).

The contract is the same one-wrong-ao-blocked rule as every probe check: one wrong
answer = the claim is wrong. The batch narrative (if present) recaps why two
renderings diverged,so you never need to reassemble the disagreement from
scattered labels.

**Rule:** any disagreement that cannot be decomposed into >= 3 concrete probes
returns to the agents as 'not yet reviewable' - no intent-ratification anywhere.

The probes appear inside the review issue body (and in `reviews/INBOX.md`),so
you answer them the same way: `confirm` when every answer matches your reading;
`flag <reason>` otherwise (the claim reopens). Nothing else changes.


## Boolean way to think about it (traditional Gate-3 points

If a review point still arrives as the older plain-words-only form (no probes),
you are checking two facts: "fact 1: version A claims X" and "fact 2:
version B claims Y". Answer:

- **`confirm`** -> both facts look right, nothing surprising is claimed. (Even
  if they disagree with each other - disagreement between versions is fine
  when they are about different clauses; both can be intended.)
- **`flag <reason>`** -> one version claims something that should NOT be
  intended (e.g. "says a box makes the classes EQUAL" when you only wanted the
  separating part).

That is the whole decision. If an issue still shows only "disagree on the
shape" with no plain-words labels, and no probe checklist, that is a **tooling
bug** - flag it with "question does not show what the versions say" so an agent
fixes it (and see the top of this file for how agents file review points
correctly).

## Reviewer-fatigue protection (recheck-control twins)

**The question:** what protects against the human accidentally confirming
something that should have been flagged (fatigue, inattention, rubber-stamping)?

**The honest answer before this: nothing.** A `confirm` was accepted at face
value. That is now fixed with **recheck-controls** — the attention-check /
control-probe technique from survey and QA methodology, adapted:

- After a point is confirmed, any agent (or a review sweep) can run
  `review_inbox.py perturb <id>` to create a **recheck-control twin**: the same
  claim with **one load-bearing element flipped** (e.g. "for every" ↔ "there
  exists", "⊆" ↔ "⊇", "=" ↔ "≠").
- The twin is a normal pending point (so it becomes a GitHub issue to review),
  but its `expected` answer is **the opposite** of the original — **it should
  be FLAGGED.**
- If the human **confirms the control too**, that is a strong fatigue signal:
  `review_inbox.py fatigue` reports it (and fast-confirms < 30s), and the
  original confirmation is **re-queued automatically** — confirming a control
  immediately re-files the original claim as a fresh pending point
  (`reopened_by=<control>`, so nothing is silent). On the GitHub surface, the
  workflow's `confirm` handler detects the `control_of:` marker and calls the
  tool to re-queue, then pushes so `sync-pending` files the fresh issue — **no
  sweep needed**. (Design note: the auto-requeue re-files a *fresh* review of
  the original claim; it does not silently re-confirm or rewrite the prior
  decision — the control stays in the archive as the audit record.)
- **Disclosure (honesty matters for this project):** the *existence* and
  *purpose* of controls is documented openly — this section — and the twin's
  question says explicitly it is a recheck-control. The *identity* of which
  points are controls is *not* pre-marked (that would let them be gamed); you
  discover it by reading the twin's full question. Consequence is benign: a
  fatigue confirm re-queues, it does not blame or punish.

**What this catches:** rubber-stamping, pattern-matching, inattention, very
fast batch confirmation.
**What it does NOT catch (be honest):** a careful-but-mistaken reviewer, or a
statement subtly wrong in a way the human can't see — those are what the
two-independent-renderings (Gate 3) and the machine checks exist for. Controls
are one layer, not a substitute.

Rule for agents: `perturb` a confirmed point and sweep `fatigue` in session
reports. Rule for the human: treat a recheck-control as "should be flagged";
if you confirm one by mistake, no blame — it just re-queues that claim.

## Relationship to the other gates

- **Layer 1 (mechanical)** — CI, no human.
- **Layer 2 (read-back)** — two translators agree; the agreed English feeds
  the review point's "machine summary".
- **Layer 3 (probe / statement lint)** — the shape facts are now machine-
  derived (statement_lint); the review point's QUESTION is the single
  confirmation that remains human.
- **This inbox** — the *delivery mechanism* for that remaining confirmation:
  async, batched, non-blocking, multi-stream-safe.