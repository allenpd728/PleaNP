# Roadmap: the rung ladder

This is the development ladder for PleaNP. Each rung is independently valuable; the project produces a defensible research contribution at every rung, independent of whether the top rung is ever reached.

The honest framing: **the most likely outcome of this program is not "P vs NP solved." It's "a world-class formalized complexity-theory and barrier library, plus honest AI-formalization tooling, plus possibly some progress on open problems one rung below P vs NP."** That is a serious contribution on its own merits.

---

## Rung 1 — Gap audit (current)

**Goal:** A written, domain-by-domain analysis of Mathlib's current complexity coverage versus what the barrier theorems require.

**Deliverable:** `docs/GAP_AUDIT.md`.

**Output:** The spec for Rungs 2–4. Tells us whether each rung is "build from scratch" or "Mathlib is already most of the way there."

**Status:** In progress. The audit also tracks the 3–4 active upstream efforts adding P/NP to Mathlib (see `docs/UPSTREAM_TRACKING.md`), since Rung 2 is upstream-tracked rather than built locally.

---

## Rung 2 — Computational model + canonical P/NP (upstream-tracked)

**Goal:** A reusable, agreed computational model in Lean, with P, NP, polynomial-time reductions, NP-hardness, NP-completeness, and oracle machines as first-class objects.

**Stance:** This rung is *upstream's* problem, not ours. Multiple active Mathlib efforts (tracked in `docs/UPSTREAM_TRACKING.md`) are contesting the right design:
- `Turing.TM1` with fuel-based step counting (Mathlib #35366)
- `FinTM0` bundled type with relational evaluation (PR #33132)
- Machine-free logical definability via `ModelTheory` (descriptive-complexity)
- λ-calculus model L (the Coq precedent — Forster/Kunze)

PleaNP imports whichever lands upstream, rather than picking a side. Our only local requirement: **oracle machines** (a TM with an oracle tape), which none of the upstream efforts provide but relativization requires.

**Status:** Blocked on upstream. The oracle-machine layer is ours to build once a base model lands.

---

## Rung 3 — Formalize the barrier theorems (the novel contribution)

**Goal:** Machine-checked proofs of:
- **Relativization** (Baker–Gill–Solovay, 1975): there exists an oracle A with P^A = NP^A; there exists an oracle B with P^B ≠ NP^B. Therefore any relativizing proof cannot separate P from NP.
- **Natural proofs** (Razborov–Rudich, 1994): under the assumption that one-way functions exist, no natural property can prove superpolynomial circuit lower bounds.
- **Algebrization** (Aaronson–Wigderson, 2008): the third barrier, covering techniques that evade the first two.

**Why this matters:** This is the exact knowledge an AI proof-search system needs encoded to avoid dead ends. A formalized "do not try relativizing/natural/algebrizing techniques" map makes search tractable and honest. None of these is formalized in any proof assistant today — this is open ground.

**Status:** Not started. Depends on Rung 2 (oracle machines, P/NP).

---

## Rung 4 — Formalize lower-bound techniques and their failures

**Goal:** Formalize existing lower-bound results *and* prove within Lean that they are natural/relativizing/algebrizing and therefore cannot lift to P vs NP.

**Coverage:**
- Circuit complexity: AC⁰ lower bounds (parity ∉ AC⁰ via the switching lemma), monotone circuit lower bounds (Razborov).
- Proof complexity: resolution size/width, Frege systems.
- The Williams (2011) result (NEXP ⊄ ACC⁰) — the one known non-relativizing, non-natural, non-algebrizing lower bound — as the existence proof that barrier-evading techniques exist.

**Status:** Not started. Depends on Rung 3.

---

## Rung 5 — Graded benchmark

**Goal:** A set of formalization tasks at increasing difficulty:
1. Textbook complexity (easy)
2. Cook–Levin (medium — already done in Coq/Isabelle, so a reference exists)
3. A recent lower-bound paper (hard)

**Purpose:** Measure AI progress honestly. Also the testbed where representation-retrieval questions (à la Maith's H6) get a concrete evaluation.

**Status:** Not started.

---

## Rung 6 — AI proof-search loop

**Goal:** Premise-selection + tactic-search over the formalized barrier landscape, bounded by the formalized "don't try X" constraints from Rungs 3–4.

**Integrity constraint:** All proof search runs against *frozen, fidelity-checked* statements only. The gates (see `docs/ARCHITECTURE.md`) are mandatory here — this is where the most integrity risk concentrates.

**Status:** Not started. Depends on Rungs 3–5.

---

## Rung 7 — Open problems below P vs NP

**Goal:** With the barrier library + search loop in place, attack problems one rung below P vs NP:
- Improved circuit lower bounds (extending Williams-style arguments)
- Derandomization consequences (if certain lower bounds hold, P = BPP)
- Sharpening the P/NP/intermediate structure (Ladner-style)

Each is independently publishable. None is P vs NP, and that's the point.

**Status:** Not started. Depends on Rung 6.

---

## Rung 8 — Novel barrier-evasion arguments

**Goal:** Only after Rungs 1–7 exist, attempt genuinely novel lower-bound or barrier-evasion arguments. The AI's role is constrained search: "given the formalized barrier map, what proof shapes haven't been ruled out?"

**Honest scoping:** Long shot. The barriers exist precisely because evading them is extraordinarily hard. But even if this rung never succeeds, Rungs 1–7 are a complete, valuable research program.

**Status:** Not started. Depends on Rung 7.

---

## What "done" looks like at each rung

| Rung | Done means |
|---|---|
| 1 | `GAP_AUDIT.md` written and reviewed |
| 2 | Oracle machines formalized; P/NP imported from upstream |
| 3 | Relativization + natural proofs + algebrization compile, zero `sorry` |
| 4 | AC⁰ lower bounds + Williams formalized with barrier-classification proofs |
| 5 | Benchmark suite exists with baseline AI measurements |
| 6 | Search loop solves ≥1 Rung-5 task end-to-end through the gates |
| 7 | ≥1 open problem below P vs NP formally proven |
| 8 | A candidate barrier-evading argument, gate-validated |
