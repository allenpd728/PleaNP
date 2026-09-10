# Template: Comparator challenge module for a frozen PleaNP statement

> **Purpose.** Per DEC-022 / `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §3.1, every barrier theorem PleaNP formally claims must be checked against an **independent, externally-sourced reference statement**, machine-checkably — the pattern `openai/NavierStokesAndEuler`'s `ComparatorChallenges/` established (alean-comparator challenge + JSON pinning theorem names and permitted axioms). This template turns a `docs/STATEMENTS/*.md` frozen spec into that layout. The template is a *procedure* for the local agent(per `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md`);it is not itself a statement spec.

---

## 0. Independence rule (read first)

The proof root must **not** import the challenge module;the challenge module must **not** import the proof root. The challenge is the *reference*;the proof root *adapts to* it. Where PleaNP itself authors the reference (as for the barriers — no external Lean reference exists;see `docs/PRIOR_ART.md`),author the challenge from a *different channel* than the one that renders the proof statement:specifically,from the `docs/STATEMENTS/*.md` frozen informal anchor(written by the non-Lean-writing driver per `docs/STATEMENTS/README.md`),and *before* any proof work attaches. The two files will then share no imports,and their theorem names must be machine-checked to align via the Comparator config(§4).

---

## 1. The reference (challenge) module

**File:** `lean/PleaNP/Challenges/<Name>.lean` (e.g. `Relativization.lean`) — a fresh `Challenges/` namespace,physically separated from `Barriers/`.)

**Content:** the frozen problem *statement*,rendered from the corresponding `docs/STATEMENTS/<Name>.md` spec into Lean,with:
- definitions + theorem *types* only — no proofs(any `sorry` here is a permitted placeholder only until the spec's validation suite passes?see `docs/VALIDATION_SUITE.md`).
- a docstring citing the spec file + the original source paper(BGS 1975, RR 1994,or AW 2009),and noting any leaning constants it reuses(per Gate 2,no local redefinitions of `P`/`NP`/`Complexity.*`).
- an explicit note of which informal clause(s)of the spec it encodes((a)/(b)for BGS,etcor),so the adapter alignment in §4 is unambiguous.



**Independence checks(before this module is trusted):**
- `python3 tooling/gates/hygiene_scan.py --prove-stage lean/PleaNP/Challenges/<Name>.lean` — 0 violations(no sorry smuggling into the reference once frozen.
- `python3 tooling/gates/model_consistency_scan.py lean/PleaNP/Challenges/<Name>.lean` — no local redefinitions of complexity-class names.
- `python3 tooling/gates/binder_usage_scan.py lean/PleaNP/Challenges/<Name>.lean` — every binder load-bearing.


## 2. The proof-root adapter (separate file

**File:** `lean/PleaNP/Barriers/<Name>.lean`(the existing rendered statement file — unchanged in role;per§0 it must not import `Challenges/<Name>.lean`).

**Content:** the proof statement expressed in the barrier's own namespace(`PleaNP.Barriers.Relativization`,per DEC-002),with theorem names shaped to attach to the challenge's via the comparator config(§4).The *proof* of the statement gets attached here(or in a later separate proof-only file — see §5),never in the challenge module.



## 3. The comparator JSON

**File:** `lean/ComparatorChallenges/<Name>.json`(mirroring the OpenAI layout,but under the project's own `lean/` tree to keep it with the Lake project).

**Shape:**
```json
{
 "challenge_module": "PleaNP.Challenges.Relativization",
 "solution_module": "PleaNP.Barriers.Relativization",
 "enable_nanoda": true,
 "theorem_names": [
 "PleaNP.Barriers.Relativization.exists_equalizing_oracle",
 "PleaNP.Barriers.Relativization.exists_separating_oracle"
 ],
 "permitted_axioms": [
 "propext",
 "Quot.sound",
 "Classical.choice"
 ]
}
```
`permitted_axioms` must match what `axiom_check.py` (Gate 6 Tier 2) allows;if a theorem legitimately needs more(next-to-no for the barriers — they are provable over machine-grounded classes),extend both lists in the same commit with a `docs/decisions/LOG.md` note.



## 4. Machine-checked alignment (CI

Add (when the Comparator lake dependency exists — aspirational until then):
```sh
lake exe comparator lean/ComparatorChallenges/<Name>.json
```
The command must pass for the claim to be Gate-1/3/4 sufficient:it machine-verify that each named theorem in the proof root is a valid adapter of the named reference statement. Until Comparator is available in the PleaNP lake project,the *aspirational* CI job is a placeholder(no-op) and Gate 3/4 continues to run via `dual_render.py` / `readback.py` 🀰

## 5. Interaction with the existing gates

| Gate | This template's contribution |
|---|---|
| 1 — Statement-freeze | The challenge module *is* the frozen statement,separate from any proof work(§1) |
| 2 — Model-consistency | Independence checks in §1.D;no local redefinitions in either module;both reuse the upstream/`PleaNP` canonical objects(BGS oracles from `PleaNP.Oracles`,etc.) |
| 3 — Statement-fidelity | `lake exe comparator` machine-checks proof-root theorem names ↔ challenge;two independent renderings(`dual_render.py`)still required top pin the informal mapping -- Comparator adds a formal reference,not a replacement |
| 4 — Read-back | Read back from the challenge module(which encodes the `docs/STATEMENTS/*.md` anchor)against the original paper,same sentence failure criteria |
| 5 — Non-triviality | The spec's §5 "dropping X is a fail" items are inherited by the challenge(no vacuous weakening introduced at the challenge layer;or a vacuous challenge convicts via `vacuity_scan.py`) |
| 6 — Hygiene/axioms | `permitted_axioms` in the JSON == `axiom_check.py` allowance;0 `sorry`s in both modules for a frozen claim |
| 7 — Proof | Attaches only to the frozen, comparator-checked statement file(§2),never to the challenge(§1) |

---

## 6. Definition-of-done for applying this template

1. `lean/PleaNP/Challenges/<Name>.lean` exists,compiles,0 sorries(pending the spec's validation suite),and passes the §1.D independence checks. 
2. `lean/PleaNP/Barriers/<Name>.lean` exists(naming/adaption to the challenge),does not import the challenge. 
3. `lean/ComparatorChallenges/<Name>.json` pins theorem names + `permitted_axioms`,matching `axiom_check.py`. 
4. `lake exe comparator lean/ComparatorChallenges/<Name>.json` passes(if Comparator available;else documented placeholder + dual_render/read-back evidence suffices)
5. The `formalization.yaml` row for that declaration is added/updated in the same commit(same rule as `docs/SORRY_TRACKER.md`).
6. The claim passes Gates 2/4/5/6(as now scanned in CI)and human read-back before any proof search attaches(Gate 7).

**Status of this template:** Adopted (DEC-022). Not yet applied to any statement(no `Challenges/` dir, no comparator JSON yet;and the `Comparator` lake dependency is not yet in `lakefile.toml`;see `docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md` §3.1 for the phased intent).