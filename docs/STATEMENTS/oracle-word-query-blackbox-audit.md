# Oracle word-query substrate: cross-domain black-box audit

> Lineage: the Option Omega synthesis (#33, DEC-024, run=20260911-0944-qmzn) that produced `docs/STATEMENTS/Oracle.v5-repair.spec.md`. It documents the invariant observed across mature black-box models: every one separates *infinite query values* from *finite machine syntax* -- a query is always a *word over a fixed finite alphabet*, never one symbol per question value.

## The invariant

A black box (oracle, device, name service, coordinate frame) answers an infinite family of queries, but the language for asking is always finite. You serialize the request into a finite string over a small, fixed character set. The infinity lives in the meanings assignable to finite strings ( length, content, composition ), not in the alphabet itself. v4 forgot this (it fused the query type into the tape-alphabet slot, forcing `Fintype Q` on the infinite `Q = Sigma n, Bits n`). v5 restores it: the query is the content of a dedicated tape -- a `List` over the machine's finite alphabet `Gamma kq` -- a word.

## Per-domain survey

| Domain | Black box | Reconciliation | Mechanism | Rules out / wall analogy |
|---|---|---|---|---|
| Math: recursion theory | Turing oracle (a set of naturals) | the machine writes n as a finite word onto a query tape;the oracle answers membership of the coded value | Serialize-the-value-onto-a-tape;decode-on-the-box-side | the query alphabet must not be the value-space (`Fintype Q` fails `Nat` injects);capping destroys the unqueried-value diagonal step |
| Math: generic-group algorithms | Group oracle(answers word-equality over a fixed generating set) | every element is named by a word over the finite generators;the box reduces words | fixed generator alphabet + arbitrary length = infinite values, finite syntax | infinite alphabet is unnecessary;finitely many generators plus word-length covers everything |
| Crypto | Random oracle(hashes on bitstrings) | queries are finite strings over `{0,1}`;length is unbounded | bits + length = the value space | capping length breaks hash chains -- analogous to capping BGS's n |
| Engineering: SQL/databases | Query engine(answers over a schema) | parameters are values;schema/column names are finite;the query is a serialized statement with values inlined | finite grammar + serialized values | don't generalize the grammar to infinite column names;keep schema finite -- same shape as word-query |
| Engineering: hardware buses | Device bus(an infinite address space) | finite address pins form a fixed-width frame;addresses are serialized per transaction | finite wires + fixed-width frame | one pin per address is absurd (would need infinite pins;;the serialization pattern is what real hardware does |
| Engineering: DNS/URLs | Name service(infinitely many names) | names are strings over a finite character set;;the resolver maps string to record | infinite name-space, finite charset | capping name length breaks the space;;infinite charset breaks every resolver -- finite charset is the point |
| Physics: coordinate frames | A reference frame(infinitely many points) | a point is specified by its coordinates over finitely many axes,each written finitely | finite axes + finite digit alphabet = infinite point-space | don't cap the points to a bounded region(alias loses most of physics);;don't add infinitely many axes(a frame has finitely many -- that is what makes it a frame |

## Why 'cap the query set' is naive

A novice fixing `Fintype Q` might bound the query family( e.g. strings up to fixed length `N`). That makes `Fintype` work, but breaks the BGS unqueried-n-bit-string step, which needs *every* length n to have 2^n fresh candidate strings. Bounded queries cap n;beyond the cap the diagonalization has no room. The mature pattern echoes this:real boxes are infinite-valued on purpose, entangled their finiteness lives in the syntax, not the semantics.

## Why 'generalize to infinite alphabets' over-shoots

The other naive fix weakens finiteness itself( allowing the tape alphabet to be infinite). Over-kill twice:(1) you don't need it -- every BGS query is an n-bit string over a 2-symbol alphabet;(2) it throws away a real physical constraint -- finite pins/wires/schema/frame-axes are what make the box realizable,and keep `FinTM2`'s bundled `Fintype` honest. Keep the alphabet finite;let length/content carry the infinity.

## What this rules out / preserves

Rules out: v4's alphabet-query fusion (`hGamma: tm'.Gamma tm'.k0 = Q`,,which forces `Fintype Q` -- a type-level contradiction for `Q = Sigma n, Bits n`);and both naive fixes above.

Preserves: the totality discipline of `Oracle Q` (oracle answers every query;;totality lives on the value-side);the exactly-1-step query consultation (`OracleTM2Recompose.spec.md` sec 4 trap 2);`P^empty = P` compatibility;;and finite alphabets everywhere a `Fintype` belongs -- because those are real engineering invariants the domains above honor. The word-query substrate(v5) is exactly the mature pattern:finite machine syntax(the tape alphabet,its contents arbitrary-length words)),infinite query values(`Sigma n, Bits n`),serialized by a decode the machine's witness supplies.
