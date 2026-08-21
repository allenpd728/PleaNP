# Playbook: prior groundwork indexed by trigger point

**Purpose.** `PRIOR_ART.md` records *what exists*; `UPSTREAM_TRACKING.md` records *what's contested upstream*. This playbook is the connective tissue: **at each rung / workflow step, which groundwork applies, and what to do with it** (imitate, import, cite, or avoid). It exists so the learnings are pulled at the right step, not rediscovered after a dead end.

**How to use:** when you start a rung or hit a workflow step, look up the row. Do the action *before* building, not after. If the groundwork has moved (a repo updated, a paper landed), update the row in the same commit that changes the plan — this file is only useful if it stays current.

**Rule:** a playbook entry is a *decision input*, not a constraint. "Imitate X" means "read X first and justify any divergence"; it does not mean "copy X blindly."

---

## By rung

| Rung | Groundwork | Action at this rung |
|---|---|---|
| **2 — Computational model / oracle machines** | Mathlib `TM2ComputableInTime` / `TM2OutputsInTime` / `initList` (core, v4.31.0); `RecursiveIn.lean` (unbounded oracle computability) | **Imitate** the `TM2OutputsInTime` composition idiom for reachability; do **not** reuse `RecursiveIn` for time bounds (it has none). Track `UPSTREAM_TRACKING` for the P/NP model — import, never define. |
| **2 — step counting** | Mathlib #35366 (`runN`), #33132 (`FinTM0`/`EvalsToInTime`) | **Watch** — import whichever lands; keep the `StepCount` interface so the swap is surgical (DEC-008/010). |
| **3a — Relativization statement + proof** | Balbach Cook–Levin (Isabelle/AFP); Gäher–Kunze Cook–Levin (Coq, L-model) | **Imitate** their machine-enumeration and step-counting handling for the clause-(b) diagonalization — the two complete Cook–Levin formalizations are proven paths through the finicky parts. **Cite** BGS 1975 as the informal source of truth for Gate 4 read-back. |
| **3b — Natural proofs** | Razborov 1995 (bounded arithmetic); Pich 2015; Jeřábek APC¹; Oliveira–Müller | **Consult for statement strength** — the PV₁/APC¹ vocabulary is the reference for what "constructive / natural" should mean formally, so the barrier isn't stated vacuously or unprovably. **Cite** as prior art (mandatory). **Do not** build the OWF→PRF reduction — hypothesize the PRF (no importable substrate exists). |
| **3c — Algebrization** | Aaronson–Wigderson 2009 (multiquadratic, v1 pinned); ITCS 2026 multilinear strengthening | **Pin v1** to AW09; track the 2026 strengthening as a candidate v2, not part of v1 (prevents formalizing a moving folk theorem). Mathlib finite fields are present — the only missing substrate is the oracle machine (Rung 2). |
| **4 — Circuit lower bounds** | **complexitylib** (Schlesinger): typed circuit model, Cook–Levin tableaux, universal machines, time hierarchy, Fourier subtheory | **Import, don't rebuild** — the single biggest overhead saver. **Blocker:** v4.30.0/v4.31.0 toolchain drift (see `UPSTREAM_TRACKING` §6); reconcile the toolchain first. **Cite** the original lower-bound papers (Håstad, Razborov, Williams) for Gate 4. |
| **5 — Benchmark** | LeanDojo Benchmark 4; MiniF2F | **Benchmark against** LeanDojo Benchmark 4's autoformalization metrics (exact-match < 10%, proof-check < 20%) as the measured threat model for Gates 3–4. |
| **6 — AI proof-search loop** | LeanDojo/ReProver (premise selection); the 2025–26 prover wave (AlphaProof, DeepSeek-Prover-V2, …) | **Build premise selection on LeanDojo/ReProver** or justify divergence. Treat the prover wave as evidence that *search* outpaces *statement integrity* — which is why the gates are mandatory before this rung runs. |
| **7 — Open problems below P vs NP** | Reitwiessner's Williams √-space formalization (Lean Together 2026) | **De-scope** Williams √-space (already targeted); pick Ladner-style structure or derandomization consequences instead. **Track** Reitwiessner's multi-tape + space model as a candidate Rung-2 substrate. |

---

## By workflow step (LOCAL_AGENT_WORKFLOW.md)

| Step | Groundwork | Action |
|---|---|---|
| **0 — Confirm substrate exists** | The rung row above | Before rendering, check the rung's row: is there something to **import** (complexitylib for Rung 4) or **imitate** (Cook–Levin for diagonalization)? If yes, do it now — it changes whether the step is "build" or "wire." |
| **1 — Render the statement** | Bounded-arithmetic vocabulary (3b); AW09 pinned formulation (3c) | State the barrier at the strength the groundwork indicates. For 3b, "constructive" should track the PV₁/APC¹ sense of feasible — not a hand-waved "poly-time." |
| **4 — Read-back (Gate 4)** | The informal source papers (BGS 1975; Razborov–Rudich 1997; AW 2009) | Read back against the *original* statement, not a paraphrase. The §5 "dropping X is a fail" lists in the statement specs are derived from these. |
| **6 — Proof search** | khanukov's bypass-witness *pattern* (not code) | **Adapt the contract idea**: barrier-evasion claims carry their justification as an explicit record field (a type-level obligation), not a comment. Makes unproven obligations un-elidable. |

---

## Anti-patterns this playbook exists to prevent

From the prior-art sweep (`PRIOR_ART.md`, "Closer prior art") — all single-pipeline AI attempts, all failed the same way:

- **Don't assume the barrier as an axiom** (gobbleyourdong's `axiom bgs_exists_equal`). A barrier is only useful if it's *provable* over real classes.
- **Don't define vacuous or oracle-blind classes** (gobbleyourdong's `∧ True`; konard's `def OracleP _ := ClassP`). The lethality scanner (`binder_usage_scan.py`) + the validation suite (`VALIDATION_SUITE.md`) are the mechanical check.
- **Don't write abstract schemes with no machine model** (khanukov's `Relativizing (S : Type u → Prop)` over bare types). A barrier "interface" that can't name an oracle machine can't be proved.
- **Don't run one pipeline for statement + proof** (all of the above). The `dev`→review→`main` flow and Gates 1–7 exist precisely because single-pipeline AI attempts produce compiling-but-wrong artifacts.

---

## Maintenance

- **Update a row when its groundwork moves.** This file is indexed by trigger point, so a stale row sends an agent to the wrong action. The two living inputs are `UPSTREAM_TRACKING.md` (upstream models) and `PRIOR_ART.md` (what exists).
- **Add a row when a new rung gains a usable external substrate.** The test: "would building this from scratch take longer than reconciling the import?" If yes, it belongs here.
- **Do not add a row for groundwork that is only intellectually adjacent** (e.g. bounded arithmetic is cited for 3b/Rung 6, but it is not importable code — it stays a *consult/cite*, not an *imitate/import*).
