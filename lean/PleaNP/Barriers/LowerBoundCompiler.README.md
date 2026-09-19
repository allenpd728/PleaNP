# Lower-Bound Compiler (Rung 8)

`PleaNP.Barriers.LowerBoundCompiler` mechanizes **Williams' transfer theorem**
as a Lean elaborator: hand it a *verified* CircuitSAT algorithm together with a
*verified* sub-exponential runtime bound, and it emits the lower bound
`NEXP ⊄ C` with the dependency closure that attaches the runtime.

The design (input contract, anti-requirements, dependency ordering) is
`docs/STATEMENTS/LowerBoundCompiler.design.md` (issue #80 Pass 1). The
classification note for the emitted lower bound is
`docs/STATEMENTS/WilliamsTransfer.classification.md` (issue #91).

## Usage

```lean
-- The conditional emission: names the transfer closure
-- `SubExpCircuitSATT → NEXP_not_subset_ACC0`.
#lower_bound_compile_cond my_lower_bound

-- The guarded full emission: `<contract>` must be a proved
-- `SubExpCircuitSATT`; emits the claim `NEXP_not_subset_ACC0` under `<name>`.
#lower_bound_compile my_contract as my_lower_bound
```

Both commands log three things at their emission site:

1. the emitted declaration;
2. the `PleaNP`-local transitive dependency closure (the definitions carrying
   the runtime model);
3. the axiom closure of the emitted claim, in the `#print axioms` idiom — the
   Gate 6 Tier 2 discipline made visible where the claim is created.

## What the full path guards against

`#lower_bound_compile` rejects a contract that

- **rests on `sorryAx`** — a placeholder-carried runtime would make the emitted
  lower bound only as strong as the contract's honesty (design note §2,
  anti-requirement "no asserted runtime");
- **has the wrong shape** — the contract's type, after `whnf`, must be
  `SubExpCircuitSATT`;
- **does not exist** — a missing contract is a clear error, not a silent no-op;
- **would shadow an existing declaration** — re-emitting a name already
  declared is an error.

The rejections are exercised at build time in
`lean/tests/LowerBoundCompilerGuards.lean` (each asserted with `#guard_msgs`),
so a regression that loosened a guard is a build failure.

## Honest status (issue #80 Pass 2)

No *proved* `SubExpCircuitSATT` exists yet: its sub-exponential half is the
tracked `acc0SatSubExpBound` gap in `PleaNP.Barriers.WilliamsSat` — the
ACC⁰-structure packing argument (Shah–Shetty-style Good-SAT), tracked by
**#98**. The example emission in the module therefore uses the conditional
form, which is a complete theorem as stated (its hypothesis is exactly the
contract #98 will supply). The full `#lower_bound_compile <contract> as <name>`
path is implemented and guarded, and becomes usable unchanged the moment a
contract proof lands. Neither form introduces a placeholder proof.

A **vacuous-class guard** (rejecting a degenerate target class `C = ∅`, where
`NEXP ⊄ C` is trivially true) is a *semantic* check that needs the class
carrier in the contract; it is recorded as a design requirement (design note
§2) rather than faked with a syntactic proxy.

## Dependencies

- `PleaNP.Barriers.WilliamsAssembly` — the assembled `NEXP ⊄ ACC⁰` statement
  chain (#91), which re-exports the #88/#89/#90 anchors.
- `PleaNP.Calculus.BarrierCalculus` — the Rung-5 verdict machinery; the emitted
  claim carries no `Relativizing` instance, so `#barrier_check` reports
  **Inconclusive** (the expected non-relativizing classification).

## Tests

- `lean/tests/LowerBoundCompilerGuards.lean` — the four contract-rejection
  guards (wrong shape, `sorryAx`, missing, shadowing), each pinned with
  `#guard_msgs`.
- `docs/STATEMENTS/LowerBoundCompilerAcceptPath.spec.md` — the **accept-path**
  test spec (issue #109): the frozen shape of the `[full]` emission log lines
  and the exact `#guard_msgs` test to land, with `lean/tests/LowerBoundCompilerAcceptPath.lean`,
  once #98 supplies a `sorry`-free `SubExpCircuitSATT` proof. The accept path is
  unreachable today by design (no such proof exists; asserting it would need the
  dishonest contract the compiler rejects), so the spec is the deliverable.
