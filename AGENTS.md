# AGENTS.md

> Condensed project reference for AI agents working in this repo. Dense by design.
> For human-readable introductions see `README.md`; for the rung ladder see `docs/ROADMAP.md`.

## Project overview

PleaNP is a Lean 4 / Mathlib project that formalizes the **barrier landscape** of computational complexity theory — the meta-theorems (relativization, natural proofs, algebrization) showing which proof techniques provably cannot resolve P vs NP — plus the circuit-complexity and proof-complexity infrastructure those barriers require.

- **Domain:** computational complexity theory (Lean 4 / Mathlib)
- **Core contribution:** the first formalized barrier library + the integrity gates that make AI-assisted proof search honest
- **Deliberate non-goal:** defining P/NP/reductions from scratch (upstream Mathlib's job — see `docs/UPSTREAM_TRACKING.md`)

## Key terms

| Term | Meaning |
|---|---|
| **Barrier** | A meta-theorem proving a class of proof techniques cannot resolve P vs NP |
| **Relativization** | Baker–Gill–Solovay (1975): relativizing proofs can't separate P from NP |
| **Natural proofs** | Razborov–Rudich (1994): natural lower-bound techniques would break OWFs |
| **Algebrization** | Aaronson–Wigderson (2008): third barrier, refining the first two |
| **Gate** | A validation step in the integrity pipeline (see `docs/ARCHITECTURE.md`) |
| **Rung** | A level in the development ladder (see `docs/ROADMAP.md`) |

## The rung ladder (summary)

| Rung | Goal | Status |
|---|---|---|
| 1 | Gap audit of Mathlib complexity coverage | In progress |
| 2 | Computational model + canonical P/NP (upstream-tracked) | Blocked on upstream |
| 3 | Formalize the barrier theorems | Not started |
| 4 | Formalize lower-bound techniques + their failures | Not started |
| 5 | Graded benchmark | Not started |
| 6 | AI proof-search loop (retrieval + gates) | Not started |
| 7 | Open problems below P vs NP | Not started |
| 8 | Novel barrier-evasion arguments | Not started |

## File map

| Path | Contents |
|---|---|
| `README.md` | Human-readable project introduction |
| `docs/GAP_AUDIT.md` | Rung 1 deliverable: Mathlib gap analysis + upstream tracking |
| `docs/ROADMAP.md` | The rung ladder with detail |
| `docs/ARCHITECTURE.md` | The gate pipeline (integrity architecture) |
| `docs/FAILURE_AUDIT.md` | Prior attempts at "formalized P vs NP" and how they failed |
| `docs/PRIOR_ART.md` | Cross-assistant prior-art survey + AI-tooling landscape (validates "no barriers formalized anywhere") |
| `docs/UPSTREAM_TRACKING.md` | Tracking the active Mathlib complexity efforts (currently #1–#8) |
| `docs/STATEMENTS/` | **Frozen, human-verified statement specs (Gate 1 anchors / Gate 4 read-back refs).** One per barrier theorem, six-part template, prose-only (no Lean rendering — that's the local agent's job). Start here when beginning Rung 3. |
| `docs/STATEMENTS/README.md` | Why a non-Lean driver writes the specs; the template; index of the three specs |
| `docs/STATEMENTS/Relativization.md` | Rung 3a spec (Baker–Gill–Solovay 1975) — cleanest first target |
| `docs/STATEMENTS/NaturalProofs.md` | Rung 3b spec (Razborov–Rudich 1994) — OWF as hypothesis, not constructed |
| `docs/STATEMENTS/Algebrization.md` | Rung 3c spec (Aaronson–Wigderson 2008) — AW09 multiquadratic v1 pinned |
| `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md` | The test-as-you-go loop the local agent follows to turn specs into validated Lean (Steps 0–6: substrate check → render → hygiene → model-consistency → read-back → freeze → proof search). **Read before any Lean execution.** |
| `docs/decisions/LOG.md` | Chronological decision log (DEC-0XX) |

## Build and test

**Lean (requires local Lean toolchain — see AGENTS_LOCAL.md, gitignored):**
```bash
cd lean
lake build
lake exe check
```

> Note: exact paths and whether lake is available depend on the local machine.
> See `AGENTS_LOCAL.md` (gitignored, not in this repo).

## Git workflow

```bash
# Commit (identifies as AI agent)
git -c user.name="openhands" -c user.email="openhands@all-hands.dev" commit -m "message"
```

## Conventions

- **Decision log:** Append-only; format `### DEC-0XX` with Date, Status, Scope, Decision, Rationale
- **Namespace:** Project-specific declarations live under `PleaNP.*`, not `Complexity.*` (that namespace is contested upstream — see `docs/UPSTREAM_TRACKING.md`)
- **Mathlib style:** All Lean code follows Mathlib naming and style conventions
- **Gate discipline:** No proof search runs against a statement that hasn't passed the fidelity gates (see `docs/ARCHITECTURE.md`)

## Pitfalls to avoid

- Don't define P, NP, or reductions locally — import from upstream Mathlib (track via `docs/UPSTREAM_TRACKING.md`)
- Don't claim the `Complexity` namespace — it's being actively designed by the Mathlib community
- Don't let the same pipeline formalize the statement *and* search for its proof — that's the #1 failure mode (see `docs/FAILURE_AUDIT.md`)
- Don't trust a green Lean checkmark as proof of correctness *of the statement* — the statement-to-informal mapping is the weak link (read the failure audit)
- Don't cite upstream P/NP numbers without checking `docs/UPSTREAM_TRACKING.md` — the computational model is contested and numbers don't transfer across models
- Don't commit machine-specific configuration (paths, SSH, local toolchain) — that belongs in `AGENTS_LOCAL.md`, which is gitignored
