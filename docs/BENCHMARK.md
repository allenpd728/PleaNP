# Rung 7 — Graded benchmark (task list + Tier-1 baseline plan)

> **Purpose.** The testbed that makes AI progress measurable and that Rung 9's
> proof search is defined against: *"the search loop solves ≥1 Rung-7 task
> end-to-end through the gates."* The benchmark is also where
> representation/retrieval questions (à la Maith's H6) get a concrete
> evaluation, and where the OpenAI NavierStokesAndEuler scale data point
> (2,655 files / 640K lines / "97h for 166pp") calibrates formalization-cost
> estimates (see `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §5).
>
> **System of record:** the GitHub issue queue + `git log origin/dev` remain
> canonical. This file is the **spec + baseline plan** (issue #81, Pass 1);
> the Tier-1 *baseline run* (one textbook task formalized through the gates)
> is Pass 2, tracked separately.

---

## The three difficulty tiers

Per `docs/ROADMAP.md` Rung 7, a graded ladder of formalization tasks:

| Tier | Difficulty | Domain | Reference precedent | Gate posture |
|---|---|---|---|---|
| **1 — Textbook** | Easy | a known complexity-theory fact, formalizable from Mathlib alone | MiniF2F-class / textbook | Full pipeline (Gates 1–7) |
| **2 — Cook–Levin** | Medium | NP-completeness of SAT (the canonical reduction theorem) | Coq/Isabelle reference exists → a cost anchor | Full pipeline + Gate 3 dual-render |
| **3 — Recent lower bound** | Hard | a recent lower-bound paper (e.g. an ACC⁰/Williams-style result) | re-enters Rung-4 territory | Full pipeline + comparator + proof-intuition records |

Gate requirements apply **uniformly** to every tier: statement-freeze (Gate 1)
+ model-consistency (Gate 2) + statement-fidelity / dual-render (Gate 3) +
read-back (Gate 4) + non-triviality (Gate 5) + hygiene/axiom (Gate 6) +
proof (Gate 7). The honest-measurement requirement (issue #81) means a task
is **not done** until it has run the full gate pipeline AND recorded a
baseline run (who claimed it, how many runs, what the gate evidence was).

---

## Tier 1 — Textbook tasks (claimable now; Mathlib alone suffices)

Each row is a claimable issue (one claim = one run per
`docs/MULTI_AGENT_WORKFLOW.md`); the Lean-shape column is the *expected*
statement family, not a committed declaration.

| # | Task | Informal source | Expected Lean shape | Notes |
|---|---|---|---|---|
| T1.1 | Time-hierarchy theorem (single tape, small gap) | textbook; modular in Mathlib | `∃ f g, ...` time-constructibility | Relativizes (Rung 5 DEAD); good first gate-calibration task |
| T1.2 | `NP ⊆ EXP` (or a padded `NTIME ⊆ DTIME` inclusion) | textbook | a `⊆` between time classes over TM2 | Uses upstream Mathlib TM material |
| T1.3 | SAT is decidable in exponential time | textbook | `Decidable`/`Computable` of a SAT decision procedure | Parallels the smoke-test discipline |
| T1.4 | `P` is closed under complement / union | textbook | set/membership closure lemmas | Smallest; the "warm-up" task |

**Tier-1 baseline plan (Pass 2):** one of the above (suggested **T1.4** —
the smallest non-trivial closure fact) is formalized through the full gate
pipeline as the calibration point. The baseline records: issue/run id, runner,
run count, and each gate's evidence. That measurement becomes the
per-task cost prior in `docs/EFFORT_ESTIMATE.md`.

---

## Tier 2 — Cook–Levin (medium)

| # | Task | Informal source | Expected Lean shape | Notes |
|---|---|---|---|---|
| T2.1 | Encode TM configurations as Boolean formulas | Cook–Levin proof | a `def` from `TM2Cfg` to a `CNF`/`Circuit` | reference: Coq/Isabelle formalizations |
| T2.2 | The polynomial-time reduction `L ≤_p SAT` | Cook–Levin proof | a `Computable`/`poly-time` reduction function + correctness | Gate 3 dual-render likely to surface shape ambiguity |
| T2.3 | SAT is NP-complete | Cook–Levin theorem | `NP`-hardness + `NP`-membership of SAT | the tier's headline |

Tier 2 benefits from `complexitylib` (#70) when it lands the P/NP model; the
design can proceed on PleaNP-local classes until then (per #18's precedent).

---

## Tier 3 — Recent lower bound (hard)

| # | Task | Informal source | Expected Lean shape | Notes |
|---|---|---|---|---|
| T3.1 | A concrete circuit lower bound (e.g. parity ∉ AC⁰) | switching-lemma theorem (Rung 4 #72) | a separation statement over `PleaNP.Circuits` | re-enters Rung-4 territory |
| T3.2 | Williams-style transfer (CircuitSAT ⇒ NEXP ⊄ ACC⁰) | #76 / #88–#91 | the transfer theorem as a Lean statement | depends on the Rung-4 library |

Tier 3 depends on the Rung 4 circuit library (#71/#72/#76); the task list is
maintained here as soon as the substrate lands.

---

## Baseline / honest-measurement contract

- **Every task is scored on:** (1) the gate pipeline passed end-to-end (not
  just a compiling statement), (2) a recorded baseline run (runner + run count
  + gate evidence) so the "how long does formalization take" question is
  answered by measurement, not vibes.

### Tier-1 baseline run (issue #81, Pass 2 — 2026-09-13, run=20260913-1930-81b)

**Task:** T1.4 (smallest textbook warm-up) on the existing oracle-free
polytime class `UpstreamPolyTime` (the `TM2ComputableInPolyTime`
function-to-language recharacterization — the P^∅ = P anchor's RHS).

**Deliverable:** `lean/PleaNP/Benchmark/Closure.lean` — zero-sorry,
concrete-machine membership facts:

| # | Fact | Witness |
|---|---|---|
| B1 | `∅ : Set Bool ∈ UpstreamPolyTime Bool` | `constFalseInPolyTime` — a 1-step constant-`false` TM2 machine (pops input, pushes `false`) |
| B2 | `⊤ : Set Bool ∈ UpstreamPolyTime Bool` | `constTrueInPolyTime` — the mirror 1-step constant-`true` machine |

**Honest scope (the measured gap):** the headline T1.4 statements — `P`
closed under `∩`, `∪`, `¬` — are **not yet theorems**. Machine composition
for this class is a Mathlib `proof_wanted` (`Turing.TM2ComputableInPolyTime.comp`,
`Mathlib/Computability/TuringMachine/Computable.lean:284`), and composing a
constant machine with input-dependent `not`/`and`/`or` machines — the general
closure argument — needs it (or a PleaNP-local composition). B1/B2 are the
provable core that does **not** need composition. Closure is the next
calibration step; blocked-on-upstream is tracked, not hidden.

**Gate evidence (all committed with the change):**
- `lake build PleaNP.Benchmark.Closure`: green (1206 jobs).
- hygiene/vacuity/model/unicode scans: 0 violations; binder: 0 violations
  (2 REVIEW items = public benchmark API, registered as demonstrated-intentional
  in `docs/GATE_REVIEW_NOTES.md`).
- `#print axioms` on B1/B2: `[propext, Classical.choice, Quot.sound]` only;
  `axiom_check.py` clean (no `sorryAx`).
- 0 sorries.

**Baseline cost prior:** this is the first calibration datapoint — a
single-claim Tier-1 facts pair on an existing substrate, one agent run.
It feeds `docs/EFFORT_ESTIMATE.md` as the per-task cost prior.

- **Calibration context:** the OpenAI NavierStokesAndEuler formalization phase
  (≈640K lines / 17h / 2,655 files / 0 sorries) was clustered-parallel and
  gate-free — a deliberate **non**-yardstick for PleaNP's single-claim gates
  (see `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §4). The relevant
  baselines for *search* are LeanDojo/ReProver (premise-selection) and
  LeanDojo Benchmark 4's autoformalization metrics (exact-match < 10%,
  proof-check < 20%) as the measured threat model for Gates 3–4
  (see `docs/PRIOR_ART.md`, AI-tooling section).

---

## Registration

- **Rung 9 acceptance target:** the ROADMAP Rung-9 "done" bar is
  *"the search loop solves ≥1 Rung-7 task end-to-end through the gates."*
  This file is that target's scoreboard: tier → task → issue → gate evidence
  → baseline.
- **Effort ledger:** the benchmark tasks feed `docs/EFFORT_ESTIMATE.md` once
  they become claimable issues (the Tier-1 tasks get filed as issues when
  Pass 2 starts).

---

_Last updated: 2026-09-13 (issue #81, Pass 1 — task list + baseline plan).
Pass 2 (the Tier-1 baseline run) is a follow-up that needs the Lean toolchain._