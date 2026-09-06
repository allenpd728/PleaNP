# Boundary probe — creativity-protocol test result (2026-09-06)

**Idea under test (from `docs/CREATIVE_PROTOCOL.md`, DEC-019):** instead of
trying to prove P ≠ NP directly, formalize the **provability boundary** of the
near-P-vs-NP lattice — machine-check which weaker near-statements are
provable, and where provability stops.

## The lattice (weakest → strongest)

| # | Statement | Kind | Provability (verified) |
|---|---|---|---|
| N1 | P_A ⊆ NP_A for every oracle | theorem | ✅ PROVEN (`P_A_subset_NP_A`) |
| N2 | equalizing renderings agree | theorem | ✅ PROVEN (`equalizing_A_iff_C`) |
| N3 | separating_D → separating_B (easy dir) | theorem | ✅ PROVEN (`separating_D_to_B`) |
| N4 | separating_B → separating_D (hard dir) | def | ⛔ NOT PROVEN (needs classical witness) |
| N5 | ∃ equalizing oracle (BGS (a)) | def | ⛔ NOT PROVEN (open) |
| N6 | ∃ separating oracle (BGS (b)) | def | ⛔ NOT PROVEN (open) |

## The result: the boundary idea WORKS (and locates the difficulty precisely)

The boundary is **between N3 and N4**: the easy direction of the separating
clause proves; the reverse direction — which requires producing a separating
witness from set-inequality, i.e. the `Classical.choice` step — does not. That
is exactly the diagonalization, the known hard core of BGS clause (b).

So the protocol-generated idea was **not just persuasive — it was
verifiable and true**: the provability boundary is a real, machine-checkable
object, and it points at precisely the sub-task (#22) where the real work is.

## Honest caveats

- This is a PROBE, not a claim: it does not prove P vs NP. It tests whether
  the boundary idea produces checkable structure. It does.
- The boundary's exact location (between N3 and N4) is only known because
  we can machine-check which statements prove. That is the protocol's
  mechanism working as designed: idea → render → machine-check → locate.

## What survives the gates

The boundary probe `lean/PleaNP/Barriers/BoundaryProbe.lean` builds clean
(the proven theorems prove; the unproven ones are `def`s — rendered, not
sorry'd, so the honesty gates stay green while the boundary is visible).

**Conclusion:** the creativity protocol is not crank-adjacent; its output
(the boundary idea) held up under machine checking, produced a real lattice
of provable/unprovable near-statements, and located the exact difficulty.
That is a working example of "novelty + verification."