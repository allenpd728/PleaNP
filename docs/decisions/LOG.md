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
**Scope:** Prior art, rung specs
**Decision:** Conducted a literature review and repo audit to broaden `docs/PRIOR_ART.md` beyond the Lean Zulip, and to sharpen the rung specs in `docs/ROADMAP.md`. Added: (a) cross-assistant survey confirming the three barriers are formalized in *no* proof assistant (Lean/Coq/Isabelle/AFP); (b) the original barrier papers as the informal source of truth for Gate 4 read-back; (c) recent theoretical refinements (ITCS 2026 multilinear algebrization barriers; arXiv:2601.09702 "semi-relativization"; Williams STOC 2025 √-space); (d) two new tracked Lean efforts (Reitwiessner space-bounded, Keßler Mathlib fork) added to `docs/UPSTREAM_TRACKING.md` as #7 and #8; (e) the crypto-substrate finding that no importable OWF/PRF exists; (f) the AI proof-search tooling landscape (LeanDojo/ReProver, AlphaProof, the 2025–2026 prover wave) as Rung 6 context. Clarified rung "done" criteria (Rung 3b OWF-as-hypothesis; Rung 3c pin AW09 v1; Rung 6 reference LeanDojo baselines; Rung 7 de-scope Williams √-space). No rung goals or ordering changed.
**Rationale:** The prior-art doc was Lean-Zulip-centric; its headline claim ("no barriers in any proof assistant") was only verified against one archive. The audit corroborates the claim across the major ecosystems and the AI-tooling landscape, and surfaces two upstream efforts (Reitwiessner, Keßler) and one already-claimed Rung-7 target (Williams √-space) that the rungs must account for to avoid duplication and to pick importable substrates correctly. The rung clarifications make the "done" criteria defensible against the moving barrier landscape (e.g., not formalizing a folk theorem that ITCS 2026 has since strengthened) without rewriting the ladder's goals or dependencies — which the evidence supports as sound.
