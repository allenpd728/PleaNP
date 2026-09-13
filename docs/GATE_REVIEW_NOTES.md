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

## 5. Gate 5 (Tier 1b) binder REVIEW — `P_A_subset_NP_A` "unreferenced"

`binder_usage_scan.py` flags `OracleComplexity.lean:80`
(`theorem P_A_subset_NP_A`) as "referenced by no other scanned
declaration". The scanner sees only Lean declarations, not CI/tooling
name references.

**Verification.** The theorem is referenced by name from CI and
tooling:

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
| binder | `emptyOracle` unreferenced | `Oracle.lean:172` | `OracleUpstreamP.lean:28` (outside clean scan set); no-action |
| binder | weak witness `∃ y` | `OracleComplexity.lean:63` | `AcceptsInTime M (x, y)` next conjunct; no-action |
| binder | `P_A_subset_NP_A` unreferenced | `OracleComplexity.lean:80` | CI `axiom_check.py` + galaxy tests + `BoundaryProbe.lean`; no-action |

Expected scan result on the clean set: **0 violations, 4 binder REVIEW
items, 3 hygiene REVIEW items — all register entries above, all
demonstrated-intentional.**