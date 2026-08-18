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
