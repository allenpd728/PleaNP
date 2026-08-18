# Statement specs (Gate 1 frozen statements) — index

This directory holds the **frozen, human-verified informal-to-formal specifications** for each theorem PleaNP aims to prove. Per the integrity architecture (`docs/ARCHITECTURE.md`, Gate 1 — statement-freeze), the formal Lean statement of any target theorem is committed and human-verified *before* any proof search runs, and the proof-search component is structurally forbidden from editing it.

## Why these docs exist (and why a non-Lean-writing driver writes them)

The failure audit (`docs/FAILURE_AUDIT.md`) establishes the project's #1 lesson: **formalization does not confer correctness of the statement-to-informal mapping.** A compiling proof of the *wrong* statement is worse than no proof, because it looks authoritative. The structural fix is that the person who pins the statement must *not* be the person (or pipeline) that later searches for its proof.

This is why these specs are written by the project driver in plain complexity-theoretic English, pinned to the original source papers, *before* any Lean is touched: they are the human-verified anchor that the formal Lean statement must be read back against (Gate 4 — read-back). Writing them is not busywork; it is the architecturally correct first move and the highest-leverage no-Lean task in the project.

## Structure of each spec

Each statement spec follows the same template:

1. **Informal statement** — the theorem as stated in the source paper, verbatim or close-paraphrased, with the exact citation.
2. **Dependencies** — every definition the statement relies on (e.g. `P^A`, `NP^A`, oracle, polynomial time), each traced to where it must come from (upstream Mathlib, a tracked effort, or PleaNP-local).
3. **Formalization target** — the precise Lean statement shape (names, quantifier order, type of the oracle), pinned to a *dated* version of the informal theorem to avoid formalizing a moving folk theorem.
4. **Gate mapping** — which integrity gates (`docs/ARCHITECTURE.md`) apply, and what each one checks for *this* statement specifically.
5. **Read-back check (Gate 4)** — the natural-language sentence that an auto-generated read-back of the formal Lean statement must match; disagreement blocks the claim.
6. **Prior art / references** — the source papers and the closest existing formalizations (from `docs/PRIOR_ART.md`), with where they stop.

For the **operating procedure** the local agent follows to turn these specs into validated Lean (statement rendering → `lake build` → hygiene scan → model-consistency → read-back → freeze → proof search), see [`LOCAL_AGENT_WORKFLOW.md`](./LOCAL_AGENT_WORKFLOW.md).

## Index

| Spec | Barrier / substrate | Rung | Status |
|---|---|---|---|
| [`Oracle.lean.spec.md`](./Oracle.lean.spec.md) | Oracle-machine substrate (PleaNP-local) | 2 (local piece) | v1 built (TM1, partial); §4 superseded by TM2 recompose |
| [`OracleTM2Recompose.spec.md`](./OracleTM2Recompose.spec.md) | Oracle.lean v2 recomposition against core TM2ComputableInTime (DEC-010 Option B) | 2 (local piece) | Draft — spec; local agent's job |
| [`Relativization.md`](./Relativization.md) | Baker–Gill–Solovay (1975) | 3a | Draft — scaffold |
| [`NaturalProofs.md`](./NaturalProofs.md) | Razborov–Rudich (1994) | 3b | Draft — scaffold |
| [`Algebrization.md`](./Algebrization.md) | Aaronson–Wigderson (2008) | 3c | Draft — scaffold |
| [`HygieneEnforcement.spec.md`](./HygieneEnforcement.spec.md) | CI hygiene enforcement (sorry-as-error + linters + CI) | cross-cutting | Draft — spec; local agent's job |

**Order of work** (per `docs/GAP_AUDIT.md` prioritization): `Oracle.lean.spec.md` first (the unblocked Rung-2 local piece — no upstream dependency, everything else keys off it) → 3a (relativization, cleanest, depends only on oracle machines) → 3b (natural proofs, depends on circuits + OWF-as-hypothesis) → 3c (algebrization, depends on 3a's oracles + finite fields). Relativization is the first *barrier* because GAP_AUDIT §4 calls it "the most foundational barrier and the one with the cleanest formalization target"; the oracle substrate is the *first thing to build* because it's unblocked and the relativization statement waits on it.

The `Oracle.lean.spec.md` is a *design* doc (not a frozen theorem statement like the three barrier specs) — it specifies what `lean/PleaNP/Computability/Oracle.lean` must be, the totality discipline, and acceptance criteria for the local agent.
