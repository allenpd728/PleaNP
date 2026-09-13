# Gate REVIEW notes — clean modules (issue #56)

> **Purpose.** A resolution record for the non-zero `REVIEW` items the
> Tier-1 gate scanners surface on the repo's "clean" modules
> (`Oracle.lean`, `OracleComplexity.lean`, `OracleSmoke.lean`,
> `BarrierVerdictB.lean`). Each item below was verified against the
> repo tree; the disposition is **no-action** (option (c) of issue #56):
> the clean modules stay clean, the scans exit 0, and the REVIEW items
> are demonstrated-intentional. Future scanners/auditors read this
> file instead of re-flagging the same items blind. The GitHub issue
> queue + `git log origin/dev` remain the system of record.
>
> **Sweep lineage:** filed by audit sweep run=20260911-1125-p4np,
> resolved by run=20260913-0942-d946 (issue #56).

## 1. Gate 6 (Tier 1) hygiene REVIEWs — `OracleSmoke.lean` `by decide`

`hygiene_scan.py --prove-stage` reports three `by decide` smells inside
the smoke test's proof bodies:

- `OracleSmoke.lean:92` — `⟨⟨⟨2, rfl⟩, by decide⟩⟩` (accept run: the
  `2`-step bound / timeout comparison)
- `OracleSmoke.lean:109` — `steps_le_m := by decide` (reject run:
  same timeout comparison)
- `OracleSmoke.lean:119` — `exact absurd hOutput (by decide)` (reject
  run: `[true] ≠ [false]` over a concrete two-element Bool stack)

**Verification.** All three are discharges of concrete finiteness /
arithmetic obligations on literal data (`2 ≤ 2`, `[true] ≠ [false]`).
They appear *inside proofs*, not as statement placeholders. The module
documentation (`OracleSmoke.lean` header, "Oracle-sensitivity smoke
test") states the intended check strength explicitly: the accept
direction is closed by evaluation (`rfl`) and the reject direction uses
determinism (`evalsTo_unique_result`) plus evaluation — "the strongest
check short of `decide` over the existential (Cfg contains function
fields, so the ∃ is not decidable)". The oracle-sensitivity claim is
carried by the reachability/acceptance structure, not by the `by
decide`s.

**Disposition.** No-action, demonstrated-intentional. Treated as extra
gate evidence per the scanner's REVIEW contract; no code change.

## 2. Gate 5 (Tier 1b) binder REVIEW — `abstractPVsNP_iff_verdictB` "unreferenced"

`binder_usage_scan.py` flags
`BarrierVerdictB.lean:46` (`theorem abstractPVsNP_iff_verdictB`) as
"referenced by no other scanned declaration". The scanner walks only
the *Lean* declarations in the scanned path set; it does not see the
corpus/churn provenance.

**Verification.** The lemma is the Gate-7 equivalence proof consumed by
the barrier-verdict corpus map:

- `churn/barrier-verdict/matrix.json:8` — `"Equivalent by proved lemma PleaNP.Calculus.abstractPVsNP_iff_verdictB."`
- `churn/barrier-verdict/lemmas.json:2` — `"A|B": "PleaNP.Calculus.abstractPVsNP_iff_verdictB"`

**Disposition.** No-action. The churn matrices are the legit external
reference; the scanner's "unreferenced" is a false dead-code verdict
limited to its scan set.

## 3. Gate 5 (Tier 1b) binder REVIEW — `emptyOracle` "unreferenced"

`binder_usage_scan.py` flags `Oracle.lean:172`
(`def emptyOracle (Q : Type) : Oracle Q := fun _ => false`) as
"referenced by no other scanned declaration". The scanned clean set
(`Oracle.lean`, `OracleComplexity.lean`, `OracleSmoke.lean`,
`Calculus/*`) does not include the module that uses it.

**Verification.** The `P^∅ = P` upstream anchor uses it directly:
`OracleUpstreamP.lean:28` —
`P_A (alpha := alpha) (emptyOracle Q) = { L | sorry }`.
`OracleUpstreamP.lean` is intentionally outside the clean scan set (it
carries the tracked `sorry`s per `docs/SORRY_TRACKER.md`; it is
isolated so `warningAsError` does not cascade).

**Disposition.** No-action. The upstream-anchor module is the legit
reference; the declaration is load-bearing.

## 4. Gate 5 (Tier 1b) binder REVIEW — weakly-constrained witness in `NP_A` (`∃ y`)

`binder_usage_scan.py` flags `OracleComplexity.lean:63` — inside `NP_A`,
the conjunct `M.oracle = hΓ.symm ▸ A` does not mention the existential
witness `y`.

**Verification.** This is correct and intended. In `NP_A`'s membership
body (`OracleComplexity.lean:57-71`), the certificate `y` is load-bearing
through the *next* conjunct, `@AcceptsInTime tm' (alpha × List alpha) h
ea oa M (x, y) (fun n => p.eval n)` — the oracle machine accepts the
pair `(x, y)`. The conjunct that the scanner top-level-splits on is
an `M`-side oracle-wiring statement; the witness appears in the second
conjunct. The scanner only conjunct-splits the top level, so this is a
false positive shape.

**Disposition.** No-action, verified-intentional. The certificate `y`
is load-bearing via `AcceptsInTime M (x, y)`; the docstring above
`NP_A` records this (Flaw C fix carried from the v4 repair).

## 5. Gate 5 (Tier 1b) binder REVIEW — `P_A_subset_NP_A` "unreferenced" (RESOLVED)

`binder_usage_scan.py` previously flagged `OracleComplexity.lean`
(`theorem P_A_subset_NP_A`) as "referenced by no other scanned
declaration" — the scanner sees only Lean declarations, not CI/tooling
name references. **Resolved 2026-09-13 (issue #63 Pass 3):** the new
`RelativizationProof.P_subset_NP_console` theorem *instantiates*
`P_A_subset_NP_A`, so the binder scanner no longer flags it; it is
removed from the register EXPECTED set.

**Historical verification** (why it was noted before resolution). The
theorem was referenced by name from CI and tooling:

- `.github/workflows/ci.yml` — the Gate 6 Tier 2 `axiom_check.py` step
  checks the clean-module theorems (including `P_A_subset_NP_A`) for
  `sorryAx`/non-standard axioms
- `tooling/gates/axiom_check.py` — the checked-theorem list
- `tooling/galaxy/tests/test_galaxy_render.py` — statement-manifest
  render tests
- `lean/PleaNP/Barriers/BoundaryProbe.lean` — in-module consumer

**Disposition.** No-action. CI/tooling name references are the legit
external reference; it is structurally load-bearing (the `P_A ⊆ NP_A`
self-check).

---

## Register (for future scan runs)

| Scanner | Review item | Location | Legit reference / disposition |
|---|---|---|---|
| hygiene (`--prove-stage`) | `by decide` smell ×3 | `OracleSmoke.lean:92,109,119` | Proof-body finiteness discharges, documented in module header; no-action |
| binder | `abstractPVsNP_iff_verdictB` unreferenced | `BarrierVerdictB.lean:46` | `churn/barrier-verdict/matrix.json` + `lemmas.json`; no-action |
| binder | weak witness `∃ y` | `OracleComplexity.lean:69` | `AcceptsInTime M (x, y)` next conjunct; no-action |
| binder | `P_A_subset_NP_A` unreferenced | `OracleComplexity.lean:86` | RESOLVED (#63 Pass 3): referenced by `P_subset_NP_console`; dropped from register |
| binder | `UpstreamPolyTime` unreferenced | `OracleComplexity.lean:40` | `P^∅ = P` compatibility anchor RHS (function→language bridge, OracleTM2Recompose Trap 1; #4/#40 upstream-P work); no-action |
| binder | `equalizing_oracle_statement` / `separating_oracle_statement` (challenge) unreferenced | `Challenges/Relativization.lean` | statement references consumed by comparator JSON pin `lean/ComparatorChallenges/Relativization.json` (proof-root `theorem_names`); no-action |
| binder | `uniform_collapse_contradicted_by_separating` / `uniform_separation_contradicted_by_equalizing` / `no_uniform_resolution_of_p_vs_np` unreferenced | `Barriers/RelativizationProof.lean` | DEC-022 §3.3 proof-work lemmas (issue #66): the BGS barrier-consequence corollaries, consumed onward by #37/#63 assembly — not dead code; no-action |
| binder | `algebrizing_separation_statement` / `algebrizing_equalization_statement` unreferenced | `Barriers/Algebrization.lean` | AW09 v1 statement references (issue #69 Pass 1): consumed by AZ5's proof assembly — not dead code; no-action |
| binder | `size_pos` / `depth_size_le` / `BoolFunc` / `CircuitFamily.sizeOf` / `CircuitFamily.depthOf` / `and2` unreferenced | `Circuits/Basic.lean` | Rung-4 circuit substrate API (issue #71 Pass 1): the typed circuit-family foundation consumed by Pass 2/3 + all Rung-4 lower bounds — not dead code; no-action |
| binder | `consoleOracleHead_computable` unreferenced | `Barriers/RelativizationProof.lean` | Clause-(a) A2 console-oracle leading-bit instance (issue #63 Pass 1, sibling): public proof-work API consumed by A3/A5 — not dead code; no-action |
| hygiene (`--prove-stage`) | `by decide` smell ×3 | `OracleV5Tests.lean:138,155,165` | Same proof-body finiteness discharges as the OracleSmoke items (v5 word-query smoke accept/reject theorems + 2-step bound); no-action |
| binder | `UpstreamPolyTime` unreferenced | `OracleComplexity.lean:40` | Consumed by `OracleUpstreamP.lean` (the P^∅ = P anchor, outside the clean scan set); no-action |
| binder | `atomEqOrNe` unreferenced | `MarkerFuneqAtom.lean:117` | Campaign rendering target — registered in `churn/marker-funeq/renderings/atom.json` (multi_render slot 1) and checked by `dual_render`/`multi_render check`; the scanner sees only Lean declarations, not the campaign workspace; no-action (issue #41) |
| binder | `pointwiseEqOrNe` unreferenced | `MarkerFuneqPointwise.lean:126` | Campaign rendering target — registered in `churn/marker-funeq/renderings/pw.json` (multi_render slot 2) and checked by `dual_render`/`multi_render check`; the scanner sees only Lean declarations, not the campaign workspace; no-action (issue #41) |

**Register changes (2026-09-13, #40):** `emptyOracle` is **no longer
flagged** — the word-query test module (`OracleV5Tests.lean`)
references it (`v5M (emptyOracle V5Query)`), so the binder scanner's
"unreferenced" REVIEW resolved itself. `OracleV5Tests.lean` contributes
3 new hygiene REVIEWs (registered above). The `y`/`P_A_subset_NP_A`
line numbers shifted (v5 substrate #35 rewired `OracleComplexity.lean`).

Expected scan result on the clean set: **0 violations, 8 binder REVIEW
items, 6 hygiene REVIEW items — all register entries above, all
demonstrated-intentional.** (The two challenge-module binder REVIEWs from
`PleaNP.Challenges.Relativization` for the DEC-022 comparator references
are registered in the row above; the challenge module is a statement
reference consumed by the JSON pin, not dead code.)
## 3. Rung-5 soundness + P^∅ anchor REVIEWs (issue #65 / #40)

**Sweep lineage:** run=20260913-1012-uJoS (issue #65), and #40 (v5-word-query tests).

### `OracleComplexity.lean` — `UpstreamPolyTime` "unreferenced"

`binder_usage_scan.py` flags `UpstreamPolyTime` (issue #40) as referenced by
no other scanned declaration. It IS the RHS of the P^∅ = P anchor theorem in
`OracleUpstreamP.lean` (`P_empty_eq_upstream_P_class = UpstreamPolyTime _`) —
which is outside the CI scan set (it is the upstream-P-blocked leaf module).
The oracle-free `TM2ComputableInPolyTime` recharacterization is the
model-consistency anchor (Trap 3); not dead code.

### `Soundness.lean` — the uniformity lemmas "unreferenced"

`binder_usage_scan.py` once flagged the library-level uniformity lemmas
(`relAtom_uniform`, `langAtom_uniform`, `pA_mem_uniform`, `uniform_and`, …
`uniform_exists`, `funeq_uniform`, `funne_uniform`, `transfer_under_ext`,
`sound_verdict_abstract_rev`) as referenced by no other scanned declaration.
They are the **intentional public API** of the Rung-5 `#barrier_check`
soundness module (`docs/STATEMENTS/Soundness.spec.md`, issue #65): each
`UniformInOracle` lemma is the semantic counterpart of one `Relativizing.*`
propagation instance, designed for downstream composition proofs (the class
transfer / BGS `False` once #18/#63 land). Same demonstrated-intentional
pattern as the `BarrierCalculus` propagation instances in §1 above. NOTE:
`pA_mem_uniform` is no longer flagged since #73 Pass 1's
`Classification.classification_uniform` references it.

**Disposition.** No-action. The register (`tooling/gates/gate_review_register_check.py`
EXPECTED) is updated to include these items so the machine-check agrees.

### `MarkerFuneqAtom.lean` / `MarkerFuneqPointwise.lean` — the campaign rendering targets (issue #41)

`binder_usage_scan.py` flags `atomEqOrNe` / `pointwiseEqOrNe` as referenced
by no other scanned declaration. They are the two-candidate **rendering
targets** of the marker-funeq campaign (issue #41): each is registered in
`churn/marker-funeq/renderings/*.json` (multi_render slots) and machine
checked by `dual_render`/`multi_render check` (the campaign reported the two
readings DISAGREE — the intended semantic divergence). The scanner sees only
Lean declarations, not the campaign workspace. Not dead code.

**Disposition.** No-action. The register EXPECTED set is updated to include
these items so the machine-check agrees.

**Register changes (2026-09-13):** the two marker-funeq campaign rendering
targets (`atomEqOrNe` / `pointwiseEqOrNe`) join the register (issue #41);
`UpstreamPolyTime` is registered above (issue #65/#40, as-swept). Binder
REVIEW count on the clean set is 8 (5 original + UpstreamPolyTime + the two
#41 rendering targets).
### `Closure.lean` — the Rung-7 Tier-1 benchmark membership theorems (issue #81)

`binder_usage_scan.py` flags `emptyLang_in_UpstreamPolyTime` /
`univLang_in_UpstreamPolyTime` as referenced by no other scanned declaration.
They are the **public API** of the Rung-7 Tier-1 baseline datapoint
(`lean/PleaNP/Benchmark/Closure.lean`, issue #81 Pass 2): the membership
facts recorded in `docs/BENCHMARK.md` (the baseline run table B1/B2) and
consumed by the benchmark/Rung-9 acceptance tracking. The scanner sees only
Lean declarations, not the benchmark docs.

**Disposition.** No-action. The register EXPECTED set is updated to include
these items so the machine-check agrees.

### `Resolution.lean` — the resolution substrate API (issue #75 Pass 1)

`binder_usage_scan.py` flags the substrate module's building blocks:
- `eval` — **referenced internally** (by `Clause.eval`) but the scanner
  resolves only top-level name references, so it still reports it as
  unreferenced; a genuine false positive. (`var` was in the same class but
  the rewritten `Clause.eval` exposes the reference, so it self-resolved.)
- `simp` — a `@[simp]`-attribute misread as an implicit binder on `not`.
- `Clause.empty`, `CNF.width`, `ResDerivation.width` — the public substrate
  measures. (`ResDerivation.size` self-resolved: the merged scan set now
  resolves it — no register entry needed.)
- `ResDerivation.sound` — the headline soundness theorem (resolution derives
  only entailed clauses).

All are demonstrated-intentional public API of the Rung-4 proof-complexity
substrate, consumed by #75 Pass 2 (the pigeonhole width lower bound) and
#73 (the barrier classification).

**Disposition.** No-action. The register EXPECTED set is updated to include
these items so the machine-check agrees.

## 4. BGS clause-(a) A2/A3 console-oracle API (issue #63)

**Sweep lineage:** run=20260913-1020-GY2l (issue #63).

`binder_usage_scan.py` flags `consoleOracleHead_computable`,
`consoleLang_mem_P_false` (and the §3.3 barrier-consequence lemmas, already
registered) as referenced by no other scanned declaration. They are the
**intentional public API** of the BGS clause-(a) proof-work module
(`lean/PleaNP/Barriers/RelativizationProof.lean`, `docs/STATEMENTS/
Soundness.spec.md`): the total-computability console oracles (A2) and the
one-query machine's concrete `P^A` memberships (A3) that the full
`NP^A ⊆ P^A` simulation (A3 assembly) and the sandwich (A5) compose. Same
demonstrated-intentional pattern as `OracleSmoke`'s smokes and the
`BarrierCalculus` propagation instances.

**Disposition.** No-action. Registered in
`tooling/gates/gate_review_register_check.py` EXPECTED.
`P_subset_NP_console` (the A4 easy direction, `P_A A ⊆ NP_A A`
instantiated at the console oracle) joins the same register: it is the first
half of the collapse sandwich, consumed by the A5 assembly (issue #63 Pass 3).


## 6. Rung-4 barrier-classification method (issue #73 Pass 1)

`binder_usage_scan.py` flags `Classification.classification_uniform` and
`Classification.oneQuery_classification_uniform` (lean/PleaNP/Calculus/
Classification.lean) as unreferenced. They are the **intentional public
API** of the Rung-4 classification method: the spine theorem
`classification_uniform` (Relativizing-membership ⟹ UniformInOracle, via
the #65 soundness bridge) and the A3 method demo (the #63 one-query
machine's constant-oracle language memberships classified as
oracle-uniform). Each lower-bound family (#72 AC0, #74 monotone, #75
resolution, #76 Williams) instantiates this spine once its proof lands.
Same demonstrated-intentional pattern as the Soundness uniformity lemmas.

**Disposition.** No-action. Registered in
`tooling/gates/gate_review_register_check.py` EXPECTED.
