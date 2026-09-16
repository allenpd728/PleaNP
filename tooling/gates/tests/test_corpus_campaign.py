#!/usr/bin/env python3
"""Unit tests for the Gate 3 corpus campaign driver (`corpus_campaign.py`) — stdlib only.

Covers the counting/collation helpers (which need no Lean:the renderings
count comes from the workspace's `renderings/*.json` files);the matrix pairs
are tallied from `matrix.json`;and the review-point count scans the `reviews/`
tree for the campaign's run key. The `run_campaign` subprocess path is exercised
indirectly via the real mujlti_render driver in its own suite.

Run:  python3 tooling/gates/tests/test_corpus_campaign.py
"""
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import corpus_campaign  # noqa: E402


class CorpusCampaignTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        corpus_campaign.CHURN = Path(self._tmp.name) / "churn"
        corpus_campaign.ROOT = Path(self._tmp.name)
        (corpus_campaign.CHURN / "demo" / "renderings").mkdir(parents=True)
        (corpus_campaign.CHURN / "demo" / "renderings" / "a.json").write_text("{}")
        (corpus_campaign.CHURN / "demo" / "renderings" / "b.json").write_text("{}")
        (corpus_campaign.CHURN / "demo" / "matrix.json").write_text(
            json.dumps({"slug": "demo", "pairs": [
                {"a": "a", "b": "b", "equivalent": True},
                {"a": "a", "b": "c", "equivalent": False},
            ]}))
        # A review point carryingthe campaign's run key (pending)
        rroot = Path(self._tmp.name) / "reviews"
        (rroot / "pending").mkdir(parents=True)
        (rroot / "pending" / "x.yaml").write_text(
            "run: multi-rendering-demo\nstatus: pending\n", encoding="utf-8")
        # Stub the Lean-driving subprocess: the test exercises only the
        # collation helpers (counts, dedupe, aggregation), not the engine.
        # NOTE: patch only corpus_campaign's OWN module-level reference, never
        # `subprocess.run` on the shared module object — `import subprocess`
        # binds the same module everywhere, so assigning through it leaks the
        # stub into every other test that shells out (it silently neutered
        # workflow_scan's `bash -n` check, issue #115).
        import types
        self._orig_subprocess = corpus_campaign.subprocess

        def fake_run(args, **kw):
            return self._orig_subprocess.CompletedProcess(args, 0, stdout="ok", stderr="")

        corpus_campaign.subprocess = types.SimpleNamespace(
            run=fake_run, CompletedProcess=self._orig_subprocess.CompletedProcess)

    def tearDown(self):
        corpus_campaign.subprocess = self._orig_subprocess
        self._tmp.cleanup()

    def test_counts_slugs(self):
        m = corpus_campaign._load_matrix("demo")
        c = corpus_campaign._counts("demo", m)
        self.assertEqual(c["renderings"], 2)
        self.assertEqual(c["pairs"], 2)
        self.assertEqual(c["equivalent"], 1)
        self.assertEqual(c["disagree"], 1)

    def test_counts_review_points(self):
        self.assertEqual(corpus_campaign._count_review_points("demo"), 1)
        self.assertEqual(corpus_campaign._count_review_points("other"), 0)

    def test_run_campaign_aggregates(self):
        row = corpus_campaign.run_campaign("demo", Path("."), mine=False,
                                     previously_mined=2)
        self.assertEqual(row["renderings"], 2)
        self.assertEqual(row["pairs"], 2)
        self.assertEqual(row["disagree"], 1)
        self.assertEqual(row["previously_mined"], 2)
        self.assertTrue(row["skipped_mine"])


if __name__ == "__main__":
    unittest.main()