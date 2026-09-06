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

## "Can't we just use Lean itself as the validator? Is the human step even necessary?"

**Short answer:** you can automate *almost all* of it with Lean-side linter
rigor — and we now do (`tooling/gates/statement_lint.py`). But there is
**one irreducible human step**, and here is the proof that it cannot be
automated away, plus what you'd lose if you tried.

### What Lean itself can verify (pure code, no LLM, no human)

A statement linter classifies the *shape* of a Lean proposition from its
syntax, with total rigor:

- **quantifier order** — ∀ / ∃ binders (is it "for every oracle" or "there
  exists an oracle"?)
- **relation head** — = vs ≠ vs ⊆ vs ∈ (equality, separation, containment,
  membership)
- **connective skeleton** — ∧ ∨ → ↔ ¬
- **oracle dependence** — does the type mention an Oracle?
- **class constants** — P_A, NP_A, Relativizing, ...
- **axiom hygiene, vacuity, proof existence, `#barrier_check` verdict** —
  already in CI.

`statement_lint.py` does exactly this. It answers the Layer-3 probe questions
(q1 quantifier, q2 direction, q3 bound, q4 existence) *from the Lean text*,
mechanically. So the human does **not** need to answer those probes — the
machine already knows the shape.

### What Lean fundamentally cannot do (the hard floor — a theorem, not a tooling gap)

Lean verifies that a proof proves a *proposition*. The proposition is a term
in the system. But **the informal claim — "I want to know whether P vs NP is
resolvable" — is not a term in the system.** There is no Lean computation
that decides "does this theorem prove the real-world P≠NP?", because the
real-world claim is an *intention outside the formal system*.

This is not a limitation of our tools; it is a theorem (Tarski's
undefinability of truth / the fact that satisfaction is not internal to a
consistent system). Concretely:

- `∃ A, P^A = NP^A` and `∃ A, P^A ≠ NP^A` are both first-class Lean
  propositions. Lean can prove each, verify they are not equivalent, and
  classify their shapes — but it **cannot know which one you wanted**. That
  is an intention, not a term.
- **Gate 3 doesn't buy grounding either:** two renderings being equivalent in
  Lean means they encode the *same formal claim* — not that the formal claim
  is the informal one. Independence catches agent error, not intention error.

### What you would lose by removing the human

**Grounding.** A closed Lean loop is perfectly consistent internally but has
**zero connection to the actual question**. That is exactly Pattern A from
`docs/FAILURE_AUDIT.md` — the failure mode the entire architecture exists to
prevent. The green checkmark would prove *something* is true, but not that it
is the P vs NP result you care about. You would have a perfect, consistent,
self-contained formalization of... an unstated intention.

You would also lose the last defense against *concept-level* substitution
(e.g. a unary alphabet, a partial oracle, a silently weakened quantifier) that
no syntax linter catches because it is a meaning-level change, not a
token-level one.

### The synthesis (what this means in practice)

1. **Automate everything automatizable** — the statement linter now classifies
   the shape mechanically. The probe *facts* are machine-derived.
2. **Keep the human at exactly one hop:** confirm that the machine's English
   summary of what the Lean *says* matches the intention. That is one yes/no
   per statement — the minimum viable human touch, and the only one that
   touches reality.
3. **Never let the human be the tiebreaker** — disagreements are defects for
   machines/agents to resolve, not decisions for the human.

So: the human step is **not** necessary as a probe-answerer (automate that),
but **is** irreducible as a single confirmation — and the loss analysis shows
exactly why removing it would destroy the project's meaning.

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