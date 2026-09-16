#!/usr/bin/env python3
"""sync-pending dedupe helper (review-issue.yml, issue #115).

The `sync-pending` job files one GitHub issue per pending review point and must
be idempotent: a point already filed must not be filed again. That logic used to
be an inline `grep` that never matched — the issue body is written as
``(inbox id: reviews/pending/<id>)`` while the grep searched for
``inbox id: *<id>`` (the bare id). Result: every push touching
``reviews/pending/*.yaml`` refiled *every* pending point as a duplicate (see
#29/#85/#95/#107/#113 and #96/#108/#114 — the same two inbox ids, five and four
times).

This module is the single source of truth for "is this inbox id already filed?",
so the workflow and the test cannot drift. It matches both the path form the
workflow writes and a bare-id form, so the fix is forward-compatible and still
recognises the issues that already exist.

Usage (from the repo root, as the workflow does):

    gh issue list --label "review:pending,review:flagged" --state open \
        --limit 100 --json title,body > /tmp/existing.json
    python3 tooling/reviews/sync_pending.py already-filed /tmp/existing.json <inbox-id>
    # exit 0 = already filed (skip), 1 = not filed (create)

`<inbox-id>` may be given with or without the ``reviews/pending/`` prefix.

Exit codes: 0 already filed, 1 not filed, 2 usage/read error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_ID_RE = re.compile(r"inbox id:\s*(?:reviews/pending/)?([A-Za-z0-9._-]+)")


def inbox_id_of(name: str) -> str:
    """Normalise a point filename or id to the bare inbox id.

    ``reviews/pending/20260907-210443-35bf.yaml`` -> ``20260907-210443-35bf``
    ``20260907-210443-35bf``                      -> ``20260907-210443-35bf``
    """
    base = Path(name).name
    if base.endswith(".yaml"):
        base = base[: -len(".yaml")]
    return base


def already_filed(existing_json_text: str, inbox_id: str) -> bool:
    """True iff any existing issue's body carries this inbox id.

    `existing_json_text` is the JSON array from `gh issue list --json title,body`
    (a list of objects with at least a `body` key). Bodies that are null/missing
    are ignored rather than raising — `gh` emits null bodies for empty issues.
    """
    want = inbox_id_of(inbox_id)
    try:
        items = json.loads(existing_json_text or "[]")
    except json.JSONDecodeError:
        return False
    if not isinstance(items, list):
        return False
    for it in items:
        body = (it or {}).get("body") or ""
        for m in _ID_RE.finditer(body):
            if m.group(1) == want:
                return True
    return False


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("already-filed", help="exit 0 if the id is already filed")
    p.add_argument("existing_json", help="path to `gh issue list --json title,body` output")
    p.add_argument("inbox_id")
    args = ap.parse_args(argv[1:])

    try:
        text = Path(args.existing_json).read_text(encoding="utf-8")
    except OSError as e:
        print(f"sync_pending: cannot read {args.existing_json}: {e}", file=sys.stderr)
        return 2

    if already_filed(text, args.inbox_id):
        print(f"sync_pending: {inbox_id_of(args.inbox_id)} already filed (skip)")
        return 0
    print(f"sync_pending: {inbox_id_of(args.inbox_id)} not filed (create)")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))