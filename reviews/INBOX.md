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

### 20260913-191150-5edf
- claim: marker-funeq (Gate 3 disagreement)
- decl: `atom,pw`  (module: `atom,pw`)
- machine summary: Two renderings not machine-verified equivalent: rendering atom (unconditional-atom reading of funeq/funne) vs rendering pw (pointwise-propagation reading of funeq/funne)
- informal (what we wanted): Two candidates for the Relativizing funeq/funne marker semantics: (slot 1) the as-implemented unconditional-atom reading - function-level equality p = q relativizes unconditionally, no per-fiber markers; (slot 2) the as-#1-requested pointwise-propagation reading - function-level equality p = q relativizes only when every fiber p x, q x carries a Relativizing marker.
- **QUESTION: On the concrete oracle-varied example, the equality L1 = L2 still relativizes without marking the individual fibers L1 x, L2 x. Was the marker intended to be an unconditional oracle-oblivious atom (as implemented), or to require pointwise propagation from the fibers (as originally requested in #1)? Reply confirm for the as-implemented unconditional-atom reading, or flag <reason> if the pointwise reading was intended.**
- expected answer: yes
- run: `multi-rendering-marker-funeq`  agent: multi-rendering  created: 2026-09-13T19:12:00Z

## Confirmed

_none_

## Flagged

_none_

---
How to answer: `python3 tooling/reviews/review_inbox.py confirm <id>`
or `flag <id> "<reason>"`. Agents sweep flagged points in their
next session (retrospective fix; nothing blocks).
