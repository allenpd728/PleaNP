#!/usr/bin/env python3
"""Galaxy renderer — emit a self-contained static galaxy.html (Canvas 2D).

Per issue #87 and the Galaxy spec (§4–5). A stdlib-Python generator that
consumes the Galaxy data model (from galaxy_data.build_galaxy) and emits a
self-contained galaxy.html: a static 2.5D page using the browser's native
Canvas 2D API (vanilla JS, no CDN, no build tooling, opens offline).

The render shows:
* black holes  — the barrier families (dark disks, labeled)
* event horizons — rings around each hole = provability boundary
* asteroids    — failed/blocked attempts, colored by rejecting gate,
                 radius ∝ size, hover tooltip with issue/declaration + gate
* residual freedom — the dark canvas between holes

Interactions: orbit-drag (2.5D), hover tooltip, and a legend.

Usage:
    python3 galaxy.py --repo ../.. --out galaxy.html
    python3 galaxy.py --json-file galaxy.json --out galaxy.html
    python3 galaxy.py --repo ../.. --out galaxy.html --serve 12000  # preview
"""
from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from galaxy_data import build_galaxy, resolve_repo  # noqa: E402


# --------------------------------------------------------------------------
# HTML/CSS/JS template — the whole deliverable is this single string.
# --------------------------------------------------------------------------
TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>PleaNP — Barrier Galaxy</title>
<style>
  :root {{
    --bg: #06070c; --ink: #d9e2ec; --dim: #8aa0b8;
    --panel: rgba(15, 18, 28, 0.86); --line: #1c2638;
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ height: 100%; margin: 0; }}
  body {{
    background: radial-gradient(1200px 800px at 50% 35%, #0b0f1a 0%, var(--bg) 60%);
    color: var(--ink); font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
    overflow: hidden;
  }}
  #wrap {{ position: fixed; inset: 0; }}
  canvas {{ display: block; width: 100vw; height: 100vh; cursor: grab; }}
  canvas.drag {{ cursor: grabbing; }}
  header {{
    position: fixed; top: 18px; left: 22px; z-index: 5; pointer-events: none;
  }}
  header h1 {{
    margin: 0; font-size: 17px; font-weight: 600; letter-spacing: 0.06em;
  }}
  header p {{ margin: 4px 0 0; font-size: 12px; color: var(--dim); }}
  #legend {{
    position: fixed; right: 22px; top: 18px; z-index: 5;
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 12px 14px; font-size: 12px; backdrop-filter: blur(4px);
  }}
  #legend h2 {{ margin: 0 0 8px; font-size: 11px; text-transform: uppercase;
               letter-spacing: 0.12em; color: var(--dim); font-weight: 600; }}
  #legend ul {{ list-style: none; margin: 0; padding: 0; }}
  #legend li {{ display: flex; align-items: center; gap: 8px; margin: 4px 0; }}
  .swatch {{ width: 10px; height: 10px; border-radius: 50%; display: inline-block; }}
  #tip {{
    position: fixed; z-index: 6; max-width: 340px; pointer-events: none;
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 10px 12px; font-size: 12px; line-height: 1.45; opacity: 0;
    transition: opacity 0.12s ease; backdrop-filter: blur(4px);
  }}
  #tip .t-title {{ font-weight: 700; margin-bottom: 4px; }}
  #tip .t-gate {{ display: inline-block; padding: 1px 7px; border-radius: 999px;
                  font-size: 11px; margin-bottom: 5px; }}
  #tip .t-body {{ color: var(--dim); }}
  footer {{
    position: fixed; bottom: 12px; left: 0; right: 0; text-align: center;
    font-size: 11px; color: var(--dim); z-index: 4; pointer-events: none;
  }}
</style>
</head>
<body>
<div id="wrap"><canvas id="glx"></canvas></div>

<header>
  <h1>&#9737; PLEANP &#183; BARRIER GALAXY</h1>
  <p>The negative space of P&#8201;vs&#8201;NP: where proof techniques cannot go.</p>
</header>

<div id="legend">
  <h2>Legend</h2>
  <ul id="legendList"></ul>
</div>

<div id="tip"></div>
<footer>orbit: drag &middot; hover: detail &middot; canvas generated offline, no network</footer>

<script>
/* ---- data (embedded JSON) ------------------------------------------- */
const GALAXY = __GALAXY_JSON__;

/* ---- tiny helpers ---------------------------------------------------- */
const TAU = Math.PI * 2;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rng = (() => {{ let s = 123456789; return () => {{
  s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; }}; }})();
function hash01(str) {{
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {{ h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }}
  return ((h >>> 0) % 10000) / 10000;
}}

/* ---- scene state ----------------------------------------------------- */
const scenes = {{
  yaw: 0.42,        // orbit rotation around Y
  pitch: 0.30,      // tilt around X
  targetYaw: 0.42,
  targetPitch: 0.30,
  dragging: false,
  lastX: 0, lastY: 0,
}};

const holes = [];
const asteroids = [];
const colors = (GALAXY.metadata && GALAXY.metadata.gate_colors) || {{
  dead: "#e5484d", vacuity: "#f2b544", model: "#3e7bfa",
  readback: "#b45be6", hygiene: "#30a46c", unresolved: "#8d8d8d",
}};

/* ---- build the scene ------------------------------------------------- */
(function buildScene() {{
  const H = GALAXY.barriers || [];
  const HZ = GALAXY.horizons || [];
  const R = 2.1;                       // hole radius in world units
  const RING = 1.45 * R;               // event-horizon ring radius
  const orbit = TAU / Math.max(1, H.length);
  H.forEach((bar, i) => {{
    const edge = hash01(bar.name);
    holes.push({{
      name: bar.name,
      x: Math.cos(i * orbit + edge) * 3.1,
      y: Math.sin(i * orbit + edge) * 3.1,
      z: (i % 2 === 0 ? 1 : -1) * 0.5,
      desc: bar.description || "",
      decls: (bar.declarations || []).length,
      edge: edge,
      horizon: HZ[i] || {{ proven: [], rendered: [], boundary: [] }},
    }});
  }});
  (GALAXY.asteroids || []).forEach((a) => {{
    const theta = rng() * TAU;
    const rad = 4.6 + rng() * 2.6;
    asteroids.push({{
      label: a.label || "?",
      gate: a.gate || "unresolved",
      color: a.color || colors[a.gate] || colors.unresolved,
      detail: a.detail || "",
      radius: clamp((a.radius || 1) * 0.05, 0.028, 0.13),
      x: Math.cos(theta) * rad,
      y: (rng() - 0.5) * 2.4,
      z: Math.sin(theta) * rad,
    }});
  }});
  buildLegend();
}})();

function buildLegend() {{
  const seen = {{}};
  asteroids.forEach((a) => {{ seen[a.gate] = a.color; }});
  const names = {{ dead: "DEAD (relativizing)", vacuity: "vacuity / Gate 5",
                  model: "model / Gate 2", readback: "fidelity / Gate 3+4",
                  hygiene: "hygiene / Gate 6", unresolved: "unresolved" }};
  const order = ["dead", "vacuity", "model", "readback", "hygiene", "unresolved"];
  const ul = document.getElementById("legendList");
  order.forEach((g) => {{
    if (!seen[g]) return;
    const li = document.createElement("li");
    li.innerHTML = `<span class="swatch" style="background:${seen[g]}"></span>`
      + `<span>${names[g] || g}</span>`;
    ul.appendChild(li);
  }});
  const li = document.createElement("li");
  li.style.marginTop = "8px";
  li.innerHTML = `<span class="swatch" style="background:#0b0f1a;border:1px solid #3e4c63"></span>`
    + "<span>residual freedom</span>";
  ul.appendChild(li);
}}

/* ---- projection math ------------------------------------------------- */
function project(x, y, z) {{
  const cy = Math.cos(scenes.yaw), sy = Math.sin(scenes.yaw);
  const cp = Math.cos(scenes.pitch), sp = Math.sin(scenes.pitch);
  // rotate Y
  let x1 = x * cy - z * sy;
  let z1 = x * sy + z * cy;
  // rotate X (pitch)
  let y1 = y * cp - z1 * sp;
  let z2 = y * sp + z1 * cp;
  const f = 4.0;                       // camera distance
  const persp = f / (f + z2 + 2.0);    // z2 + 2 centers the scene
  return {{ x: x1 * persp, y: y1 * persp, s: persp }};
}}

/* ---- render loop ----------------------------------------------------- */
const canvas = document.getElementById("glx");
const ctx = canvas.getContext("2d");
let W = 0, Hpx = 0;

function resize() {{
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  W = window.innerWidth; Hpx = window.innerHeight;
  canvas.width = W * dpr; canvas.height = Hpx * dpr;
  canvas.style.width = W + "px"; canvas.style.height = Hpx + "px";
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}}
window.addEventListener("resize", resize);
resize();

function draw() {{
  ctx.clearRect(0, 0, W, Hpx);
  const cx = W / 2, cy = Hpx / 2;
  scenes.yaw += (scenes.targetYaw - scenes.yaw) * 0.06;
  scenes.pitch += (scenes.targetPitch - scenes.pitch) * 0.06;

  /* stars (residual freedom) */
  ctx.fillStyle = "rgba(255,255,255,0.55)";
  for (let i = 0; i < 220; i++) {{
    const sx = (hash01("s" + i) * W), sy = (hash01("t" + i) * Hpx);
    ctx.globalAlpha = 0.12 + hash01("u" + i) * 0.5;
    ctx.fillRect(sx, sy, 1, 1);
  }}
  ctx.globalAlpha = 1;

  /* asteroids — draw from far to near */
  const depthOrder = asteroids
    .map((a, idx) => {{ const p = project(a.x, a.y, a.z); return {{ a, p, idx }}; }})
    .sort((m, n) => n.p.s - m.p.s);
  depthOrder.forEach(({{ a, p }}) => {{
    const px = cx + p.x * W * 0.36;
    const py = cy + p.y * Hpx * 0.36;
    if (px < -60 || px > W + 60 || py < -60 || py > Hpx + 60) return;
    const r = a.radius * p.s * Hpx * 2.2;
    const grad = ctx.createRadialGradient(px, py, 0, px, py, r * 3);
    grad.addColorStop(0, a.color);
    grad.addColorStop(0.35, a.color + "cc");
    grad.addColorStop(1, "transparent");
    ctx.globalAlpha = clamp(p.s * 1.4, 0.25, 1);
    ctx.fillStyle = grad;
    ctx.beginPath(); ctx.arc(px, py, r * 3, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
    ctx.fillStyle = a.color;
    ctx.beginPath(); ctx.arc(px, py, r * 1.7, 0, TAU); ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.globalAlpha = 0.75;
    ctx.beginPath(); ctx.arc(px - r, py - r, r * 0.5, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }});

  /* black holes + event horizons */
  holes.forEach((h) => {{
    const p = project(h.x, h.y, h.z);
    const px = cx + p.x * W * 0.36;
    const py = cy + p.y * Hpx * 0.36;
    const ringR = RING * p.s * Hpx * 0.36;
    const holeR = R * p.s * Hpx * 0.36;
    if (ringR <= 0) return;

    // event horizon — faint blue ring, elliptical to fake 3D
    ctx.strokeStyle = "rgba(120,170,255,0.28)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(px, py, ringR, ringR * 0.45, 0, 0, TAU);
    ctx.stroke();

    // horizon stat ticks
    const horiz = h.horizon || {{}};
    const ticks = (horiz.proven || []).length;
    const marks = (horiz.rendered || []).length + (horiz.boundary || []).length;
    drawTicks(px, py, ringR, ticks, "#55d6be");
    drawTicks(px, py, ringR, marks, "#f2c14e", Math.PI, ticks);

    // black hole disk
    const grad = ctx.createRadialGradient(px - holeR * 0.2, py - holeR * 0.2, 0,
                                          px, py, holeR);
    grad.addColorStop(0, "#000");
    grad.addColorStop(0.55, "#0a0e1a");
    grad.addColorStop(1, "#161d33");
    ctx.fillStyle = grad;
    ctx.beginPath(); ctx.arc(px, py, holeR, 0, TAU); ctx.fill();
    ctx.strokeStyle = "rgba(140,160,255,0.5)";
    ctx.lineWidth = 1;
    ctx.stroke();

    // glow
    ctx.strokeStyle = "rgba(80,110,220,0.16)";
    ctx.lineWidth = holeR * 0.5;
    ctx.beginPath(); ctx.arc(px, py, holeR * 0.8, 0, TAU); ctx.stroke();

    // label
    ctx.fillStyle = "#d9e2ec";
    ctx.font = "600 13px ui-monospace, Menlo, monospace";
    ctx.textAlign = "center";
    ctx.fillText(h.name, px, py + holeR + 22);
    ctx.fillStyle = "#8aa0b8";
    ctx.font = "11px ui-monospace, Menlo, monospace";
    const declCount = h.decls;
    ctx.fillText(declCount + " declared · " + (horiz.boundary || []).length
                 + " at boundary", px, py + holeR + 38);
  }});

  requestAnimationFrame(draw);
}}

function drawTicks(px, py, ringR, count, color, angleStart = 0, offset = 0) {{
  if (count <= 0) return;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  for (let i = 0; i < count; i++) {{
    const a = angleStart + (i + offset) / Math.max(count + offset, 1) * Math.PI;
    const x0 = px + Math.cos(a) * ringR * 0.82;
    const y0 = py + Math.sin(a) * ringR * 0.42;
    const x1 = px + Math.cos(a) * ringR * 1.06;
    const y1 = py + Math.sin(a) * ringR * 0.54;
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
  }}
}}

/* ---- hover tooltip --------------------------------------------------- */
const tip = document.getElementById("tip");

function hitTest(mx, my) {{
  const cx = W / 2, cy = Hpx / 2;
  let best = null, bestD = 14; // px threshold
  const candidates = [...asteroids.map((a, idx) => ({ a, idx })),
                      ...holes.map((h, idx) => ({ h, idx }))];
  for (const el of candidates) {{
    const p = el.a ? project(el.a.x, el.a.y, el.a.z) : project(el.h.x, el.h.y, el.h.z);
    const clean = el.a ? el.a : el.h;
    const px = cx + p.x * W * 0.36;
    const py = cy + p.y * Hpx * 0.36;
    const rr = el.a ? el.a.radius * p.s * Hpx * 2.2 : R * p.s * Hpx * 0.36;
    const d = Math.hypot(mx - px, my - py);
    if (d - rr < bestD && d < rr + 8) {{
      bestD = d - rr; best = { p, clean, asteroid: !!el.a };
    }}
  }}
  return best;
}}

function showTip(x, y, el) {{
  if (!el) {{
    tip.style.opacity = "0";
    return;
  }}
  const c = el.clean;
  let title = c.name || c.label || "?";
  let gate = "";
  let body = "";
  if (el.asteroid) {{
    gate = `<span class="t-gate" style="background:${c.color}22;color:${c.color}">`
      + `gate: ${c.gate}</span>`;
    body = `<div class="t-body">${esc(c.detail || "")}</div>`;
  }} else {{
    const horiz = c.horizon || {{}};
    gate = `<span class="t-gate" style="background:#55d6be22;color:#55d6be">barrier</span>`;
    body = `<div class="t-body">${esc(c.desc || "")}<br>`
      + `proven: ${(horiz.proven||[]).length} · rendered: ${(horiz.rendered||[]).length}`
      + ` · boundary: ${(horiz.boundary||[]).length}</div>`;
  }}
  tip.innerHTML = `<div class="t-title">${esc(title)}</div>${gate}${body}`;
  const tw = tip.offsetWidth, th = tip.offsetHeight;
  const pad = 14;
  tip.style.opacity = "1";
  const tx = clamp(x + 14, pad, W - tw - pad);
  const ty = clamp(y + 14, pad, Hpx - th - pad);
  tip.style.left = tx + "px";
  tip.style.top = ty + "px";
}}
function esc(s) {{
  return String(s).replace(/[&<>"]/g, (ch) => ({{
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;",
  }}[ch]));
}}

/* ---- interaction ----------------------------------------------------- */
canvas.addEventListener("pointerdown", (e) => {{
  scenes.dragging = true; scenes.lastX = e.clientX; scenes.lastY = e.clientY;
  canvas.classList.add("drag"); canvas.setPointerCapture(e.pointerId);
}});
canvas.addEventListener("pointermove", (e) => {{
  if (scenes.dragging) {{
    scenes.targetYaw += (e.clientX - scenes.lastX) * 0.005;
    scenes.targetPitch = clamp(scenes.targetPitch + (e.clientY - scenes.lastY) * 0.004,
                               -0.7, 1.1);
    scenes.lastX = e.clientX; scenes.lastY = e.clientY;
  }} else {{
    const el = hitTest(e.clientX, e.clientY);
    showTip(e.clientX, e.clientY, el);
    canvas.style.cursor = el ? "pointer" : "grab";
  }}
}});
canvas.addEventListener("pointerup", (e) => {{
  scenes.dragging = false; canvas.classList.remove("drag");
}});
canvas.addEventListener("leave", () => tip.style.opacity = "0");
</script>
</body>
</html>
"""


# --------------------------------------------------------------------------
# Renderer driver
# --------------------------------------------------------------------------
def render(galaxy: dict, title: str | None = None) -> str:
    """Render the Galaxy model (dict) into a self-contained HTML string.

    The TEMPLATE keeps its literal CSS/JS braces escaped as ``{{``/``}}`` (so
    the string survives future `.format()` use); we collapse them back to
    singles here since we substitute the JSON payload via replace().

    Volatile metadata (`generated`) is dropped so the same model always
    renders byte-identical HTML (the regen CI smoke compares outputs).
    """
    data = dict(galaxy)
    if title:
        data.setdefault("metadata", {})["title"] = title
    meta = data.setdefault("metadata", {})
    meta.pop("generated", None)
    payload = json.dumps(data, ensure_ascii=False)
    # Embed the JSON safely: escape </script> sequences to keep the inline
    # script intact even if a user-controlled field contains such a string.
    payload = payload.replace("</", "<\\/")
    html = TEMPLATE.replace("{{", "{").replace("}}", "}")
    return html.replace("__GALAXY_JSON__", payload)


def load_model(repo: Path, json_file: str | None) -> dict:
    """Load the Galaxy model from a JSON file or by scanning the repo."""
    if json_file:
        return json.loads(Path(json_file).read_text(encoding="utf-8"))
    return build_galaxy(repo).to_dict()


def serve(directory: Path, port: int) -> None:
    """Serve the directory over HTTP on localhost:port (blocking)."""
    handler = _QuietHandler
    httpd = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"serving {directory} at http://localhost:{port}/ (Ctrl+C to stop)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="PleaNP repo root (used when no --json-file)")
    ap.add_argument("--json-file", help="path to a Galaxy model JSON (offline mode)")
    ap.add_argument("--out", default="galaxy.html", help="output HTML path")
    ap.add_argument("--serve", type=int, metavar="PORT",
                    help="after writing, serve the output directory on PORT")
    ap.add_argument("--open", action="store_true", help="open the HTML in a browser")
    args = ap.parse_args(argv)

    if args.json_file:
        repo = Path(args.repo).resolve()
    else:
        repo = resolve_repo(args.repo)
    model = load_model(repo, args.json_file)

    html = render(model)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"wrote {out} ({len(html)} bytes)")

    if args.open:
        webbrowser.open(out.resolve().as_uri())
    if args.serve:
        serve(out.parent, args.serve)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())