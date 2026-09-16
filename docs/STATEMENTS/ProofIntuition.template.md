# Template: proof-intuition record (human-legibility deliverable for an AI-discovered formal claim)

> **Purpose.** DEC-023 / `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §5: the authority of an AI-discovered theorem is *not* established by `#print axioms` or a green build — it requires that humans can testify "I understand this construction and here is why it is right." This template is that testimonial's shape. It is the **explanation** slot that OpenAI filled with its 166-page paper;the NS release's skepticism was never "does Lean accept it?" but "does anyone understand why this construction is right?" — and no `sorry`/vacuity gate can see that gap. This record is **Gate-4-adjacent**:it is read back against the *proof's explanation*,not the statement. Filed per AI-discovered formal claim,reviewed by the human alongside Gate 4,before the claim goes to community review.



## 0. When to fill this in

- A human(or human+agent)can write one *after* a proof exists,and *before* the claim is presented as authoritative.
- If no human can fill it,that is **a finding,not a blocker**:the claim is "formally checked but not yet human-legible" — record that honestly in §7 below,and keep the claim out of authoritative-review slots until it flips.




## 1. Claim being explained

- **Formal statement (declaration + file:**
- **Informal statement(the `docs/STATEMENTS/*.md` anchor:**
- **Discovery context (who/how/when — agent run-id if known;model pass if known:**
- **Formalization context (which pass produced the Lean — SEPARATE from discovery,per DEC-022 §2.5/§5:***
- **Intuition-record author(s) (humans who testify understanding:**
- **Date & review round:**

## 2. The construction in five plain-words layers (the comprehension bridge,`docs/CREATIVE_PROTOCOL.md` Phase 5\)

- **Visceral** — one sentence,child-level analogy.
- **Operational** — what the construction concretely does(step by step,no Lean).
- **Mechanistic** — the causal chain of *why it works*(the load-bearing mechanism -- NOT the choices).
- **Theoretical** — the deeper principle this construction is an instance of.
- **Frontier** — what it implies for the barrier landscape if it holds.



## 3. Load-bearing audit (which choices do the work?is any choice buying the conclusion?)

Per DEC-023 / `docs/VALIDATION_SUITE.md` §"Load-bearing-choice audit":list every *choice* the construction makes(oracle, machine-enumeration ordering, encoding,viscosity-like parameter, force-like data, perturbation scale, etc.),and for each:

- **What it is** — which hypothesis/parameter/free-choice.
- **What it does** — which clause of the conclusion it carries.
- **Internal mechanism?** — is the work done by an internal invariant( adiagonalization scheduler,a residual-cancellation identity,a resource-contradiction),or by the choice itself?
- **Perturbation test** — if you perturb this choice slightly(would the construction survive(and the claim with it)? Or is the theorem *bought* by the exact choice?(For NS what rescued it:the vortex/cascade phenomenon is robust even though the exact theorem needs the fine tuning -- "internal mechanism,externally-perturbable" -- and that combination is what makes it credible. If a choice is load-bearing-and-fragile,flag it loud.


## 4. Why it is not cheating (the "chosen-to-work" confession)

- **What it is NOT relying on** — enumerate the cheap outs this construction was *designed not* to rely on(the classic crank moves:an after-the-fact oracle/force/encoding choice,`True := by trivial`,a vacuous variant,a hidden `sorry`/axiom.
- **Which gate-evidence exists** — the hygiene/vacuity/model-consistency/binder gate outputs for this claim(link the CI artifacts;0 `sorry`s;no local redefinitions;every binder load-bearing,and now:every choice audited)and **which does not yet exist**(e.g., Comparator challenge per DEC-022,if not yet run.



## 5. The single strongest objection,a steelman,and its resolution

State the single strongest objection a smart skeptic would raise to *this construction*(not to the field),state it *more strongly* than they would,then resolve it(note:if you cannot resolve it,that is a finding -- record it;do not paper over it with enthusiasm,per the review-fatigue-protection and honesty conventions.



## 6. What a reviewer should actually check (short checklist)

- **Read layer-2 alone first** — can you follow the construction from §2 without the Lean?
- **Check §3's perturbation tests yourself** — perturb one choice;does the explanation still hold(can you *predict* the failure mode)?
- **Look for §4's cheap outs** — is any "designed not to rely on" move actually doing work in disguise?
- **Ask:"would I believe this explanation if told it was human-written?"** — the authority test the no-sorry/no-vacuity gates cannot see.



##7. Honest status

- **Human-legible today?** (yes/no/partial -- if partial,say which layers are legible and which are not.
- **Findings (if any):** each with:what it is,whether it blocks authoritative review,what would unblock it.


## 8. Interaction with the gates

| Gate | This record's contribution |
|---|---|
| 1 — Statement-freeze | Uses the frozen `docs/STATEMENTS/*.md` anchor in §1;does not restate/replace it |
| 4 — Read-back | Read back against the *proof's explanation*(§2–§6),not the statement;human reviews alongside Gate 4 |
| 5 — Non-triviality | §4's cheap-out enumeration is the vacuity scan extended from statements to *constructions* |
| 6 — Hygiene/axioms | Cites the existing gate artifacts(§4);adds nothing new to scan for -- it is a *human* deliverable |
| 7 — Proof | Filed when a proof exists;the explanation is *pre*-review,not a substitute for the proof or its gates |
| — (creativity/authority, DEC-023) | The load-bearing audit(§3)and the steelman(§5)are the "chosen-to-work" detector -- the authority mechanism at the frontier |


**Status of this template:** Adopted(DEC-023). Not yet applied to any claim(no AI-discovered proof exists yet;awaiting the BGS proof path #18,or Rung 9/11 output.