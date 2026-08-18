# Architecture: the integrity pipeline (the gates)

This document specifies the validation pipeline that makes AI-assisted formalization honest. It exists to structurally prevent the most common failure mode of claimed P vs NP formalizations: **formalizing the wrong statement and trusting the green checkmark** (see `docs/FAILURE_AUDIT.md`, Pattern A).

## Core principle

> **The integrity of a formal proof equals the integrity of its weakest gate.**

The Lean kernel checks the *proof*. The gates check the *statement* and the *process*. These are different trust boundaries, kept separate. A compiling proof of the wrong statement is worse than no proof, because it looks authoritative.

The architectural rule that follows: **statement formalization and proof search must be isolated from each other.** The same pipeline must not both define the statement and search for its proof.

---

## The gate pipeline

Every formal claim passes through these gates, in order. A claim is only trusted if every gate passes.

### Gate 1 — Statement-freeze

The formal Lean statement of the target theorem is committed and human-verified *before* any proof search runs. The proof-search component is structurally forbidden from editing the statement.

**What it blocks:** The classic crank-style "P ≠ NP" proof where the statement is quietly edited until it becomes provable.

**Implementation:** The statement lives in a frozen, version-controlled file. The proof-search tooling has read-only access to it; write access is a separate, human-gated operation.

### Gate 2 — Model-consistency

The statement must be stated over the *agreed, canonical* computational model. It cannot redefine P or NP locally.

**What it blocks:** Redefining `NP` as something weaker, proving the redefined thing, and calling it P vs NP.

**Implementation:** The statement must reference the canonical P/NP definitions imported from upstream Mathlib (see `docs/UPSTREAM_TRACKING.md`), not local overrides. A linter checks for local redefinitions of complexity-class names.

### Gate 3 — Statement-fidelity (the strong one)

Two *independent* formalizations of the same informal statement are produced (by different agents, or human + agent) and checked for logical equivalence.

**What it blocks:** The case where one formalization accidentally encodes a weaker claim. If two independent formalizations disagree, neither is trusted.

**Implementation:** Two formalization passes, isolated pipelines, with an equivalence check. Disagreement blocks the claim and triggers human review.

### Gate 4 — Read-back

Auto-generate an informal English statement *from* the formal Lean statement (formal → informal, the reverse direction), and check it matches the intended target.

**What it blocks:** The statement compiles but means something subtly different from the intended P vs NP.

**Implementation:** A formal-to-informal translator (LLM-based or rule-based) produces a natural-language statement; a human or second model checks it against the intended target.

### Gate 5 — Non-triviality / context

Check the statement isn't a vacuous variant (e.g., `True → P ≠ NP`, or a statement that holds trivially under the chosen axioms) and that its free variables have the intended types.

**What it blocks:** Proving a trivially-true statement and presenting it as the real claim.

**Implementation:** The "modular setup" — each definition (P, NP, reduction, oracle) is a module with a *spec* and a *type*. Statements are type-checked against the right module context. Vacuity checks flag statements that hold without substantive assumptions.

### Gate 6 — Axiom / hygiene

Scan for `sorry`, `admit`, `by decide`-abuse, custom axioms, and `sorry` smuggled in via meta-programs.

**What it blocks:** A "proof" that compiles only because it hides an unproven step.

**Implementation:** A hygiene scanner (LeanFlow and OpenProver already do pieces of this). Cheap and mandatory.

### Gate 7 — Proof (only now)

Run proof search against the *frozen, fidelity-checked* statement. If it finds a proof, the result is only as trustworthy as Gates 1–6 were strict.

**Implementation:** The AI proof-search loop (Rung 6). Its output is a proof term, checked by the Lean kernel.

---

## Trust boundaries

| Boundary | What it checks | Who/what is trusted |
|---|---|---|
| Lean kernel | The proof (every step follows from the rules) | The kernel implementation (small, audited) |
| Gates 1–6 | The statement and the process | The gate implementations + human review of Gates 3–4 |
| Human review | The informal-to-formal mapping | Domain experts |

The key insight: **the statement-fidelity gates (3, 4) must not be AI-driven in the same pipeline as the proof.** That's the structural fix for Pattern A.

---

## How this maps to the rungs

- **Rungs 1–4** build the substrate the gates reference (canonical definitions, barrier theorems).
- **Rung 5** provides tasks to test the gates against.
- **Rung 6** is where Gate 7 (proof search) lives, operating under Gates 1–6.
- **Rungs 7–8** produce claims that must pass the full pipeline.

The gates are not a Rung — they're a cross-cutting concern that applies from Rung 3 onward, whenever a formal claim is made.

## How the gates become operational

The frozen, human-verified statement specs that the gates run against live in `docs/STATEMENTS/` (one per barrier theorem, following a six-part template). The local-agent operating procedure for turning those specs into validated Lean — statement rendering → `lake build` → hygiene scan → model-consistency → read-back → freeze → proof search — is defined in `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md`. That workflow is what makes the gates executable rather than aspirational: the remote authoring agent writes the spec; the local agent (with the Lean toolchain) renders and validates it; the two are separate trust boundaries by design (DEC-007).
