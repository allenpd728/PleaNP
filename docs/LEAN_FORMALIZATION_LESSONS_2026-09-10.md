# Lessons from the 2026-09-08 Navier–Stokes / Lean releases — and what PleaNP carries over

> **Scope.** On 2026-09-08 two AI-assisted teams released finite-time-blowup results for fluid equations, open-sourcing large Lean 4 formalizations alongside their analytic papers: OpenAI (`openai/NavierStokesAndEuler`, forced Navier–Stokes, ~2,655 Lean files as of 2026-09-10) and Buckmaster–Alpöge (`tristanbuckmaster/fluid_lean`, forced Euler + Boussinesq + affine-core program). This note records (a) the independently-verifiable facts of those releases,(b) what they do and do not establish,(c) the three strategy/architecture/workflow affordances PleaNP adopts (DEC-022),(d) the anti-patterns PleaNP explicitly does **not** copy,and (e) pointers for future sweepsof prior-art rows. It is a *lessons* doc — not a statement spec, not a decision(see `docs/decisions/LOG.md` DEC-022).**The claims below about those repos were checked against the public GitHub API/repo contents on 2026-09-10;they may drift.**

---

## 1. Verified facts (2026-09-10 checkout)

| | Buckmaster–Alpöge `fluid_lean` | OpenAI `NavierStokesAndEuler` |
|---|---|---|
| Claim | Forced-Euler blowup (smooth forcing)+ Boussinesq; affine-core program | Forced Navier–Stokes blowup, every viscosity >0: whole-space (C)+ periodic (D) |
| Lean toolchain | — | Lean `v4.34.0-rc2` + Mathlib `v4.34.0-rc2` (pinned via `lean-toolchain` + lakefile rev), + `Comparator` lake dependency |
| Lean footprint | ~3,748 files (1 commit, 2026-09-08) | ‎2,655 files, ~640.9K lines(2 commits: launch 2026-09-08 + update 2026-09-10) |
| Hygiene | — | ‎0 `sorry`s across the Lean tree;`#print axioms` on the comparator solutions shows only standard axioms (`propext`, `Quot.sound`, `Classical.choice`);`formalization.yaml` declares `sorry_count: 0` |
| Fidelity device | — | **Comparator**: an independent challenge module (`ComparatorChallenges/NavierStokes.lean`,adapted from DeepMind's *Formal Conjectures* Clay-problem formalization) declaring the problem,vs proof-root adapters;JSON pins theorem names + `permitted_axioms`;`lake exe comparator` machine-checks the adaptation. The proof root structurally does **not** import the challenge module. |
| Statement layout | — | The 2026-09-10 push added standalone paper-theorem statement files (`NavierStokes/PaperResults.lean` etc.,imported by the root `NavierStokes.lean`),which are what the comparator solutions + normal build both exercise |
| Known limits | statement↔paper audit not published | `formalization.yaml` itself says `review: status: self-assessed`; no independent statement↔paper audit published (as of 2026-09-10); Clay process (publication + 2 years + general acceptance) not begun |

**Sources:** GitHub API + raw content(`openai/NavierStokesAndEuler` @ `f9e8bc5b`; `tristanbuckmaster/fluid_lean` @ `d0124689`),the Clay Millenium problem description,and press coverage (incl. Quanta, CNN — treated as secondary, the repos as primary).

---

## 2. What these releases establish — and what they don't

**Established (by these repositories):**
- The Lean *formal chain* is sound: the stated Lean theorems (C/D for NS; the Euler blowup) compile,with zero `sorry`s,and `#print axioms` shows only the standard kernel axioms.
- The proof-root statements are *adapted to* an independent formal reference (the Comparator challenge copied from DeepMind's Formal Conjectures):`lake exe comparator` checks the adaptation. This is a machine-checkable statement-fidelity boundary — the same trust-boundary design PleaNP's gates already mandate(Gate 1 vs Gate 7),now proven at ~640K-line scale.

- The constructions are *constructive* in the Lean sense(a candidate + residual estimates),not non-constructive existence arguments.



**NOT established (and why PleaNP must keep its human gates):**
- The **paper↔Lean translation** of the informal Clay problem(C/D)is *not* independently audited yet(the repository itself says "self-assessed").Lean vouchses only for the formal chain;thatching informal↔formal hop is exactly what PleaNP Gates 3–4 (dual-render, read-back, probe review)exist to pin with human-in-the-loop review.

- No global acceptance:Clay's conditions (publication in a qualifying venue,≥2 years,general community acceptance)have not begun to run;prediction markets and commentary agree this is months-to-years out

---

## 3. Three affordances PleaNP adopts (DEC-022

### 3.1 Adopt Comparator-style machine-checkable statement-equivalence for every barrier statement

**What OpenAI did.** Their proof root does not import the problem statement;the *reference* problem statement lives in an independently-sourced challenge module(`ComparatorChallenges/`),and a JSON config pins (theorem names, `permitted_axioms`)so `lake exe comparator` can machine-check that the proof root's theorem names are sound adapters of the reference. The independence is structural:the challenge is copied from an *external* project (DeepMind Formal Conjectures),not written by the same pipeline that proved the result.



**What PleaNP adopts.** For each barrier theorem(and each frozen statement spec),the formal statement PleaNP proves must be checked against an **independent, externally-sourced reference statement**,machine-checkably,with a `Comparator.lean`-style challenge module + `permitted_axioms` pin,per the template in `docs/STATEMENTS/ComparatorChallenge.template.md`. Where no external Lean reference exists(the barriers are new ground — see `docs/PRIOR_ART.md`),PleaNP produces the *first* reference:our `docs/STATEMENTS/*.md` specs are the human-verified informal anchors,and the challenge module for BGS(a)/(b) etc. is authored from a *different* source than the proof root(as `STATEMENTS/` specs are written by thenon-Lean-writing driver per `docs/STATEMENTS/README.md` — the structural independence already exists in the statement-spec channel;this makes it machine-readable.).



**Why.** The single most novel engineering component of the OpenAI release is an independent, machine-checkable statement boundary. PleaNP's dual-render/read-back machinery(Gates 3–4)is already stronger than their single-reference check for the human-facing mapping,but it lacked their machine-checkable *formal* equivalence layer. Adopting it makes Gate 3/4's "two independent renderings"into "two independent renderings **plus** a machine-checkable reference adapter" for every barrier claim. The DOT:the claim is auditable the same way OpenAI's is benchmarkable on first day(anyone can run `lake exe comparator`).



### 3.2 Adopt `formalization.yaml` (v0.4)as the repo's machine-readable statement manifest

**What OpenAI did.** One YAML at repo root drives:source-of-truth paper URLs, `main_results` with `declaration`+`file`+`sorry_count`+`axioms[]`+`comparator_config`, `automation`(method/model/framework),`review.status`("self-assessed"),`alignment`(informal-statement ↔ Lean declaration ↔ module ↔ status)list. CI/tooling cann read this one file to derive what to build andwhat to machine-check.



**What PleaNP adopts.** A `formalization.yaml`(v0.4, schema per mathlib-initiative)at repo root,recording for each formal claim:informal source(paper theorem locator)↔ Lean declaration ↔ file ↔ `sorry_count` ↔ `axioms[]` ↔ `comparator_config`(when available)↔ review status.The manifest unifies the facts today scattered across ad-hoc scripts(`hygiene_scan.py`, `axiom_check.py`, `binder_usage_scan.py`…)andal sorts the Gate-evidence expectation:as of 2026-09-10 the initial manifest covers the already-green modules(PleaNP.Oracles/OracleSmoke/BarrierCalculus/…)— which is the current CI surface —and each new proof slated for freeze adds its row in the same commit(the same rule as `docs/SORRY_TRACKER.md`). The manifest is *declarative data*,not an executable —the gate scanners remain the executables,and a future CI job may *assert* the manifest rows(e.g. `axiom_check.py` against each declared `axioms[]`)**as aspirational follow-up**,not implemented in this commit. YAML cannot be validated in this sandbox (no pyyaml,no lake),so the file ships as raw text — validate with a YAML parser when tooling is available before relying on it.



###3.3 Adopt the standalone-paper-theorem-file layout ("PaperResults pattern")

**What OpenAI did.** Their push of 2026-09-10 added,per paper claim,a standalone Lean file(`NavierStokes/PaperResults.lean`, plus `R3/Theorem.lean`, `PeriodicPaperTheorem.lean`, …)that *states* the result in the paper's theorem vocabulary,imported bythe root,and exercised by both the comparator solutions and the ordinary full build.That makes "is the paper's Theorem 1.1 actually formalized?" a first-class, machine-compiled cut instead of a docstring promise.



**What PleaNP adopts.** A frozen formal claim lives inits own standalone Lean file(imported bya root module,and covered by CI builds + `#print axioms` checks**before** any proof search attaches toit. This is Gate 1 (statement-freeze)rendered as *file layout*,not discipline — and it matches the existing "statement spec → rendered statement file → proof file" split in `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md`.The BGS zero-sorry milestone,#18,should land as`PleaNP/Barriers/Relativization.lean`(statement file,zero-sorry,Comparator-checked)plus a separate proof-only scratch module attached later -- keep them physically separate files from the start.


---

## 4. Anti-patterns PleaNP does **not** copy

- **Do not adopt "publish the raw agent output as the release."** Their first commit was 2,486 files with commit message "."—a human-intelligible *paper* is what makes independent review possible.PleaNP commits per-claim with human-reviewable diffs(per`docs/MULTI_AGENT_WORKFLOW.md`).
- **Do not move to "10,000 agents."** PleaNP's problems(barrier theorems,gate-constrained claims)need *precision over parallelism*:each statement must pass 7 gates;the parallel-search-to-verify-a-PDE construction doesn't transfer to oracle diagonalizations.Keep claim-sized agents.
.
- **Do not formalize P vs NP directly.** 166 pages of analysis ⟹ 640K lines of Lean ⇒ a real P≠NP proof would dwarf any current formalization effort.That is strong evidence for PleaNP's "barrier-library, not P/NP proof" scope decision(README; ROADMAP scope note DEG-012).
- **Do not treat a green `#print axioms` as substituting for human read-back.** It checks the formal chain only;the informal claim(is this actually (C)/(D)?)still needs the human gate(their manifest says "self-assessed";PleaNP's Gates 3–4 stay mandatory).
- **Do not treat the *single* Comparator reference as sufficient** for PleaNP's stronger standard:dual-render requires *two* independent renderings to agree;Comparator is one machine-checkable reference on top — not a replacement for the second rendering.

- **Do not vendor inline deps.** Their challenge inlines code adapted from DeepMind (license-compliant,but one-off);PleaNP imports upstream(DEC-003)and keeps `docs/STATEMENTS/` as the frozen-informal anchor channel.


---

## 5. Why this validates PleaNP's architecture (the meta-takeaway

OpenAI and Buckmaster–Alpöge just executed, at enormous scale, three of PleaNP's core theses: **(1) negative-space/breakdown constructions are where AI+Lean delivers** — their result is a disproof-of-global-smoothness (a "there is no global smooth solution"),which is the *shape* of `P ≠ NP`—a constructive-candidate + residual-estimates machine,something large agent collectives are genuinely good at})**(2) statement-fidelity requires an independent, machine-checkable reference boundary** — Comparator:sproof root doesn't import the challenge,the part TNW called"the part that matters most";PleaNP's gates encode the same separation at smaller scale,and can now add their machine-checkable layer,at **all three are already PleaNP's design DNA**(DEC-012 negative-space bet;Gates 1–7;scope restraint) -- this external validation is the single most valuable take-away:the project is aimed at the right problems. The three adoptions above close the two genuine gaps spotlighted:an independent machine-checkable reference layer(3.1)and a machine-readable statement manifest(3.2)with the file-layout discipline(3.3)that make the existing gates executable at scale.
.


**Playbook/prior-art implications (for the next sweep of `docs/PLAYBOOK.md`/`docs/PRIOR_ART.md`):**
- New **imitate** candidate for Rungs 2–4 rows:the Comparator challenge pattern(`openai/NavierStokesAndEuler/ComparatorChallenges`,2026-09-10)and the paper-theorem-file layout — both live,pinned,zero-sorry exemplars of the statement-fidelity machinery at ~640K lines.

- Rung 7 (benchmark)row should eventually cite `NavierStokesAndEuler` asan external "large-scale AI-built Lean formalization" data point(scale:2,655 files/640K lines; through-put:97h discovery+formalization for 166 pp)for calibrating formalization-cost estimates in PleaNP's benchmark planning.

- The OpenAI `formalization.yaml` automation section(model `GPT-6 Astra`,framework `Codex`)is an example of the "automation manifest" PleaNP mulls for Rung 9 reproducibility — adopt as a *reference format*,not as the exact data(no Astra/Codex here:OpenHands is the model per DEC-021)


---

## 6. Beyond sorry/vacuity: the creativity/authority gates (DEC-023

The releases' deepest lesson for an AI-authority-in-Lean project isn't "0 sorries" or "not vacuous" — it's **the constraint net is what makes creative construction search tractable and non-cheating,and human-legible explanation is what makes its authority real.** Two things the mechanical gates cannot see,which PleaNP has now adopted as creat/authority gates(see `docs/decisions/LOG.md` DEC-023):

1. **Discovery tractability = constraint density compiled into cheap rejectors** — their scale jump (~100 agents/50h Euler disproof vs ~10,000/88h NS)was NOT "bigger compute" but **constraint density**:each dense constraint is a cheap filter rejecting most candidates,so search concentrates on the residual freedom. PleaNP now has a `CREATIVE_PROTOCOL.md` Phase ‎2.5(Constraint-Net Cartography, the executable-filter step:enumerate the independent constraint net,specify an automated rejector per constraint,before creative search)and stacks its proto-rejectors(`#barrier_check`,validation must-refute lemmas,Comparator refs DEC-022,load-bearing-choice audit)This turns "creative search" from "generate-then-pick"(cherry-picking)crank-adjacent into "compile-time-constrained search" whose rejection traces are evidence**

2. **Authority = human legibility,not compilation** — Buckmaster's "AI slop" verdict on a Lean-verified proof,and OpenAI's "self-assessed" manifest,show a machine-checked proof can still fail the authority test if no human can read the reasoning. PleaNP has adopted **(a)** a proof-intuition record per AI-discovered claim(`docs/STATEMENTS/ProofIntuition.template.md`:5-layer plain-words construction,load-bearing audit,perturbation tests,cheap-outs confession,steelman,reviewer checklist——the "explanation" slot the 166-page paper filled)and **(b)** a load-bearing-choice audit in `docs/VALIDATION_SUITE.md`(extending binder-lethality from *definitions* to *proofs*:which choices do the work,internal-mechanism-or-choice-bought,meet the "internal mechanism,externally-perturbable" standard——flag constructions whose conclusion is bought by an exact choice)The no-sorry/no-vacuity gates are necessary,but not sufficient,for a construction to be authoritative——now PleaNP checks *how the construction was found* and *whether humans can own it*,orthogonal to hygiene(Gate 6)and vacuity(Gate 5)**

**Pointer table (where each adoption lives):**

| Adoption | Lives in |
|---|---|
| Constraint-net cartography (Phase 2.5) | `docs/CREATIVE_PROTOCOL.md` |
| Load-bearing-choice audit | `docs/VALIDATION_SUITE.md` §"Load-bearing-choice audit" |
| Proof-intuition record template | `docs/STATEMENTS/ProofIntuition.template.md` |
| Decision record | `docs/decisions/LOG.md` DEC-023 |