# Semantic approval without Lean literacy — the Plain-English Anchor

> **Your map if you do NOT write proofs:** see
> `docs/STATEMENTS/HUMAN_REVIEW_LAYERS.md`. It adds the third layer —
> the **probe checklist** (`tooling/gates/probe_check.py`) — which replaces
> "compare two English sentences" with 3–5 tiny single-choice probes you can
> answer with Numberphile/Computerphile-level intuition. The process here
> (Layers 1–2 + gates) is the full pipeline; HUMAN_REVIEW_LAYERS.md is the
> operator's manual for the human in it.

**Audience:** the project owner (not Lean-literate). **Purpose:** how the human
approves the *meaning* (semantics) of Lean statements and incremental barrier
claims without reading Lean code, and how agents prove that meaning is
non-vacuous. This is the operationalized form of Gates 3/4/5 from
`docs/ARCHITECTURE.md` and the validation-suite requirement
(`docs/STATEMENTS/ValidationSuite.spec.md`).

The short version: **you never approve Lean. You approve English.** The Lean is
machine-checked (build + hygiene + vacuums + `#print axioms`); the *meaning* is
checked by two independent English translations that must agree, plus concrete
examples you can reason about in plain words. If the two translations disagree,
the claim is blocked until they converge. You are the tiebreaker only when the
two translations agree.

---

## The core principle

A Lean proof has two independent properties:

1. **It checks** (the kernel + gates accept it) — *machines* verify this.
2. **It means the intended thing** (the English claim it encodes) — *this is
   what you must approve, and you can do it without reading Lean*.

The failure mode this architecture blocks (Pattern A in
`docs/FAILURE_AUDIT.md`) is a *checking* proof of the *wrong* statement. The
defense is not "read the Lean harder" — it's **two independent translations
that must agree, plus concrete examples**.

---

## The process (for a new statement or barrier claim)

Every semantic claim passes through these stages. The agent drives; you approve
at exactly the points marked **YOU**.

### Step 0 — Claim is filed
A task/issue is `status:available` with a one-paragraph **Summary in plain
English** (the informal claim) and a **Definition of done**. This paragraph is
the seed of the English anchor — it should say clearly, in words:

- *quantifier words*: "there exists an oracle…", "for every language…"
- *the classes/objects involved*: "P^A and NP^A", "a circuit family", "a proof
  in the Frege system"
- *the relation*: "are equal", "are not equal", "is contained in", "is
  computable in time T"

> **YOU:** read just this paragraph. Does it state the claim you *want* formalized?
> If yes, it becomes the frozen informal anchor. If no, edit the paragraph — do
> NOT touch any Lean.

### Step 1 — Two independent renderings (Gate 3)
Two **different** agents (or agent + a second pipeline) each write the Lean
statement *independently* from the English anchor. They are isolated — neither
sees the other's Lean. Then a third check proves the two Lean statements are
logically equivalent (or one is derivable from the other).

> **YOU:** nothing. This is machine/agent work.

### Step 2 — Two independent read-backs (Gate 4) — the part you DO approve
Two **different** translation passes each read the (frozen) Lean statement and
write an English sentence that means *exactly* what the Lean says — not what it
should say, but what it *does* say. These two read-backs are compared:

- **They agree** → the agreed English is the **Plain-English Anchor**. Show it
  to you. → **YOU:** read the Anchor. Compare it against Step 0's informal
  claim. If they match — approve. If they differ — the formalization is
  *wrong* (or the informal claim was), and you say *what* differs in English;
  the agent revises and restarts at Step 1.
- **They disagree** → the claim is **BLOCKED**. Disagreement between two
  independent read-backs is the machine's way of telling you "something is
  ambiguous." The agent resolves (revises the Lean, or both read-backs are
  re-run) until they converge. **You are never asked to choose between two
  conflicting translations** — disagreement is a defect, not a decision for you.

### Step 3 — Concrete examples (validation suite)
For each definition with a "must-prove / must-refute" pair, the agent writes
**small, concrete, English-checkable examples**:

- *must-prove*: "For the oracle that answers **yes** to everything, membership
  of `L` in class C **should** hold for language `L = all strings`. Check it."
- *must-refute*: "For the same oracle, **no** membership claim should follow for
  the *empty* language without a machine. Check it."

> **YOU:** read the examples in English. Does each one state the outcome you
> *expect* in words? Approve the expectations. The *machine* then checks the
> expectation actually holds in Lean. This is the "does the definition constrain
> anything?" test — a definition that passes all must-prove/must-refute pairs is
> not vacuous.

### Step 4 — Barrier triage (Rung 5)
Any P-vs-NP-shaped claim goes through `#barrier_check`. The verdict is English:

- **"DEAD: this proof relativizes"** → the claim cannot resolve P vs NP.
- **"Inconclusive"** → it may (or may not) — not ruled out by the barrier.

> **YOU:** read the verdict. If a claim you care about is DEAD, it is wasted
> effort — do not invest further in it. This is the demand-pull artifact.

### Step 5 — Done = gate evidence
The done comment on the issue must include, in English:

1. The **Plain-English Anchor** (the agreed read-back from Step 2).
2. The **gate commands and their outputs** (hygiene, vacuity, `#print axioms`,
   and the `#barrier_check` verdict).
3. The **concrete examples** and whether each held.

> **YOU:** if any of these three is missing, the claim is **not done** — it is
> not a trust failure of the proof, it is a *process* failure. Request the
> evidence. This is your checklist — every "done" should answer these in
> English, every time.

---

## The one-page human checklist (print this)

For **every** claim you are asked to approve, you need only answer:

1. **Does the English summary state the claim I want formalized?** (Step 0)
2. **Does the agreed read-back (Anchor) say the same thing as the summary?**
   (Step 2) — if the Anchor says "for all oracles" but you wanted "there exists
   an oracle", that's a fail.
3. **Are the concrete examples' expected outcomes what I expect?** (Step 3)
4. **What did `#barrier_check` say?** (Step 4) — DEAD means stop investing.
5. **Is the gate evidence present?** (Step 5) — missing evidence = not done.

You never need to: read Lean, judge a proof step, or resolve a disagreement
between two translations. Agents must not place those on you.

---

## What agents must NEVER do

- **Never ask the human to adjudicate two conflicting read-backs.** Disagreement
  is a defect to fix, not a decision to delegate. (This is the single most
  important rule for protecting a non-Lean-literate approver.)
- **Never present a bare Lean theorem for "approval."** All approval is via the
  English Anchor, the examples, and the gate evidence.
- **Never mark a claim done with a missing Plain-English Anchor, missing gate
  evidence, or unresolved must-prove/must-refute.**
- **Never let the same agent that wrote the Lean also be the sole read-back
  author** — the whole point is independence (Gate 3/4).

---

## Status

2026-09-06 — process documented AND tooled (harness landed). Current state:
- **Gate 4 harness tooled:** `tooling/gates/readback.py` runs two independent
  translators (deterministic skeleton + pluggable LLM), requires agreement,
  blocks on disagreement, never escalates to the human as a choice.
  `tooling/gates/lean_readback.py` is the deterministic half; unit tests in
  `tooling/gates/tests/test_readback.py` (stdlib, no secrets) — wired into CI
  + a no-secret read-back smoke step.
- **Tier-2 axiom check in CI:** `tooling/gates/axiom_check.py` runs in CI;
  asserts only Mathlib-standard axioms, no `sorryAx`.
**Lean-side automation (2026-09-06):** `tooling/gates/statement_lint.py`
classifies a statement's shape (quantifiers, relations, oracle-dependence,
class constants) mechanically from the Lean syntax — the probe *facts* of
Layer 3 are machine-derived, so the human does not answer probes. The human
step reduces to ONE confirmation per statement: does the machine's English
summary of what the Lean says match the intention? (see HUMAN_REVIEW_LAYERS
"Can't we just use Lean itself?" for why that hop is irreducible — Tarski.)

Remaining gaps (tracked as issues):
1. **Gate 3 dual-rendering harness — TOOLED (2026-09-06):**
   `tooling/gates/dual_render.py` (`self` = CI-safe single-rendering check;
   `check` = machine-verified equivalence of two independent renderings via
   Lean rfl/simpa/simp, with a parameterized ∀-quantified fallback). The
   `check` mode's honest contract: equivalence is only trusted when Lean
   mechanically closes the IFF; otherwise it BLOCKS pending a real proof.
   The second-independent-rendering *author* (human or LLM) is still the
   input requirement for a true dual pass — CI self-checks one rendering.
2. **LLM translator integration** — `readback.py` calls an LLM only when
   `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` is set; wiring a provider into CI
   requires a secret, which is a maintenance decision (see issue `read-back
   LLM integration`).