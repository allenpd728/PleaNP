# Effort estimate — remaining task inventory to the proof-search frontier

> **Purpose.** A single ledger that records every remaining task on the path to
> Rung 9 (AI proof-search) with its **dependency**, **priority**, and a
> **work-effort estimate** (agent-run sizing), so the "how much is left" and
> "how long will it take" questions are answerable at a glance. This is the
> Part-3 gap fix at the process level: the rungs are outlined, but the *task
> graph* previously lived scattered across issues and design docs.
>
> **System of record:** the GitHub issue queue + `git log origin/dev` remain
> canonical (per `docs/MULTI_AGENT_WORKFLOW.md`). This file is a **cache**
> maintained by sweeps; it may lag the queue. Rows are the newly filed issues
> #62–#83 (2026-09-12) plus the pre-existing BGS substrate queue where a task
> contract exists.
>
> **Sizing convention:** one **agent-run** = one claimed issue under the
> one-claim-per-agent protocol (`docs/MULTI_AGENT_WORKFLOW.md` §Claiming),
> sized to fit comfortably in one agent session. Ranges are
> optimistic → pessimistic. Effort values are judgment calls by a single
> session, not measured throughput — calibrate them against the repo's own
> history (61 issue-runs in the 2026-09-06→12 burst, of which a minority were
> substantive Lean work; the D1 counting lemma took several runs across 4 days).
>
> **Multi-run tasks are Pass-decomposed (2026-09-12).** Every row estimated
> at ≥2 runs carries an explicit **`**Passes:**`** block (Pass 1..n, each =
> one run) in its issue body: #62/#63/#69/#70/#71/#72/#73/#74/#75/#76/#77/#78/
> #79/#80/#81/#82. The design-only rows (#67/#68, 1–2 runs) are single-claim
> by design — their deliverable *is* the decomposition. Per the multi-run
> sizing rule added to `docs/MULTI_AGENT_WORKFLOW.md` §Task definition, an
> issue flips to `status:available` when Pass 1 can start; the claim comment
> says which pass is claimed; the issue stays open until the final pass
> reports full gate evidence. **Do not sum the passes as separate issues** —
> the effort ranges below already estimate the *total* runs across all
> passes; the pass split is about claim-size discipline, not about
> multiplying the row count.

Rows ≤ the BGS milestone and the substrate-critical path do not require
upstream P/NP (PleaNP-local classes suffice per `#18`'s precedent). The
upstream-P clock (Mathlib PRs #35366 / #33132 per `docs/UPSTREAM_TRACKING.md`)
is an **external** dependency for Rung 6 only.

---

## The ledger

**Priority:** H = priority:high (jumps queue), N = normal, X = blocked-needs-input (human/external input first).

| Issue | Rung | Task | Depends on | Priority | Effort (runs) | Status |
|---|---|---|---|---|---|---|
| #4 | 2 | Recharacterize `P_empty_eq_upstream_P_class` w/o oracle-free redefinition | upstream P | H | 1–2 | available |
| #35 | 2 | v5 word-query oracle substrate repair | DEC-024 doc | H | 2–4 | available |
| #40 | 2 | Tests: v5 word-query substrate repair | #35 | N | 1 | b-n-i → avail |
| #62 | 3a | BGS (a) design decomposition (A1–A5) | — | H | 1 | available |
| #63 | 3a | BGS (a) impl: close `exists_equalizing_oracle` sorry (A5) | #62, #35 | H | 2–4 | available |
| #64 | 3a | Comparator challenges: BGS (a)+(b) modules + JSON pins | — (root-adapt at #18/#63) | H | 1 | available |
| #66 | 3a | PaperResults file layout: statement vs proof modules | — | N | 1 | available |
| #18 | 3a | BGS separating-oracle proof path (clause (b), zero-sorry) | #22/#23 chain | H | (see #22/#23) | available |
| #22 | 3a | BGS (b) sub-task 2: diagonalization (D3–D5) | #35 | H | 4–6 | b-n-i |
| #23 | 3a | BGS (b) sub-task 3: assemble (D6) + close sorry | #22 | H | 2–3 | b-n-i |
| #26 | 3a | BGS easy half: U_B ∈ NP^B machine construction | #35 | H | 1–2 | b-n-i |
| #36 | 3a | BGS easy half over repaired substrate (re-scope) | #35 | H | 1–2 | b-n-i |
| #37 | 3a | BGS (b) diagonalization over word-query substrate (D1–D6) | #35 | H | (covers #22+#23) | b-n-i |
| #67 | 3b | Natural Proofs proof-path decomposition (N1–N6) | — (design; N-impl → #35/R4) | N | 1–2 | available |
| #68 | 3c | Algebrization proof-path decomposition (AZ1–AZ6) | — (design; AZ-impl → #35) | N | 1–2 | available |
| #69 | 3c | Algebrization impl: render AW09 v1 + first proof sub-task | #68, #35 | H | 2–4 | available |
| #70 | 4 | complexitylib dependency reconciliation | — | H | 3–6 | available |
| #71 | 4 | PleaNP.Circuits + P/poly + natural-property definitions | #70 | N | 3 | available |
| #72 | 4 | AC⁰ lower bound: parity ∉ AC⁰ via switching lemma | #71 | N | 2 | available |
| #74 | 4 | Monotone circuit bounds (Razborov CLIQUE) | #71 | N | 3 | available |
| #75 | 4 | ProofComplexity resolution width/size (pigeonhole width) | #71 (soft) | N | 2 | available |
| #76 | 4 | Williams transfer: NEXP ⊄ ACC⁰ (non-relativizing existence) | #71, #72/#74 idioms | H | 10–15 | available |
| #73 | 4 | Barrier classifications: techniques are relativizing/natural/algebrizing | #65, #72/#74/#75/#76 | N | 3 | available |
| #65 | 5 | `#barrier_check` soundness: Relativizing ⇒ BGS-relativizing | — | H | 1–2 (abstract) | available |
| #82 | 5 | Rung 5 concrete integration: Relativizing seeds on P_A/NP_A | #35, #65 | N | 2 | available |
| #41/#29/#42 | 5 | funeq/funne marker semantics review (atom vs pointwise) | #30/#3 tests | N | 1–2 | pending review |
| #77 | 6 | Search→decision gap lemma (self-reducibility + Hutter) | upstream P | H | 2–4 | b-n-i |
| #78 | 6 | Levin universal search + `P_eq_NP_iff` #eval-able term | upstream P, #77 | N | 2 | b-n-i |
| #79 | 6 | P/NP model-equivalence anchor across upstream models | ≥2 upstream models | N | 2 | b-n-i |
| #81 | 7 | Graded benchmark: task list + Tier-1 baseline | — (Tier-3 → R4) | N | 2 | available |
| #80 | 8 | Lower-Bound Compiler: Williams transfer as Lean elaborator | #76 | N | 5–8 | available |
| #83 | meta | Consolidated task inventory + effort ledger (this file) | — | N | 1 (doc) | available |

**Statuses:** `available` = claimable now; `b-n-i` = `blocked-needs-input`
(upper-block landed or human/external input required). The BGS "easy half"
has a duplicative pair (#26 vs #36) — sweep per protocol when #35 lands.

---

## Critical path to the first milestone (BGS zero-sorry, #18)

```
#35 (v5 substrate) ──► #26/#36 (U_B ∈ NP^B machine) ──► #37/#22 (D3–D5 diagonalization)
                                                     ──► #23 (D6 assembly + close sorrys)
#62 (clause (a) design) ──► #63 (clause (a) impl) ──┐
                                                     ├──► BGS both clauses zero-sorry (#18 + #63)
#64 (Comparator) ──► #66 (file layout) ──────────────┘
```

Shortest path to the first zero-sorry barrier theorem: **#35 → #26/#36 →
#37/#22 → #23** (≈ 9–17 runs), the #62/#63 fork, and #64/#66 in parallel.
This is the "weeks, not months" item from the Part-3 analysis.

## Critical path to proof search (Rung 9)

Rung 9's dependency note (ROADMAP) requires Rungs 3–4, 5, 6. Mapping to run
counts:

| Block | Runs (opt → pess) | Critical dependency |
|---|---|---|
| Rung 2 substrate + BGS (3a) | 20 → 38 | #35 (v5) |
| Rung 3b Natural Proofs | 15 → 30 | #70 (circuit import) |
| Rung 3c Algebrization | 15 → 30 | #68 design, #35 base |
| Rung 4 lower-bound library + classifications | 45 → 80 | #70, #76 (heaviest) |
| Rung 5 soundness + concrete | 6 → 12 | #65, #82 |
| Rung 6 Anchor Object | 10 → 20 | upstream P (external) |
| **Total to Rung-9 entry (sum of the ledger rows above)** | **61 → 79 runs** (55 → 71 excluding upstream-blocked Rung 6) | upstream P is the only external clock |

> **Ledger-sum method (2026-09-12, authoritative).** The per-block ranges above
> were the *judgment* estimates from Part-3 (phase 1 flush). Now that every
> task carries an `**Effort:`** line and a pass-decomposed `**Passes:**` block
> (airtight rule), the authoritative total is the **sum of the ledger rows**,
> computed live from the issue queue on 2026-09-12:
>
> - Rung 2 = **4–6 runs**, Rung 3 = **22–28 runs**, Rung 4 = **26–34 runs**,
>   Rung 5 = **3 runs**, Rung 6 = **6–8 runs**, Rung 7 = **2 runs**,
>   Rung 8 = **2 runs**. **Grand total (all in-scope) = 65–83 runs.**
> - Proof-search entry (Rungs 2+3+4+5+6, the ROADMAP dependency note):
>   **61–79 runs**, of which **55–71 runs** are unblocked now and **6–8 runs**
>   are the upstream-P-gated Rung 6 slice.
>
> The per-block table above is retained as the conservative planning envelope;
> the ledger sum is the current best estimate. Recompute by summing the live
> issue Effort lines (or `python3 tooling/gates/pass_scan.py` for queue
> health).

---

## Effort-model notes

- **The OpenAI NavierStokesAndEuler surprise is deliberately NOT a yardstick
  for this work.** Its formalization phase (~640K lines in 17h, 2,655 files, 0
  sorries) was clustered-parallel, no human gates, and its discovery phase
  (~10,000 agents / 88h / 130B output tokens) was unconstrained search for an
  unknown construction. PleaNP's work is constrained formalization of known
  theorems (BGS/RR/AW) through the 7-gate pipeline — the Euler/formalization
  end of the spectrum, not the NS end (see `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §4, DEC-022 anti-pattern: precision over parallelism).
- **What IS carried over from the releases** is now protocol-level, not just
  task-level: the iterative pass-sizing rule and the DEC-022/023 gates
  (Comparator + paper-theorem files + proof-intuition/load-bearing audit +
  constraint-net cartography) are codified in `docs/MULTI_AGENT_WORKFLOW.md`
  §Task definition + §Gates (commit `58af8f9`), and the multi-run issues
  carry their `Passes:` blocks. The "17h / 640K-line formalization" figure is
  a *calibration data point* for Rung 7 cost estimates, not a throughput
  target for PleaNP's single-claim gates.
- **Run→token conversion (for cost modeling, not for task sizing):** each
  substantive formalization run spends on the order of 5–20M output tokens
  (Lean compile-loops; far below OpenAI's discovery agents). The full
  ~115–235-run outline is therefore ≈ 0.6B–4.7B output tokens — at GPT-6 Astra
  retail ($50/M out, $10/M in) roughly $0.1M–$1M all-in. Three to four orders
  of magnitude below the NS run's tens of millions; the barrier-calculus +
  gate pipeline is the reason (each constraint is a cheap rejector).
- **Upstream P is the single external risk.** Nothing here controls when
  Mathlib lands a P/NP model (#35366/#33132). Rungs 2/6 and #4/#40 sit on
  that clock. The repo's correct stance — PleaNP-local classes until a model
  lands — keeps the BGS path unblocked by it.
- **Sizing is a hypothesis, not a measurement.** When a task is claimed,
  note its actual run-count in the done comment so this ledger's ranges can be
  refined (this file is maintained by sweeps).