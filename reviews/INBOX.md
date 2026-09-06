# Review inbox (human review surface)

> One review point = one claim = ONE question. Agents file points
> and never wait; you review the batch when convenient. `confirm`
> = the machine summary matches your intention; `flag` = it does
> not (the claim reopens). No answer blocks anyone.

## Pending

### 20260906-163721-c9bb
- claim: P_A subset NP_A for every oracle
- decl: `PleaNP.Oracles.P_A_subset_NP_A`  (module: `PleaNP.Computability.OracleComplexity`)
- machine summary: A statement about [P_A, NP_A] with oracle dependence relating by containment/subset (⊆).
- informal (what we wanted): For every oracle A, P^A is a subset of NP^A.
- **QUESTION: The machine says this claim is about containment of P_A in NP_A, over all oracles. Is that what you intended?**
- expected answer: yes
- run: `20260906-1600-demo`  agent: openhands  created: 2026-09-06T16:00:00Z

## Confirmed

_none_

## Flagged

_none_

---
How to answer: `python3 tooling/reviews/review_inbox.py confirm <id>`
or `flag <id> "<reason>"`. Agents sweep flagged points in their
next session (retrospective fix; nothing blocks).
