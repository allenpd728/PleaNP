# Review inbox (human review surface)

> One review point = one claim = ONE question. Agents file points
> and never wait; you review the batch when convenient. `confirm`
> = the machine summary matches your intention; `flag` = it does
> not (the claim reopens). No answer blocks anyone.

## Pending

### 20260907-210443-35bf
- claim: Relativizing.funeq/funne are oracle-oblivious atoms, not pointwise-propagated
- decl: `PleaNP.Calculus.Relativizing.funeq`  (module: `lean/PleaNP/Calculus/BarrierCalculus.lean`)
- machine summary: Instances Relativizing (p = q) and Relativizing (p ≠ q) for p q : α → Prop,declared unconditionally(no pointwise Relativizing-fiber hypotheses)
- informal (what we wanted): Issue #1 requested the marker propagate from pointwise Relativizing (p x) for function-level equality/inequality
- **QUESTION: Is it correct that function equality/inequality of FIXED predicates us marked oracle-oblivious(unconditionally relativizing),even though individual fibers may be oracle-dependent?**
- expected answer: yes
- run: `20260907-2035-k7m2`  agent: openhands  created: 2026-09-07T21:10:00Z
- refs: e46fd23

## Confirmed

_none_

## Flagged

_none_

---
How to answer: `python3 tooling/reviews/review_inbox.py confirm <id>`
or `flag <id> "<reason>"`. Agents sweep flagged points in their
next session (retrospective fix; nothing blocks).
