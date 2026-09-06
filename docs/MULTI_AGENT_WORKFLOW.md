# MULTI_AGENT_WORKFLOW.md — GitHub-issue task coordination for PleaNP

How OpenHands agents (and external contributors) find, claim, and complete work
on PleaNP. One task = one GitHub issue. This protocol is adapted from the
**muse** repo's `TASK_WORKFLOW.md` (2026-09-06), which has been battle-tested
for multi-agent coordination under a shared GitHub identity. PleaNP keeps
muse's core mechanics (run-ids, atomic label claims, blockers, sweeps) and
adds PleaNP-specific rules: the **integrity gates** are mandatory for any
formal claim, and **community contributions** (Zulip) enter through the same
issue queue.

> **System of record:** the issue queue plus `git log origin/dev`. Status
> tables in docs (ROADMAP.md etc.) are caches updated by sweeps and may lag —
> check the queue and dev history before concluding work is undone.

## Why this exists

PleaNP's work is inherently multi-agent: the rung ladder (ROADMAP.md) has many
independent, gated tasks, and agents run in parallel against the same repo
under a shared GitHub identity. Without a coordination protocol, agents
double-claim, strand dependents, and lose work at rebase. This file is the
protocol. It is the same pattern that made muse's W/S/P/C/L pipeline work.

## Run-ids

Every agent session generates a **run-id** at session start:
`<YYYYMMDD-HHMM>-<4 random alphanumerics>` (e.g. `20260906-1530-a1b2`). The
run-id appears in every claim comment, done comment, and blocker the session
writes. It is the only way to distinguish claims under a shared GitHub
identity — all agents authenticate as the same account, so labels, assignees,
and author fields cannot tell claims apart. Without run-ids the re-fetch
check in §Claiming has no teeth.

## Task states (labels)

| Label | Meaning |
|---|---|
| `status:available` | Ready to be claimed. All blockers are `done`. |
| `status:claimed` | An agent has claimed it. Claim comment is the heartbeat. |
| `status:done` | Work committed to `dev`. The human reviews on `dev` at leisure; anything needing changes spawns a follow-up task. |
| `status:blocked-needs-input` | Agent could not start or finish; needs human input. |
| `priority:high` | Jumps the work queue (default order is lowest issue number). |
| `community-ready` | Good first contribution for external/Zulip community members. |
| `needs-gate` | Requires integrity-gate review before acceptance (see §Gates). |

## Task definition

Each issue contains:

- **Summary** — what to build, in one paragraph
- **Definition of done** — the observable end state (files written, checks passing, gate evidence)
- **Context** — links to spec sections, prior art, or related tasks the agent needs
- **Blocked by** — native GitHub issue-blocking relationships forming the lineage

**Documentation deliverable.** Every code task produces a `.md` doc alongside
its code: a README in the module's directory (usage, API, dependencies) plus a
test spec in `docs/STATEMENTS/` or `lean/tests/`. The doc is part of the
Definition of Done, not an afterthought.

Sizing rule: one task = completable in one agent run (well under an hour of
work). If a task can't be done in one run, it gets decomposed further before
becoming `available`.

## Dependencies

Dependencies are expressed as GitHub "blocked by" relationships, forming
lineages. A task becomes `available` only when **every** issue blocking it is
`status:done` (merged — not merely in review). Within a lineage, only one task
is ever available at a time.

## Claiming protocol

The claim lock applies to **any issue an agent is actively working** — a task,
a `Tests:` follow-up, or a blocker-resolution — not just tasks.

**One claim per agent at a time.** An agent holds **exactly one**
`status:claimed` label across the entire issue tracker. Finish the claimed
item (commit + close + unblock dependents) before claiming the next. Parallel
agents are safe because **each** agent respects this rule.

1. **Sweep stale claims.** Before selecting work, list all `status:claimed`
   issues. For each, if the claim comment is older than **1 hour** with no
   activity since (no commits, no new comments), the claim is void: remove
   `status:claimed`, restore the prior label, and comment that the work was
   reclaimed (audit trail). A fresh claim comment carrying a run-id that is not
   yours belongs to a live sibling — leave it alone.
1a. **Sweep protocol violations.** An issue carrying two status labels at once
   is in an illegal state. The sweep repairs it: the *older* label wins
   (`blocked-needs-input` outranks `claimed`), the extra label is removed, and
   a comment records the repair.
1b. **Docs coherence sweep.** Check that `README.md`, `AGENTS.md`,
   `docs/ROADMAP.md`, `docs/decisions/LOG.md`, and `docs/SORRY_TRACKER.md`
   agree with each other: if a recently-closed task changed the design, the
   plan, or the task list, the sibling docs must reflect it in the same
   session — a stale doc is a process failure on par with a stale claim.
2. **Pick work.** Any `status:available` issue the agent has enough context to
   start. Default order: lowest issue number first; issues labeled
   `priority:high` jump the queue. Before concluding any work item is undone,
   check `git log origin/dev` and the issue queue — docs tables lag.
2a. **Filing is not atomic — search, file, search again.** Before filing a new
   task, search open issues for its slug. After filing, search again: if a twin
   with a **lower issue number** now exists, close yours as duplicate.
3. **When no task is available, fall through in priority order:**
   - **(a) Open `Tests:` issues.** Claim and complete them one at a time.
   - **(b) Open PRs with unaddressed review comments.** Address each, reply to
     every thread with the fixing commit, mark threads resolved.
   - **(c) Open blockers.** Work through `status:blocked-needs-input` issues one
     at a time; if resolvable, close the blocker and return the task to
     `status:available`.
   - Only when tasks, `Tests:` issues, PR comments, and blockers are all
     exhausted is the queue empty and the session done.
4. **Attempt the claim, then verify ownership.** Whatever the work item: swap
   its current label to `status:claimed` **in one atomic edit** — self-assign,
   and post a claim comment (`claimed by <agent-name> run=<run-id> at <UTC
   timestamp>`). Then re-fetch the issue **and read the latest claim comment**:
   if its run-id is not yours, a sibling won — back off and pick a different
   item.
5. **Do the work; prove the done.** Commit directly to `dev` (no PR — review
   happens retrospectively on `dev`). Swap `status:claimed` → `status:done` and
   close the issue with a comment linking the commits. **Tasks with
   known-answer criteria (conformance counts, gate commands, `#barrier_check`
   verdicts) close only when the done comment includes the gate command and its
   output** — a done claim without evidence is how full maps shipped empty and
   nobody noticed.

   **Concurrent-work rules** (agents run in parallel against `dev`):
   - Pull before you start, and again before you push.
   - On push rejection (non-fast-forward): `git pull --rebase origin dev`,
     resolve conflicts, push again. Repeat as needed.
   - **Rebase revealed a sibling landed the same work?** Compare the two
     implementations: if yours adds nothing, drop it; if yours genuinely
     extends it, merge the two in the rebase. Never push a second copy.
   - **Never force-push to `dev`** — it can destroy a sibling agent's committed
     work.
   - A rebase conflict you cannot resolve confidently is a blocker — file it.
6. **Spec the tests.** Before closing out, write a test spec (in
   `lean/tests/` or `docs/STATEMENTS/`) describing the coverage the work needs.
   If the task introduced a behavior with no existing test coverage, the test
   spec is mandatory. Then file a follow-up GitHub issue titled
   `Tests: <task title>` that links the test spec, labels it
   `status:available`, and marks it `Blocked by` the task just completed.
7. **Unblock dependents.** Before finishing, check the issues that listed this
   task under "Blocked by". For each whose blockers are all now `status:done`,
   label it `status:available` and comment that it is unblocked. Dependent
   tasks do not become visible to the queue on their own.
8. **Iterate.** If review later finds the work lacking, write a new task rather
   than reopening the old one.

## Gates (PleaNP-specific — non-negotiable)

PleaNP's integrity architecture (`docs/ARCHITECTURE.md`) separates statement
formalization from proof search. **No formal claim closes as `status:done`
without passing the gates:**

- **Gate 6 (hygiene):** `python3 tooling/gates/hygiene_scan.py --prove-stage
  <files>` — zero `sorry`/`admit`/`axiom` in a proven claim.
- **Gate 5 (vacuity):** `python3 tooling/gates/vacuity_scan.py <files>` — no
  `:= True`/`↔ True`/`:= none` dishonest placeholders.
- **Gate 2 (model-consistency):** `python3 tooling/gates/model_consistency_scan.py
  <files>` — no local redefinition of P/NP, no `Complexity.*` namespace.
- **Gate 5 Tier 1b (lethality):** `python3 tooling/gates/binder_usage_scan.py
  --allow-unreferenced '^(exists_equalizing_oracle|exists_separating_oracle|smoke_accepts_true|smoke_rejects_false)$' lean/PleaNP` — 0 violations.
- **Build:** the module compiles under `lake build` (v4.31.0 / Mathlib v4.31.0).
- **`#barrier_check`:** any P-vs-NP-shaped claim is triaged with the Rung-5
  elaborator; a **DEAD** verdict means the claim cannot resolve P vs NP.

The done comment must include the gate command + output (see §Claiming step 5).

## Blockers

When an agent cannot start or complete a task (unclear spec, missing context,
ambiguous definition of done), it must not guess:

1. Write `blockers/open_YYYYMMDD-HHMMSS_<short-slug>.md` containing:
   - the task/issue attempted
   - what information is missing
   - what is needed to unblock
2. Label the issue `status:blocked-needs-input` and comment with a link to the
   blocker file.
3. Move on to a different available task — never sit idle on a blocker.

**Blocker quality bar.** Blockers are for spec-level ambiguity — missing or
contradictory information that only the human can resolve. They are not for
implementation choices, which are the agent's to make. Before writing one,
confirm: you read the relevant spec/docs and can cite the exact gap; the
missing information is a *decision*, not a *mechanism*; you state what you
tried and why it was insufficient.

**Nested blockers.** Any claimed work item can be blocked, including a `Tests:`
issue. The exception is blocker-resolution itself: an agent that cannot resolve
a blocker must **not** file a blocker-on-a-blocker and walk away. Instead:
leave the issue `status:blocked-needs-input`, comment explaining what is still
missing, and **flag it to the human in the end-of-session report**.

Resolving a blocker: the human answers on the issue or updates the spec. During
the start-of-session sweep, agents check every `blockers/open_*` file whose
issue has been updated since the file was written; if the blocker is resolved,
the agent renames the file to `closed_YYYYMMDD-HHMMSS_<short-slug>.md`
(appending the resolution), removes `status:blocked-needs-input`, and returns
the task to `status:available`.

## End-of-session report

Before finishing, every agent reports (with its run-id):

- Tasks completed (with commit links), including the gate evidence for any
  known-answer DoDs
- Test specs written (linked `Tests:` issues) and any completed tasks whose test
  follow-up never landed
- Stale claims reclaimed during the sweep
- Protocol violations repaired (issues found with two status labels)
- Duplicate filings closed (twins with lower issue numbers surviving)
- Work dropped at rebase because a sibling landed it first
- New blockers written (with one-line reasons)
- Open blockers still awaiting human input
- Blockers closed during the sweep
- Unresolvable blockers escalated, or **stalled queue** if nothing was workable

## Community contributions (Zulip) — see `docs/CONTRIBUTIONS.md`

External contributors (e.g. from the Lean/Mathlib Zulip) do **not** commit
directly to `dev`. They submit via **pull requests** (the normal GitHub flow),
which are then triaged by an agent into the issue queue, gated, and merged.
Full protocol: `docs/CONTRIBUTIONS.md`.