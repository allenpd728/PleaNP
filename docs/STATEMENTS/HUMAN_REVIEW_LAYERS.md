# Human semantic review for a non-proof-writing reviewer

**Audience:** the project owner — intro-level math and CS, a fan of
Numberphile and Computerphile, comfortable with ideas but not with writing
Lean (or writing proofs at all). **Purpose:** this is the map of *how you*
approve the *meaning* of formal claims, without learning Lean or proof
craft.

---

## Do we need another layer of abstraction?

**Yes — and this document is the answer to why.** Here is the honest chain of
reasoning:

1. The machines can already verify "is this proof complete and not vacuous?"
   (hygiene, vacuity, `#print axioms`, `#barrier_check`). That part needs no
   human.
2. The first human layer — the **read-back** — says: *compare the English
   claim we wanted with the English sentence that the Lean actually says.*
   That is real progress, but it still asks you to *spot the difference
   between two sentences*. With intro-level background, the failure isn't
   reading — it's **precision**: you can *feel* that "there exists an
   oracle" and "for every oracle" differ, but can you reliably *know* they
   differ at a glance? For someone who doesn't write proofs, that is a high
   bar, every single time.
3. So we add a **third layer** that removes the "compare two sentences"
   requirement entirely. Instead of judging prose, you answer a **checklist
   of tiny, independent, concrete probes** — each one the kind of fact a
   Numberphile video makes obvious. A claim is approved only when *every*
   probe matches. You are never asked to weigh subtle prose; you are asked
   "is this one fact true?" — and a single wrong answer means the claim is
   wrong.

That third layer is the abstraction you were asking about. It is not "more
papers to read"; it is *less* required skill, because each probe is a single
idea you already understand.

---

## The three layers (what YOU do at each)

| Layer | What verifies | Who | Your level of effort |
|---|---|---|---|
| **1. Mechanical** | sorries, vacuity, axioms, barrier verdict | machines + CI | none |
| **2. Read-back** | the Lean *says* the intended thing | two independent translators agree; you read the agreed English | compare one English sentence to the claim you wanted |
| **3. Probe checklist** | each *tiny fact* the claim needs is true | you answer yes/no per probe | answer 3–5 concrete questions |
| *(Gate 3, machine)* | two independent Lean renderings are equivalent | Lean checks the IFF | none |

The crucial property: **in every layer, you are never the tiebreaker on a
disagreement.** If two translators disagree → blocked, fix it. If a probe
answer is wrong → the claim is wrong, not your understanding. Machines and
agents absorb ambiguity; you only ever confirm single concrete facts.

---

## Layer 3 in practice (the probe checklist)

`tooling/gates/probe_check.py` turns a claim into a checklist. For the real
theorem *P^A ⊆ NP^A for every oracle A*, the checklist looks like this
(see `tooling/gates/specs/pA_subset_npA.json`):

```
claim: for every oracle A, P^A is a subset of NP^A

[q1] Does the claim range over...?
     [ ] there exists an oracle        [x] for every oracle
     hint: "there exists" = we pick a helpful oracle;
           "for every" = must work for ALL, even hostile ones.

[q2] Which direction does the containment go?
     [x] P implies NP   [ ] NP implies P   [ ] both ways (equal)
     hint: "subset" means one-way: everything in P is in NP.

[q3] What is the time bound?
     [x] at most polynomial   [ ] exactly   [ ] none
     hint: "at most" is a ceiling; weaker than "exactly".

[q4] Does the claim assert a witness exists?
     [x] yes, a certificate   [ ] no, universal
     hint: NP = "there exists a short certificate".
```

You answer by picking one option per question. The tool checks your answers
against the claim's *expected* values:

- All correct → the claim's semantics are consistent with the checklist.
- Any wrong → **blocked**, and the tool tells you *which probe* and *what*
  should have been the answer:
  ```
  [x] probe 'q1': expected 'for every oracle' but you answered 'there exists an oracle'
  ```

That single message is the whole contract: you only had to know ONE fact —
"P^A ⊆ NP^A is a *for-every-oracle* claim" — and if you got it wrong, the
claim does not get approved. This is exactly the Numberphile/Computerphile
skill: understanding one crisp idea at a time.

---

## Vocabulary you need (no proofs, no Lean)

Everything outside this short list is the machines' job; you never need more:

- **there exists vs for every** — "we can pick one" vs "it must work for
  all." (Computerphile: ∃ vs ∀.)
- **subset/containment direction** — "everything in P is in NP" (one way) vs
  "P equals NP" (both ways). (Numberphile: P vs NP is about whether the
  direction reverses too.)
- **at most vs exactly** — a ceiling vs a strict requirement.
- **polynomial time** — "time bounded by a polynomial in the input size."
  You already know this from Computerphile; nothing deeper.
- **oracle** — "a magic black box that answers questions in one step." The
  whole relativization barrier is built on this idea, and you have the
  intuition from the barrier videos.
- **certificate / witness** — "a short piece of evidence that proves
  membership" (NP).

That's it. If a claim needs a concept beyond this list, an agent must add a
probe *explaining* that concept in one sentence at this level — never assume
you know it.

---

## Process summary (what you do, end to end)

1. Agent files a claim with an **informal English statement** (Layer 0).
2. Machines run Layers 1 + mechanical Gate 3 (CI). **You do nothing.**
3. The read-back (Layer 2) produces the agreed Plain-English Anchor.
4. An agent generates the **probe checklist** (Layer 3) for the claim.
5. **You answer the probes** (3–5 single-choice questions).
6. A single wrong probe answer → **blocked**, with the specific probe named.
7. All correct → approved at the semantic layer (machines already approved
   the mechanical layer).

You never: read Lean, judge a proof step, or arbitrate a disagreement between
two sources. The system's design guarantee is that any ambiguity lands on the
**machines or the agents**, never on you.

---

## Open questions (tracked)

1. **Probe authoring cost.** Every claim needs a 3–5-probe checklist written
   by an agent. Is that overhead acceptable per claim, or should probes be
   generated automatically from the read-back? (Filed as an issue.)
2. **LLM in CI.** Layer 2 (read-back) and Layer-3 answer *checking* both
   currently work heads-down; wiring an LLM into CI is the open
   maintenance/secret decision (issue #5).
3. **Who writes the "expected" values.** The probes' expected answers come
   from the *formal* claim (the Lean), not from the informal wish. An agent
   must derive the expected values from the Lean so the checklist tests the
   Lean's actual semantics — never the human's recollection of the claim.
   This is a bias-guard: the checklist must reflect what the proof *says*,
   not what we *hope* it says.