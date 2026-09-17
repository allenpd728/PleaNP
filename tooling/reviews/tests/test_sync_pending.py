#!/usr/bin/env python3
"""Tests for the sync-pending dedupe helper (issue #115).

The bug this guards: the workflow wrote the *path* form of the inbox id into the
issue body but grepped for the *bare* id, so the match never succeeded and every
push refiled every pending point. These tests pin:
  * the real body form (path) IS matched — the regression;
  * the bare-id form is also matched (forward-compatible);
  * a different id is NOT matched (no false "already filed" that would silently
    drop a genuinely new review point);
  * the pre-fix matcher would have failed (a direct demonstration of the bug).

Run: python3 tooling/reviews/tests/test_sync_pending.py
"""
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO / "tooling" / "reviews"))

import sync_pending as sp  # noqa: E402

# The exact body shape the workflow writes (see review-issue.yml: BODY=...).
BODY_PATH_FORM = """(inbox id: reviews/pending/20260907-210443-35bf)
**One question to review (intro-level):**

**Is it correct that ...**
"""

BODY_BARE_FORM = """(inbox id: 20260907-210443-35bf)
**One question to review (intro-level):**
"""


def issues_json(*bodies):
    import json
    return json.dumps([{"title": f"t{i}", "body": b} for i, b in enumerate(bodies)])


class TestSyncPending(unittest.TestCase):
    def test_path_form_body_is_matched(self):
        # THE regression: this is what the workflow actually writes.
        self.assertTrue(sp.already_filed(issues_json(BODY_PATH_FORM), "20260907-210443-35bf"))

    def test_bare_id_form_is_matched(self):
        self.assertTrue(sp.already_filed(issues_json(BODY_BARE_FORM), "20260907-210443-35bf"))

    def test_id_with_path_prefix_argument(self):
        # Callers may pass the filename or the prefixed id.
        self.assertTrue(sp.already_filed(
            issues_json(BODY_PATH_FORM), "reviews/pending/20260907-210443-35bf.yaml"))

    def test_different_id_not_matched(self):
        # Must not silently swallow a genuinely new point.
        self.assertFalse(sp.already_filed(issues_json(BODY_PATH_FORM), "20260913-191150-5edf"))

    def test_empty_and_null_bodies_are_safe(self):
        self.assertFalse(sp.already_filed("[]", "20260907-210443-35bf"))
        self.assertFalse(sp.already_filed("", "20260907-210443-35bf"))
        self.assertFalse(sp.already_filed(issues_json(None, ""), "20260907-210443-35bf"))

    def test_malformed_json_is_not_a_crash(self):
        self.assertFalse(sp.already_filed("not json", "20260907-210443-35bf"))

    def test_prefix_collision_is_not_a_match(self):
        # A substring of an id must not count as a match (the old * grep risk).
        self.assertFalse(sp.already_filed(issues_json(BODY_PATH_FORM), "20260907-210443"))

    def test_the_old_inline_grep_would_have_missed(self):
        """Demonstrate the bug directly: the pre-fix pattern did not match."""
        import re
        inbox_id = "20260907-210443-35bf"
        old_pattern = f"inbox id: *{inbox_id}"
        self.assertIsNone(re.search(old_pattern, BODY_PATH_FORM),
                          "the old pattern unexpectedly matched — the bug analysis is wrong")

    def test_normalisation(self):
        self.assertEqual(sp.inbox_id_of("reviews/pending/x-1.yaml"), "x-1")
        self.assertEqual(sp.inbox_id_of("x-1"), "x-1")
        self.assertEqual(sp.inbox_id_of("/a/b/x-1.yaml"), "x-1")


if __name__ == "__main__":
    unittest.main()