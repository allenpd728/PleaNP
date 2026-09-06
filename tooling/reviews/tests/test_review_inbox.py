#!/usr/bin/env python3
"""Unit tests for the review inbox (review_inbox.py) — stdlib only.

Uses a temp ROOT so tests never touch the real reviews/ tree. Tests the
full lifecycle: add -> index -> confirm/flag, the mini-YAML round-trip,
schema validation, and unique ids.

Run:  python3 tooling/reviews/tests/test_review_inbox.py
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import review_inbox  # noqa: E402


def _base_fields():
    return [
        "kind=semantic-review",
        "run=20260906-0000-aaaa",
        "agent=test-agent",
        "created=2026-09-06T00:00:00Z",
        "claim=A claim",
        "module=M",
        "decl=X.Y",
        "machine_summary=A statement about [P_A] with containment",
        "informal=For all A, P_A subset NP_A",
        "question=Is this over 'for every'?",
        "expected=yes",
    ]


class ReviewInboxTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        review_inbox.REVIEWS = root / "reviews"
        review_inbox.PENDING = review_inbox.REVIEWS / "pending"
        review_inbox.CONFIRMED = review_inbox.REVIEWS / "confirmed"
        review_inbox.FLAGGED = review_inbox.REVIEWS / "flagged"
        review_inbox.INBOX = review_inbox.REVIEWS / "INBOX.md"
        for d in (review_inbox.PENDING, review_inbox.CONFIRMED, review_inbox.FLAGGED):
            d.mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self._tmp.cleanup()

    def test_add_requires_required_fields(self):
        self.assertEqual(review_inbox.add(["kind=semantic-review"]), 2)
        self.assertEqual(len(list(review_inbox.PENDING.glob("*.yaml"))), 0)

    def test_add_rejects_unknown_field(self):
        rc = review_inbox.add(_base_fields() + ["bogus=1"])
        self.assertEqual(rc, 2)
        self.assertEqual(len(list(review_inbox.PENDING.glob("*.yaml"))), 0)

    def test_add_and_list(self):
        rc = review_inbox.add(_base_fields())
        self.assertEqual(rc, 0)
        points = list(review_inbox.PENDING.glob("*.yaml"))
        self.assertEqual(len(points), 1)
        self.assertEqual(review_inbox.list_points("pending"), 0)

    def test_unique_ids_parallel(self):
        self.assertEqual(review_inbox.add(_base_fields()), 0)
        self.assertEqual(review_inbox.add(_base_fields()), 0)
        pids = [p.stem for p in review_inbox.PENDING.glob("*.yaml")]
        self.assertEqual(len(pids), len(set(pids)), "ids must be unique (multistream)")

    def test_confirm_moves_to_confirmed(self):
        review_inbox.add(_base_fields())
        pid = next(review_inbox.PENDING.glob("*.yaml")).stem
        review_inbox._move(pid, "confirmed", None)
        self.assertTrue(review_inbox.CONFIRMED.joinpath(pid + ".yaml").exists())
        self.assertFalse(review_inbox.PENDING.joinpath(pid + ".yaml").exists())

    def test_flag_moves_and_records_reason(self):
        review_inbox.add(_base_fields())
        pid = next(review_inbox.PENDING.glob("*.yaml")).stem
        review_inbox._move(pid, "flagged", "wrong quantifier")
        fp = review_inbox.FLAGGED.joinpath(pid + ".yaml")
        self.assertTrue(fp.exists())
        d = review_inbox._MiniYaml.load(fp.read_text())
        self.assertEqual(d.get("reason"), "wrong quantifier")
        self.assertEqual(d.get("status"), "flagged")

    def test_index_writes_inbox(self):
        review_inbox.add(_base_fields())
        review_inbox.index()
        text = (review_inbox.REVIEWS / "INBOX.md").read_text()
        self.assertIn("Review inbox", text)
        self.assertIn("QUESTION", text)
        self.assertIn("Pending", text)

    def test_yaml_roundtrip_escaping(self):
        d = {"claim": "a: claim with colon", "status": "pending", "n": "5"}
        s = review_inbox._MiniYaml.dump(d)
        d2 = review_inbox._MiniYaml.load(s)
        self.assertEqual(d2["claim"], "a: claim with colon")
        self.assertEqual(d2["status"], "pending")


if __name__ == "__main__":
    unittest.main(verbosity=2)