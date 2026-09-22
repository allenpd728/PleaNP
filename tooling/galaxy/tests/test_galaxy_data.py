#!/usr/bin/env python3
"""Unit tests for the Galaxy data layer (issue #86). stdlib-only, no network."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import galaxy_data  # noqa: E402


class TestBarriers(unittest.TestCase):
    def test_parse_barriers_three_families(self):
        yaml = """
status:
 main_results:
 - description: >-
     (BGS clause a) Existence of an oracle A with P^A = NP^A.
   declaration: PleaNP.Barriers.Relativization.exists_equalizing_oracle
   status: rendered-not-frozen
   sorry_count: 1
 - description: >-
     Oracle-machine substrate: decidability in polynomial time.
   declaration: PleaNP.Oracles.DecidesInTime
   status: validated-in-ci
"""
        bars = galaxy_data.parse_barriers(yaml)
        names = [b.name for b in bars]
        self.assertEqual(names, ["Relativization", "NaturalProofs", "Algebrization"])
        rel = bars[0]
        self.assertEqual(rel.declarations_meta[0]["declaration"],
                         "PleaNP.Barriers.Relativization.exists_equalizing_oracle")
        # The oracle-substrate row maps to no barrier and is skipped.
        self.assertTrue(all(len(b.declarations_meta) <= 1 for b in bars))

    def test_parse_barriers_sources_used_for_description(self):
        yaml = """
sources:
 - title: "Algebrization: A New Barrier in Complexity Theory"
   relationship: formalizes
"""
        bars = galaxy_data.parse_barriers(yaml)
        algb = [b for b in bars if b.name == "Algebrization"][0]
        self.assertIn("Algebrization", algb.description)

    def test_parse_barriers_empty_yaml(self):
        bars = galaxy_data.parse_barriers("")
        self.assertEqual([b.name for b in bars], list(galaxy_data.BARRIER_NAMES))


class TestMatrix(unittest.TestCase):
    def test_blocked_pairs_are_asteroids(self):
        m = {"slug": "bgs", "pairs": [
            {"a": "A", "b": "B", "equivalent": False, "detail": "BLOCKED: nope"},
            {"a": "A", "b": "C", "equivalent": True, "detail": "proved"},
        ]}
        asts = galaxy_data.parse_matrix(m)
        self.assertEqual(len(asts), 1)
        self.assertEqual(asts[0]["gate"], "readback")
        self.assertIn("A ≢ B", asts[0]["label"])
        self.assertIn("BLOCKED", asts[0]["detail"])

    def test_empty_matrix(self):
        self.assertEqual(galaxy_data.parse_matrix({"slug": "x", "pairs": []}), [])


class TestBlockers(unittest.TestCase):
    def test_parses_blocker_md(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "open_20260907-0953_bgs26-fintype.md"
            p.write_text(
                "# Blocker: #26 — uninhabitable substrate\n\n"
                "## What information is missing\n\nA human decision...\n\n"
                "## Resolution (2026-09-11, DEC-024)\n\nChosen: word-query oracle.\n",
                encoding="utf-8")
            asts = galaxy_data.parse_blockers(Path(d))
        self.assertEqual(len(asts), 1)
        self.assertEqual(asts[0]["gate"], "model")
        self.assertIn("26", asts[0]["label"])
        # Radius deterministic from filename date.
        self.assertGreater(asts[0]["radius"], 1.0)

    def test_skips_closed_blockers(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "open_20260907-0953_x.md").write_text(
                "# Blocker: still open\n\n## What information is missing\nA decision.\n",
                encoding="utf-8")
            (Path(d) / "closed_20260907-2110_y.md").write_text(
                "# Blocker: resolved\n\n## Resolution\nDone.\n",
                encoding="utf-8")
            asts = galaxy_data.parse_blockers(Path(d))
        self.assertEqual(len(asts), 1)
        self.assertIn("still open", asts[0]["label"])


class TestSorries(unittest.TestCase):
    def test_parses_tracker_rows(self):
        md = """
| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 6 | `OracleUpstreamP.lean:25` | `P_empty_eq_upstream_P_class` — RHS set comprehension | Upstream P | High |
| 8 | `Relativization.lean:80` | BGS clause (a) proof | PSPACE/QBF | Low |
"""
        asts = galaxy_data.parse_sorries(md)
        self.assertEqual(len(asts), 2)
        self.assertTrue(all(a["gate"] == "hygiene" for a in asts))
        self.assertTrue(any("OracleUpstreamP" in a["label"] for a in asts))
        # Detail carries the pending dependency.
        self.assertTrue(any("Upstream P" in a["detail"] for a in asts))

    def test_skips_headers_and_separators(self):
        md = "|---|---|---|\n| File | What | pending | ... |\n"
        self.assertEqual(galaxy_data.parse_sorries(md), [])

    def test_resolved_row_with_pipe_in_cell_is_not_open_debt(self):
        # Regression for #127: `{ L | sorry }` in a Resolved row's *What* cell
        # split on `|` into extra cells and parsed as live debt.
        md = """## Detailed inventory

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 7 | `A.lean:4` | a real open site. | Upstream P | Medium |
| 6 | ~~`B.lean:2`~~ **Resolved** — RHS was `{ L | sorry }`. | — | — |
"""
        asts = galaxy_data.parse_sorries(md)
        self.assertEqual([a["label"] for a in asts], ["sorry: A.lean:4"])

    def test_resolved_section_rows_are_not_open_debt(self):
        md = """## Detailed inventory

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 7 | `A.lean:4` | a real open site. | Upstream P | Medium |

## Resolved

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 6 | `B.lean:2` | closed some time ago. | — | — |
"""
        asts = galaxy_data.parse_sorries(md)
        self.assertEqual([a["label"] for a in asts], ["sorry: A.lean:4"])


class TestReviewPoints(unittest.TestCase):
    def test_parses_review_yaml(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "20260907-210443-35bf.yaml"
            p.write_text(
                "agent: openhands\n"
                "claim: Relativizing.funeq are oracle-oblivious atoms\n"
                'question: "Is that correct?"\n'
                "decl: PleaNP.Calculus.Relativizing.funeq\n",
                encoding="utf-8")
            asts = galaxy_data.parse_review_points(Path(d))
        self.assertEqual(len(asts), 1)
        self.assertEqual(asts[0]["gate"], "readback")
        self.assertIn("funeq", asts[0]["label"])
        self.assertEqual(asts[0]["declarations"], ["PleaNP.Calculus.Relativizing.funeq"])


class TestBuildGalaxy(unittest.TestCase):
    def _fake_repo(self, root: Path) -> None:
        (root / "formalization.yaml").write_text(
            "status:\n main_results:\n"
            " - description: >-\n"
            "     (BGS clause a) Existence of an oracle A with P^A = NP^A.\n"
            "   declaration: PleaNP.Barriers.Relativization.exists_equalizing_oracle\n"
            "   status: rendered-not-frozen\n"
            "   sorry_count: 1\n",
            encoding="utf-8")
        (root / "docs").mkdir()
        (root / "docs" / "SORRY_TRACKER.md").write_text(
            "| # | File:Line | What it is | Pending on | Priority |\n"
            "|---|----------|------------|------------|----------|\n"
            "| 8 | `Relativization.lean:80` | BGS clause (a) proof | PSPACE | Low |\n",
            encoding="utf-8")
        (root / "blockers").mkdir()
        (root / "blockers" / "open_20260907-0953_bgs26.md").write_text(
            "# Blocker: #26 — uninhabitable\n\n## What information is missing\nA decision.\n",
            encoding="utf-8")
        (root / "reviews").mkdir()
        (root / "reviews" / "pending").mkdir()
        (root / "churn").mkdir()

    def test_build_galaxy_assembles_all(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self._fake_repo(root)
            g = galaxy_data.build_galaxy(root)
        self.assertEqual([b.name for b in g.barriers],
                         ["Relativization", "NaturalProofs", "Algebrization"])
        self.assertGreaterEqual(len(g.asteroids), 2)  # 1 sorry + 1 blocker
        # Gate-color mapping is embedded.
        for a in g.asteroids:
            a_dict = a if isinstance(a, dict) else a.to_dict()
            self.assertIn(a_dict["color"], galaxy_data.GATE_COLORS.values())
        rel_h = [h for h in g.horizons if h.barrier == "Relativization"][0]
        self.assertIn("exists_equalizing_oracle", rel_h.rendered[0])

    def test_build_galaxy_resolves_repo(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self._fake_repo(root)
            self.assertEqual(galaxy_data.resolve_repo(str(root)), root)
        # Existing-file case: resolves from the repo root.
        root2 = Path(__file__).resolve().parent.parent.parent.parent
        if (root2 / "formalization.yaml").exists():
            self.assertTrue(galaxy_data.resolve_repo(str(root2)).exists())


class TestMinYamlQuirks(unittest.TestCase):
    """Regression tests for formalization.yaml's parser quirks."""

    def test_same_indent_seq_under_key(self):
        from miniyaml import loads
        data = loads("status:\n main_results:\n - description: x\n   sorry_count: 1\n")
        self.assertEqual(len(data["status"]["main_results"]), 1)
        self.assertEqual(data["status"]["main_results"][0]["sorry_count"], 1)

    def test_block_scalar_then_continuation_keys(self):
        from miniyaml import loads
        data = loads(
            "related_formalizations:\n"
            " - id: https://a.b\n"
            "   note: >-\n"
            "     Comparator challenge + layout\n"
            "     adopted from the release\n"
        )
        item = data["related_formalizations"][0]
        self.assertEqual(item["id"], "https://a.b")
        self.assertIn("adopted from", item["note"])

    def test_folded_scalar_joins_lines(self):
        from miniyaml import loads
        data = loads("desc: >-\n  Line one\n  Line two\n")
        self.assertEqual(data["desc"], "Line one Line two")

    def test_url_not_treated_as_mapping(self):
        from miniyaml import loads
        data = loads("related_formalizations:\n - id: https://github.com/openai/X\n")
        self.assertEqual(data["related_formalizations"], [{"id": "https://github.com/openai/X"}])


class TestFullManifest(unittest.TestCase):
    def test_real_formalization_yaml(self):
        repo = Path(__file__).resolve().parent.parent.parent.parent
        yaml_path = repo / "formalization.yaml"
        if not yaml_path.exists():
            self.skipTest("repo manifest not present")
        bars = galaxy_data.parse_barriers(yaml_path.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(bars), 3)
        # Every family is present.
        self.assertEqual([b.name for b in bars], list(galaxy_data.BARRIER_NAMES))
        # BGS declarations exist under Relativization.
        rel = [b for b in bars if b.name == "Relativization"][0]
        decls = [dm["declaration"] for dm in rel.declarations_meta]
        self.assertTrue(any("exists_equalizing_oracle" in d for d in decls))


if __name__ == "__main__":
    unittest.main(verbosity=2)