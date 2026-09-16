#!/usr/bin/env python3
"""Unit tests for the Galaxy renderer (issue #87). stdlib-only, no network."""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import galaxy  # noqa: E402


def _sample_model() -> dict:
    meta = {
        "barrier_names": ["Relativization", "NaturalProofs", "Algebrization"],
        "gate_colors": galaxy_data_gate_colors(),
    }
    return {
        "metadata": meta,
        "barriers": [
            {"name": "Relativization", "description": "BGS 1975", "declarations": [
                "PleaNP.Barriers.Relativization.exists_equalizing_oracle"]},
            {"name": "NaturalProofs", "description": "RR 1994", "declarations": []},
            {"name": "Algebrization", "description": "AW 2008", "declarations": []},
        ],
        "horizons": [
            {"barrier": "Relativization", "proven": ["P_A_subset_NP_A"],
             "rendered": ["exists_equalizing_oracle"], "boundary": ["N4", "N5"]},
            {"barrier": "NaturalProofs", "proven": [], "rendered": [], "boundary": []},
            {"barrier": "Algebrization", "proven": [], "rendered": [], "boundary": []},
        ],
        "asteroids": [
            {"label": "bgs: A ≢ B", "gate": "readback", "detail": "BLOCKED",
             "color": "#b45be6", "radius": 1.0, "source": "churn/bgs/matrix.json",
             "declarations": []},
            {"label": "blocker: #26", "gate": "model", "detail": "decision",
             "color": "#3e7bfa", "radius": 1.4, "source": "blockers/x.md",
             "declarations": []},
        ],
    }


def galaxy_data_gate_colors() -> dict:
    # Avoid importing galaxy_data just for colors; hardcode the 6.
    return {"dead": "#e5484d", "vacuity": "#f2b544", "model": "#3e7bfa",
            "readback": "#b45be6", "hygiene": "#30a46c", "unresolved": "#8d8d8d"}


class TestRenderOutput(unittest.TestCase):
    def setUp(self):
        self.model = _sample_model()
        self.html = galaxy.render(self.model, title="Unit test galaxy")

    def test_self_contained_offline(self):
        # No external resource references (no http/cdn/<link href>/<img src>).
        self.assertNotIn("http://", self.html)
        self.assertNotIn("https://", self.html)
        self.assertNotIn('rel="stylesheet"', self.html)
        self.assertNotIn("<link ", self.html)

    def test_css_braces_are_single(self):
        # The doubled-brace collapse must have produced valid CSS.
        self.assertNotIn("{{", self.html)
        self.assertNotIn("}}", self.html)
        self.assertIn("background: radial-gradient", self.html)
        self.assertIn("body {", self.html)

    def test_embedded_json_present_and_valid(self):
        m = re.search(r"const GALAXY = (\{.*?\});", self.html, re.S)
        self.assertTrue(m, "no embedded Galaxy const found")
        js = m.group(1)
        # js is a JS object literal; it must also be strict JSON as we embed.
        data = json.loads(js)
        self.assertEqual([b["name"] for b in data["barriers"]],
                         ["Relativization", "NaturalProofs", "Algebrization"])
        self.assertEqual(len(data["asteroids"]), 2)

    def test_canvas_and_legend_present(self):
        self.assertIn('<canvas id="glx"', self.html)
        self.assertIn("id=\"legendList\"", self.html)
        self.assertIn("id=\"tip\"", self.html)
        # JS that draws the scene.
        self.assertIn("requestAnimationFrame(draw)", self.html)

    def test_zoom_interactions_wired(self):
        # Wheel zoom + pinch zoom + reset, with a clamp range.
        self.assertIn("canvas.addEventListener(\"wheel\"", self.html)
        self.assertIn("zoomBy(", self.html)
        self.assertIn("view.targetZoom = clamp(", self.html)
        self.assertIn("dblclick", self.html)
        self.assertIn("pinch", self.html)

    def test_responsive_fit_and_mobile_css(self):
        # Auto-fit scale from a projected bounding box (fixes mobile clipping).
        self.assertIn("function fitScale()", self.html)
        self.assertIn("Math.min(W * pad / spanX, Hpx * pad / spanY)", self.html)
        # Mobile media query exists.
        self.assertIn("@media (max-width: 700px)", self.html)

    def test_legend_collapsible(self):
        # Legend is hidden by default and toggled by the legend button.
        self.assertIn("id=\"legendToggle\"", self.html)
        self.assertIn("legend.classList.toggle(\"open\")", self.html)
        self.assertIn("#legend.open", self.html)

    def test_watermark_depth_cues_present(self):
        # Honest early-prototype watermark + baseline grid (depth cue).
        self.assertIn("early prototype", self.html)
        self.assertIn("rungs 1", self.html)
        self.assertIn("function drawGrid(", self.html)

    def test_title_injected(self):
        self.assertIn("<title>PleaNP — Barrier Galaxy</title>", self.html)

    def test_script_tag_escaping_of_json(self):
        # A hostile string inside the model must not break </script>.
        self.model["asteroids"][0]["detail"] = "</script><script>alert(1)</script>"
        html = galaxy.render(self.model)
        self.assertNotIn("</script><script>", html)


class TestCLI(unittest.TestCase):
    def test_json_file_mode(self):
        src = Path(__file__).parent.parent
        json_path = src / "_test_model.json"
        out = src / "_test_galaxy.html"
        json_path.write_text(json.dumps(_sample_model(), ensure_ascii=False),
                             encoding="utf-8")
        try:
            code = galaxy.main(["--json-file", str(json_path), "--out", str(out)])
            self.assertEqual(code, 0)
            self.assertTrue(out.exists())
            self.assertIn("const GALAXY", out.read_text(encoding="utf-8"))
        finally:
            if out.exists():
                out.unlink()
            if json_path.exists():
                json_path.unlink()


class TestModelSource(unittest.TestCase):
    def test_build_galaxy_to_dict_roundtrip(self):
        repo = Path(__file__).resolve().parent.parent.parent.parent
        if not (repo / "formalization.yaml").exists():
            self.skipTest("repo root not found")
        import importlib
        import galaxy_data
        importlib.reload(galaxy_data)
        g = galaxy_data.build_galaxy(repo)
        d = g.to_dict()
        # Renders cleanly.
        html = galaxy.render(d)
        self.assertIn("const GALAXY", html)
        self.assertIn("Relativization", html)


if __name__ == "__main__":
    unittest.main(verbosity=2)