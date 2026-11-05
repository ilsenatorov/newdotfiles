#!/usr/bin/env python3
"""Build a self-contained HTML report for a printed part, ready for the Artifact tool.

All images are embedded, so the page works anywhere. See print-part's SKILL.md for usage.
"""

import argparse
import base64
import json
import sys
from html import escape
from pathlib import Path

STYLE = """
/* Workshop job sheet: plain data first, with the images on neutral plates. */
:root {
  --bg: #f1f4f3; --surface: #fbfcfc; --fg: #16211e; --muted: #56655f; --line: #cdd6d2;
  --accent: #0a6b5d; --good: #1c7a4b; --warn: #a85f00; --bad: #b3261e; --plate: #ffffff;
  --display: "Archivo", "Helvetica Neue", Arial, sans-serif;
  --body: "Archivo", "Helvetica Neue", Arial, sans-serif;
  --data: "IBM Plex Mono", ui-monospace, Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #121816; --surface: #1a2220; --fg: #e6ecea; --muted: #9dacA6; --line: #33403b;
  --accent: #55c7b1; --good: #63cf95; --warn: #e8ab55; --bad: #f28b82; color-scheme: dark;
} }
:root[data-theme="dark"] {
  --bg: #121816; --surface: #1a2220; --fg: #e6ecea; --muted: #9dacA6; --line: #33403b;
  --accent: #55c7b1; --good: #63cf95; --warn: #e8ab55; --bad: #f28b82; color-scheme: dark;
}
body { background: var(--bg); color: var(--fg); font-family: var(--body); font-size: 16px; line-height: 1.5; }
main { max-width: 1040px; margin: 0 auto; display: grid; gap: 40px; padding-block: 32px 56px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
h1 { font-family: var(--display); font-size: clamp(30px, 6vw, 44px); line-height: 1.1; font-weight: 700; margin: 0; text-wrap: balance; }
h2 { font-family: var(--display); font-size: 21px; font-weight: 650; margin: 0 0 14px; text-wrap: balance; }
header { display: grid; gap: 12px; }
.summary { margin: 0; max-width: 65ch; color: var(--muted); font-size: 18px; }
.status { justify-self: start; font-family: var(--data); font-size: 13px; padding: 3px 10px; border: 1px solid currentColor; border-radius: 3px; }
.pass { color: var(--good); } .warn { color: var(--warn); } .fail { color: var(--bad); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
th, td { text-align: left; padding: 9px 14px 9px 0; border-bottom: 1px solid var(--line); vertical-align: top; }
th { font-size: 12px; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); font-weight: 600; }
td.num { font-family: var(--data); white-space: nowrap; }
tr.total td { font-weight: 650; }
.settings { margin: 12px 0 0; color: var(--muted); font-size: 14px; max-width: 75ch; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr)); gap: 16px; }
figure { margin: 0; display: grid; gap: 6px; min-width: 0; }
figure img { display: block; width: 100%; height: auto; background: var(--plate); border: 1px solid var(--line); }
figcaption { font-family: var(--data); font-size: 13px; color: var(--muted); }
ul { margin: 0; padding-left: 20px; display: grid; gap: 8px; max-width: 75ch; }
code { font-family: var(--data); font-size: 14px; overflow-wrap: anywhere; }
.files { list-style: none; padding: 0; }
"""


def data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def label(path: Path) -> str:
    return path.stem.replace("_", " ")


def figures(paths: list[Path]) -> str:
    return "\n".join(
        f'<figure><img src="{data_uri(p)}" alt="{escape(label(p))}" loading="lazy"><figcaption>{escape(label(p))}</figcaption></figure>'
        for p in paths
    )


def estimates_section(data: dict) -> str:
    def row(name: str, stats: dict, css: str = "") -> str:
        return (f'<tr class="{css}"><td>{escape(name)}</td><td class="num">{escape(stats["time"])}</td>'
                f'<td class="num">{escape(stats["total_time"])}</td><td class="num">{stats["filament_g"]:.1f} g</td>'
                f'<td class="num">{stats["cost"]:.2f}</td><td class="num">{stats["layers"]}</td></tr>')

    rows = "".join(row(name, stats) for name, stats in data["parts"].items())
    if "plate" in data:
        rows += row("Full plate", data["plate"], "total")
    s = data["settings"]
    brim = "automatic brim" if s["brim_mm"] is None else f'{s["brim_mm"]} mm brim'
    settings = (f'{s["material"].upper()} on a {s["plate"]}, {s["layer_height"]} mm layers, {s["walls"]} walls, '
                f'{s["infill_percent"]}% infill, {"with" if s["supports"] else "no"} supports, {brim}.')
    notes = "".join(f"<li>{escape(n)}</li>" for n in data.get("notes", []))
    notes = f"<h2>Slicer messages</h2><ul>{notes}</ul>" if notes else ""
    return f"""<section><h2>Print estimate</h2><div class="scroll"><table>
<thead><tr><th>Part</th><th>Print time</th><th>With start routine</th><th>Filament</th><th>Cost</th><th>Layers</th></tr></thead>
<tbody>{rows}</tbody></table></div>
<p class="settings">{escape(settings)} Sliced by {escape(data["slicer"])}. These are predictions, not measurements. Cost uses the price in Bambu's profile.</p>
{notes}</section>"""


def checks_section(results: list[dict]) -> str:
    rows = "".join(
        f'<tr><td>{escape(r["part"])}</td><td>{escape(r["check"])}</td><td class="num {r["status"]}">{r["status"].upper()}</td><td>{escape(r["detail"])}</td></tr>'
        for r in results
    )
    return f"""<section><h2>Printability checks</h2><div class="scroll"><table>
<thead><tr><th>Part</th><th>Check</th><th>Result</th><th>Detail</th></tr></thead><tbody>{rows}</tbody></table></div></section>"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--title", required=True)
    ap.add_argument("--summary", default="")
    ap.add_argument("--estimates", type=Path)
    ap.add_argument("--printcheck", type=Path)
    ap.add_argument("--render", nargs="*", type=Path, default=[])
    ap.add_argument("--toolpath", nargs="*", type=Path, default=[])
    ap.add_argument("--file", action="append", default=[], help="Project file to list by its path")
    ap.add_argument("--note", action="append", default=[], help="Risk or next step to highlight")
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    missing = [str(p) for p in [*args.render, *args.toolpath] if not p.is_file()]
    if missing:
        sys.exit(f"Images not found: {missing}")

    results = json.loads(args.printcheck.read_text()) if args.printcheck else []
    failed = sum(r["status"] == "fail" for r in results)
    warned = sum(r["status"] == "warn" for r in results)
    if failed:
        status = ("fail", f"{failed} printability check{'s' if failed != 1 else ''} failed")
    elif warned:
        status = ("warn", f"Printable, with {warned} warning{'s' if warned != 1 else ''}")
    elif results:
        status = ("pass", f"All {len(results)} printability checks passed")
    else:
        status = ("warn", "Printability not checked")

    sections = []
    if args.note:
        items = "".join(f"<li>{escape(n)}</li>" for n in args.note)
        sections.append(f"<section><h2>Before you print</h2><ul>{items}</ul></section>")
    if args.estimates:
        sections.append(estimates_section(json.loads(args.estimates.read_text())))
    if args.render:
        sections.append(f'<section><h2>FreeCAD renders</h2><div class="grid">{figures(args.render)}</div></section>')
    if args.toolpath:
        sections.append(f'<section><h2>Sliced toolpaths</h2><div class="grid">{figures(args.toolpath)}</div></section>')
    if results:
        sections.append(checks_section(results))
    if args.file:
        items = "".join(f"<li><code>{escape(str(Path(f).resolve()))}</code></li>" for f in args.file)
        sections.append(f'<section><h2>Files on your machine</h2><ul class="files">{items}</ul></section>')

    title = escape(args.title)
    summary = f'<p class="summary">{escape(args.summary)}</p>' if args.summary else ""
    html = f"""<title>{title}</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>{STYLE}</style>
<main>
<header><h1>{title}</h1>{summary}<span class="status {status[0]}">{escape(status[1])}</span></header>
{''.join(sections)}
</main>
"""
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(html)
    print(f"{args.out} ({args.out.stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
