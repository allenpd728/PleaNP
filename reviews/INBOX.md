# Review inbox (human review surface)

> One review point = one claim = ONE question. Agents file points
> and never wait; you review the batch when convenient. `confirm`
> = the machine summary matches your intention; `flag` = it does
> not (the claim reopens). No answer blocks anyone.

## Pending

### 20260906-172145-107e
- claim: bgs (Gate 3 disagreement)
- decl: `A,D`  (module: `A,D`)
- machine summary: Gate 3 multi-rendering: renderings A and D disagree
- informal (what we wanted): Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A
- **QUESTION: Two independent renderings of the claim 'bgs' are NOT machine-verified equivalent (rendering A vs D). They disagree on the shape. Which matches your intention — or is the informal claim ambiguous?**
- expected answer: yes
- run: `multi-rendering-bgs`  agent: multi-rendering  created: 2026-09-06T17:21:45.117766+00:00

### 20260906-172145-1842
- claim: bgs (Gate 3 disagreement)
- decl: `C,D`  (module: `C,D`)
- machine summary: Gate 3 multi-rendering: renderings C and D disagree
- informal (what we wanted): Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A
- **QUESTION: Two independent renderings of the claim 'bgs' are NOT machine-verified equivalent (rendering C vs D). They disagree on the shape. Which matches your intention — or is the informal claim ambiguous?**
- expected answer: yes
- run: `multi-rendering-bgs`  agent: multi-rendering  created: 2026-09-06T17:21:45.118128+00:00

### 20260906-172145-34e0
- claim: bgs (Gate 3 disagreement)
- decl: `A,B`  (module: `A,B`)
- machine summary: Gate 3 multi-rendering: renderings A and B disagree
- informal (what we wanted): Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A
- **QUESTION: Two independent renderings of the claim 'bgs' are NOT machine-verified equivalent (rendering A vs B). They disagree on the shape. Which matches your intention — or is the informal claim ambiguous?**
- expected answer: yes
- run: `multi-rendering-bgs`  agent: multi-rendering  created: 2026-09-06T17:21:45.111869+00:00

### 20260906-172145-90c8
- claim: bgs (Gate 3 disagreement)
- decl: `B,C`  (module: `B,C`)
- machine summary: Gate 3 multi-rendering: renderings B and C disagree
- informal (what we wanted): Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A
- **QUESTION: Two independent renderings of the claim 'bgs' are NOT machine-verified equivalent (rendering B vs C). They disagree on the shape. Which matches your intention — or is the informal claim ambiguous?**
- expected answer: yes
- run: `multi-rendering-bgs`  agent: multi-rendering  created: 2026-09-06T17:21:45.117906+00:00

### 20260906-172145-a575
- claim: bgs (Gate 3 disagreement)
- decl: `B,D`  (module: `B,D`)
- machine summary: Gate 3 multi-rendering: renderings B and D disagree
- informal (what we wanted): Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A
- **QUESTION: Two independent renderings of the claim 'bgs' are NOT machine-verified equivalent (rendering B vs D). They disagree on the shape. Which matches your intention — or is the informal claim ambiguous?**
- expected answer: yes
- run: `multi-rendering-bgs`  agent: multi-rendering  created: 2026-09-06T17:21:45.118021+00:00

## Confirmed

_none_

## Flagged

_none_

---
How to answer: `python3 tooling/reviews/review_inbox.py confirm <id>`
or `flag <id> "<reason>"`. Agents sweep flagged points in their
next session (retrospective fix; nothing blocks).
