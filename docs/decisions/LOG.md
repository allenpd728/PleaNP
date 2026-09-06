# Decision log

Chronological record of design decisions. Append-only. Format: `### DEC-0XX` with Date, Status, Scope, Decision, Rationale.

---

### DEC-001

**Date:** 2026-08-18
**Status:** Active
**Scope:** Project structure
**Decision:** PleaNP is a monorepo with a clean, extractable `lean/` lake project, a `tooling/` Python layer, and a `docs/` spec layer.
**Rationale:** The three layers need version alignment (retrieval reads Lean state, gates run against Lean definitions). Monorepo avoids cross-repo coordination overhead at this stage. The `lean/` tree is self-contained so it can be extracted for a Mathlib PR without carrying Python dependencies. The split-pain-later principle: start monorepo, split only when pain demands.

---

### DEC-002

**Date:** 2026-08-18
**Status:** Active
**Scope:** Naming
**Decision:** Project-specific declarations live under the `PleaNP.*` namespace, not `Complexity.*`.
**Rationale:** `Complexity` is being actively designed by the Mathlib community (see `docs/UPSTREAM_TRACKING.md`). Claiming it would conflict with upstream and misrepresent PleaNP's role — we formalize barriers, not complexity classes. The `PleaNP` namespace is honest about scope and avoids collisions.

---

### DEC-003

**Date:** 2026-08-18
**Status:** Active
**Scope:** Computational model
**Decision:** PleaNP imports P, NP, and polynomial-time reductions from upstream Mathlib rather than defining them locally. Oracle machines are defined locally.
**Rationale:** 3–4 active Mathlib efforts are contesting the computational-model design (tracked in `docs/UPSTREAM_TRACKING.md`). Building our own would mean picking a side in an open debate and duplicating substrate work. None of the upstream efforts provide oracle machines, which relativization requires — so that is ours regardless of which model lands.

---

### DEC-004

**Date:** 2026-08-18
**Status:** Active
**Scope:** Integrity architecture
**Decision:** Statement formalization and proof search are isolated in separate pipelines. The integrity gates (statement-freeze, model-consistency, statement-fidelity, read-back, non-triviality, hygiene) run before any proof search.
**Rationale:** The failure audit (`docs/FAILURE_AUDIT.md`) shows the #1 failure mode of claimed P vs NP formalizations is formalizing the wrong statement and trusting the green checkmark (Pattern A). The structural fix is to make it impossible for the same pipeline to both define the statement and search for its proof. This is the project's most important design contribution.

---

### DEC-005

**Date:** 2026-08-18
**Status:** Active
**Scope:** Relationship to Maith
**Decision:** PleaNP is a sibling project to Maith, not a submodule or dependency. PleaNP may reference Maith's findings (notably H6, the retrieval hypothesis) as they firm up, but does not depend on Maith.
**Rationale:** Maith is a representation-research project with open hypotheses; PleaNP is a formalization + integrity project. Entangling them now would couple an open experiment to a build pipeline. The dependency direction is one-way: PleaNP may cite Maith conclusions; Maith does not depend on PleaNP.

---

### DEC-006

**Date:** 2026-08-18
**Status:** Active
**Scope:** Machine-specific configuration
**Decision:** Machine-specific configuration (local Lean toolchain paths, build-server connection details, SSH/access mechanics) is kept out of the public repo, in a gitignored `AGENTS_LOCAL.md` that is referenced but never committed.
**Rationale:** The public repo must be a clean, portable, analyzable artifact. Local setup details are environment-specific and not of public interest. This follows the Maith precedent (`AGENTS_LOCAL.md` pattern).

---

### DEC-007

**Date:** 2026-08-18
**Status:** Active
**Scope:** Build workflow
**Decision:** The Lean build runs on a local machine (not in this authoring environment). The authoring environment maintains the source of truth (the repo); build feedback comes via the local toolchain.
**Rationale:** The authoring environment lacks a Lean toolchain and is ephemeral (reinstalls would be painful, especially Mathlib). A hybrid model — source-of-truth here, build-server local — keeps the repo portable while maintaining a fast edit→compile→goal-state feedback loop. Machine specifics are per DEC-006.


---

### DEC-008

**Date:** 2026-08-18
**Status:** Active
**Scope:** Computational model choice (Rung 2 local piece)
**Decision:** Oracle.lean is built against Mathlib core `Turing.TM1` (PostTuringMachine.lean) as a partial prototype, with a `StepCount` typeclass interface isolating the step-counting dependency. The complexity classes P^A and NP^A are NOT defined yet — they require the step-counting layer that core TM1 lacks (GAP_AUDIT section 1). The `StepCount` interface means when upstream step counting lands (#35366 runN, #33132 EvalsToInTime, or complexitylib reconciliation), only the counting glue changes — not the Oracle type, Cfg, Machine, or step definitions.
**Rationale:** complexitylib was tested and does NOT reconcile under v4.31.0 (23/4033 modules fail with Mathlib API drift; see UPSTREAM_TRACKING section 6). No upstream P/NP model has landed in Mathlib core. Core Turing.TM1 is present in Mathlib v4.31.0 and provides the machine model (Stmt, Cfg, step) needed to define the oracle-machine substrate, but lacks step counting — so the prototype is labeled "Substrate confirmed (partial — oracle machine only; P^A/NP^A blocked on step counting)." This follows decision rule 4 (UPSTREAM_TRACKING): record the chosen model so the next agent knows why TM1 was chosen and that the interface exists to swap it.


---

### DEC-009

**Date:** 2026-08-18
**Status:** Active
**Scope:** Build/CI hygiene enforcement
**Decision:** Hygiene is enforced via (1) per-file `set_option warningAsError true` pragmas in all PleaNP .lean files (making `sorry` a hard build error), and (2) a CI workflow (`.github/workflows/ci.yml`) that runs `lake build` + the hygiene scanner on every push/PR to main. The per-file pragma was chosen over a package-level `moreLeanArgs` flag because the latter caused "unknown configuration option" errors in lake v4.31.0 (the `warningAsError` option needs to be registered by Lean's stdlib, which loads after `-D` parsing). The per-file approach scopes unambiguously to PleaNP files only (not Mathlib), per the spec's section 3 caveat. `lake exe lint` is not available in Mathlib v4.31.0; a `#lint` test file is the fallback path (not yet wired).
**Rationale:** Makes Gate 6 Tier 1 structural (CI-gated) rather than aspirational. A `sorry`-laden PR now fails CI. This catches mechanical failures (sorry, axioms) but not semantic ones (wrong statement, vacuity) — those remain Gates 1-5. See `docs/STATEMENTS/HygieneEnforcement.spec.md`.


---

### DEC-010

**Date:** 2026-08-18
**Status:** Active - Option B chosen (core TM2ComputableInTime, no dependency change)
**Scope:** Step-counting substrate for oracle complexity (P^A / NP^A)

**Decision:** This DEC records the architectural fork in how PleaNP obtains the step-counting layer needed to define P^A and NP^A (the complexity classes the relativization barrier requires). Three options are laid out; the user picks one, and the local agent records the choice and executes.

**Context:** Oracle.lean (DEC-008) is built against core Turing.TM1, which has no step counting. The StepCount typeclass interface isolates this dependency. The question is what instantiates StepCount:

**Option A — Pin v4.30.0, import complexitylib**
- complexitylib (Schlesinger) provides P, NP, BPP, PSPACE, Cook-Levin, a circuit model, Fourier analysis, and multi-tape TMs with step counting. All available today.
- complexitylib is pinned to Lean v4.30.0 / Mathlib v4.30.0. It does NOT compile under v4.31.0 (23 of 4033 modules fail with Mathlib API drift — verified empirically). Under v4.30.0 (its native toolchain), it builds cleanly — no re-verification needed; the failures were v4.31.0-only.
- Pro: unblocks the critical path immediately — P/NP/reductions/Cook-Levin/circuits/step-counting all available. P^A/NP^A, the relativization statement, and a chunk of Rung 4 become runnable now.
- Con: PleaNP (and the sibling maith project) must downgrade to v4.30.0, behind Mathlib core. Accepts a non-Mathlib-core dependency (Apache 2.0, importable as a git dependency — allowed by UPSTREAM_TRACKING rule 3). When a v4.31.0+ complexitylib release lands or #35366 lands, bump back up — the StepCount interface makes this surgical.
- Verdict: highest unblock, highest cost (toolchain downgrade + non-core dependency).

**Option B — Use core TM2ComputableInTime (no dependency change)**
- Mathlib core (v4.31.0) already has a time-bounded computation framework: TM2ComputableInTime (in Mathlib/Computability/TuringMachine/Computable.lean) bundles a TM2 with a time: Nat -> Nat function and a proof it outputs f in at most time(input.length) steps. TM2ComputableInPolyTime is the polynomial-time variant (time: Polynomial Nat). The underlying step-counted relation is TM2OutputsInTime, built on EvalsToInTime (in StateTransition.lean), which tracks a steps count with a steps_le_m proof and has refl/trans (additive step counting).
- A StepCount instance can be written against TM2ComputableInTime's time field, without waiting for #35366's runN or importing complexitylib.
- Pro: stays on core Mathlib, no toolchain change, no external dependency. Consistent with DEC-003 (import, dont define) spirit.
- Con: this is a TM2 (multi-tape) function-computability framing (computing f: alpha -> beta in time), not a language-decision framing with a clean runN counter. Requires recomposing Oracle.lean against TM2 instead of TM1, and bridging from function-computability to language-decision (deciding L: Set alpha). More instance-writing work than Option A, but unblocked now.
- Verdict: conservative, no dependency change, more local work.

**Option C — Local throwaway step counter (stopgap)**
- The local agent writes a minimal fuel-based counter to instantiate StepCount, marked temporary. Unblocks statement-freeze (Gate 1 anchor) for the relativization statement without unblocking the proof.
- Pro: cheapest, fastest, no dependency or toolchain change.
- Con: unblocks only statement-freeze, not proof. The counter is throwaway and will be replaced when a real step-counting substrate lands.
- Verdict: cheapest stopgap, least ambitious.

**Rationale for recording this as a DEC:** The choice changes the project's dependency posture (A: non-core dependency + toolchain downgrade; B: stay on core, more local work; C: stopgap only). This is a genuine architectural fork — the kind the decision log exists for. The user picks; the local agent records the choice and executes.


# DEC-011 entry (to append to docs/decisions/LOG.md)

### DEC-011

**Date:** 2026-08-18
**Status:** Active
**Scope:** Validation discipline and the meta-lesson on honest scaffolding

**Decision:** Adopt a validation-suite requirement for all definitional modules. No definition reaches "frozen" status without compiling a quorum of must-prove lemmas, must-refute lemmas, and smoke tests. Introduce a status ladder (typed → validated → frozen) and forbid the word "anchor" for anything below frozen. Add `binder_usage_scan.py` (Gate 7) as a Tier-1 lethality check. Add a red-team pass on definitions before proving theorems from them. Fix CI staging so `warningAsError` doesn't self-defeat (render-stage vs prove-stage).

**Rationale (the meta-lesson):** The project's `FAILURE_AUDIT.md` Pattern A is usually told as a story about dishonest formalizers editing statements until they compile. The project's own first deliverable showed the more common, harder case: honest scaffolding that compiles, is documented as partial, and is still semantically empty. The v2 Oracle.lean and OracleComplexity.lean had three flaws (DecidesInTime vacuously satisfiable, oracle inert, NP_A certificate vacuous) that passed all Tier-1 scanners (Gate 5 vacuity, Gate 6 hygiene, Gate 2 model-consistency) because the flaws were structural, not syntactic. The defense isn't more honesty checks; it's behavioral evidence, demanded per definition, before anything is allowed to be called an anchor.

The three flaws were:
- **Flaw A:** `DecidesInTime` had no `EvalsToInTime` reachability — the time bound, input encoding, and machine were unused. `P_A` degenerated to "all languages."
- **Flaw B:** `step` delegated to `FinTM2.step` without branching on `queryLabel`. The oracle was inert — `P^A = P^B` for all A, B.
- **Flaw C:** `NP_A` wrapped the whole-language `DecidesInTime` inside `∃ y` — the certificate was vacuous. `NP^A ≈ P^A` by construction.

All three would have been caught by:
1. A must-refute lemma: "P_A A ≠ univ" (countability argument)
2. A smoke test: a machine that queries the oracle and produces different outputs for different oracles
3. A binder-usage scan: flagging unused parameters (`t`, `ea`, `M` in DecidesInTime) and dead binders (`y` absent from its conjunct in NP_A)

The v3 fix (commit `5fd85c6`) addresses the three flaws: step branches on the oracle answer, DecidesInTime references the real step function, NP_A uses a per-input AcceptsInTime predicate. But the process lesson — that behavioral evidence must be demanded per definition — is the lasting fix, recorded here.

**See also:** `docs/VALIDATION_SUITE.md` (the full validation requirements), `tooling/gates/binder_usage_scan.py` (Gate 7), the harsh review (2026-08-18).

---

### DEC-012

**Date:** 2026-09-06
**Status:** Active
**Scope:** Roadmap expansion — three new target components(priority order: Barrier Calculus, Anchor Object, Lower-Bound Compiler).

**Decision:** Adopt the three components as new rungs of the ladder,with rung numbers in `docs/ROADMAP.md`: **Rung 5 — Barrier Calculus** (`Relativizing` typeclass + `#barrier_check` elaborator + THH unit test —the crown jewel — negative-space specification turned into a typechecking question); **Rung 6 — Anchor Object** (machine-checked P/NP model-equivalence across ≥2 upstream formalizations + Levin universal search rendering `P_eq_NP_iff` as an explicit `#eval`-able term); **Rung 8 — Lower-Bound Compiler** (Williams' transfer theorem as a Lean elaborator emitting verified `NEXP ⊄ C` from a verified CircuitSAT algorithm + runtime bound — lower priority than #1, not blocking — under `PleaNP.Circuits`). Former rungs are renumbered(7 Graded benchmark, 9 AI proof-search loop;,  10 Open problems below P vs NP;,  11 Novel barrier-evasion arguments). Existing out-of-scope boundaries unchanged: still not claiming to resolve P vs NP, still deferring P/NP's base definition to upstream Mathlib. The `lean/` tree stays the sole first-class code artifact.

**Levin-search / decision-gap item(logged as a scoped open lemma, NOT a blocker):** Extending the Anchor Object from the *search* version(Levin universal search,`#eval`-able term)to the *decision* version(`P_eq_NP_iff`)as a decision problem needs **(1) self-reducibility** of the search problem,and **(2) a Hutter-style proof-search wrapper** that turns a bounded search into a decision. Neither is in scope of the current rung's "done" definition; both are formulable as a single scoped,publishable lemma as soon as one base computational model lands upstream. Cite this entry when the search⟶decision gap is discussed,so it isn't glossed over nor silently treated as done.



**Rationale:** The project's core bet is negative-space specification: formalize the constraints a proof must satisfy,not the proof itself,. Confirmed as a genuine gap — no proof assistant has formalized these barriers; Coq/Isabelle Cook–Levin formalizations(2021/2023) stalled with no barrier follow-through precisely because they had no demand-pull artifact. `#barrier_check` *is* that artifact — every future claimed-proof triage run creates the pull. The three components are independently valuable and prioritized by leverage(5:the demand-pull device itself; 6: robust statement;  8:the widest eventual force-multiplier,but non-blocking).


---

### DEC-013

**Date:** 2026-09-06
**Status:** Active — Plan B (CI as build oracle) and Plan A (devcontainer) landed 2026-09-06 (commit pending). CI now gates on the clean modules (PleaNP.Basic + PleaNP.Calculus.BarrierCalculus) with a Mathlib olean cache-restore step, because the full-tree `lake build` fails on the pre-existing v3 Oracle.lean debt (see docs/SORRY_TRACKER.md); widen back to `lake build` when the v4 repair lands. The devcontainer (`.devcontainer/`) provides the warm browser environment; the only human action remaining is the one-time "create a Codespace" click (and any later quota decisions).
**Scope:** Persistent toolchain strategy (Lean 4 + Mathlib) without the local M4 box or from-scratch sandbox builds.

**Decision (proposal):** Adopt the community cache as the persistence layer and a warm devcontainer as the environment entry point. Concretely: (1) add a .devcontainer (elan + lean-toolchain pin + lake exe cache get + prebuild of the PleaNP import closure) so any cloud editor (GitHub Codespaces free 60 h/mo, Gitpod free 50 h/mo) or any fresh sandbox converges to a warm state in minutes; (2) keep .github/workflows/ci.yml as the always-free headless build oracle (public repo = unlimited Actions minutes), adding a Mathlib olean cache-restore step; (3) use the lean4web playgrounds (live.lean-lang.org, lean.math.hhu.de) for single-file experiments; (4) compartmentalize by keeping new modules import-light and the calculus layer physically separable as its own mini lake project if needed. Do NOT vendor Mathlib or self-host the olean cache — the community Azure cache is the decentralization already in place, and DEC-003 (import upstream) stays intact.

**Rationale:** Verified in-session (2026-09-06): elan installs in seconds and lake exe cache get restores ~8.5k Mathlib oleans in minutes; with cache warm, a single PleaNP module builds in ~4 s. The expensive, non-persistent step (full Mathlib build) never needs to happen in any environment — the community cache is persistent, free, and public. The M4 box is a convenience, not a prerequisite. Options researched live (Codespaces/Gitpod requirements, mathlib cache mechanics, lean4web, globally-shared-install pattern) — see docs/TOOLCHAIN_SOLUTIONS.md.
