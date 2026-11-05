#!/usr/bin/env python3
"""Render STEP or STL files to PNGs with FreeCAD's own viewer, without a display.

Usage:
  render.py --out DIR --part a.step --part "b.step@15,0,1.75#e8590c" [options]

A part spec is PATH[@X,Y,Z][#RRGGBB]. @ moves the part, which lets several parts
be shown assembled. Options:
  --views iso,top,front,right,bottom   views to save (default: iso,top,front,right)
  --section x=12                       also save a cut view at this plane (x, y or z)
  --size 1400x1000                     image size in pixels
  --name assembly                      output file prefix (default: first part's name)

Prints one line per image. Exits non-zero if any requested image is missing.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PALETTE = ["1c7ed6", "e8590c", "2f9e44", "ae3ec9", "f08c00", "0ca678"]

# Runs inside FreeCAD. Everything is reported through the status file because
# FreeCAD's GUI swallows stdout and exceptions.
INNER = r'''
import json, os, traceback
cfg = json.loads(os.environ["FC_RENDER_CONFIG"])
status = {"images": [], "error": None}
try:
    import FreeCAD as App, FreeCADGui as Gui, Part, Mesh
    from PySide import QtGui
    # Camera moves animate by default, and an image saved mid-move is tilted or clipped.
    App.ParamGet("User parameter:BaseApp/Preferences/View").SetBool("UseNavigationAnimations", False)
    doc = App.newDocument("render")
    if not Gui.activeDocument():
        Gui.setActiveDocument(doc.Name)
    section = cfg.get("section")
    for i, spec in enumerate(cfg["parts"]):
        name = "P%d" % i
        is_mesh = spec["path"].lower().endswith(".stl")
        if is_mesh:
            obj = doc.addObject("Mesh::Feature", name)
            obj.Mesh = Mesh.Mesh(spec["path"])
        else:
            obj = doc.addObject("Part::Feature", name)
            obj.Shape = Part.read(spec["path"])
        obj.Placement = App.Placement(App.Vector(*spec["pos"]), App.Rotation())
        vo = obj.ViewObject
        vo.ShapeColor = tuple(spec["color"])
        if is_mesh:
            vo.DisplayMode = "Flat Lines"
        else:
            vo.LineColor = (0.1, 0.1, 0.1)
            vo.LineWidth = 1.5
    doc.recompute()
    Gui.updateGui()
    view = Gui.activeDocument().activeView()
    view.setCameraType("Orthographic")
    try:
        view.setAnimationEnabled(False)
        view.setAxisCross(False)
    except Exception:
        pass
    setters = {"iso": view.viewIsometric, "top": view.viewTop, "front": view.viewFront,
               "right": view.viewRight, "bottom": view.viewBottom}
    w, h = cfg["size"]
    def coverage(path):
        """Share of pixels that are not background, sampled on a grid."""
        image = QtGui.QImage(path)
        hits = total = 0
        for y in range(0, image.height(), 8):
            for x in range(0, image.width(), 8):
                total += 1
                hits += QtGui.QColor(image.pixel(x, y)).lightness() < 245
        return hits / max(total, 1)
    def save(label):
        Gui.updateGui()
        view.fitAll()
        Gui.updateGui()
        out = os.path.join(cfg["out"], "%s_%s.png" % (cfg["name"], label))
        view.saveImage(out, w, h, "White")
        status["images"].append(out)
        status.setdefault("coverage", {})[out] = coverage(out)
    for label in cfg["views"]:
        setters[label]()
        save(label)
    if section:
        axis, value = section["axis"], section["value"]
        big = 2000.0
        origin = {"x": (value, -big, -big), "y": (-big, value, -big), "z": (-big, -big, value)}[axis]
        cutter = Part.makeBox(big * 2, big * 2, big * 2, App.Vector(*origin))
        for obj in list(doc.Objects):
            if obj.TypeId != "Part::Feature":
                raise RuntimeError("--section needs STEP input, not STL")
            # obj.Shape already includes the object's placement, so cut it as it stands.
            obj.Shape = obj.Shape.cut(cutter)
        doc.recompute()
        # The cut removes everything above the plane, so look from that side.
        {"x": view.viewRight, "y": view.viewRear, "z": view.viewTop}[axis]()
        save("section_%s%g" % (axis, value))
except Exception:
    status["error"] = traceback.format_exc()
with open(cfg["status"], "w") as f:
    json.dump(status, f)
os._exit(0)
'''


def parse_part(text: str, index: int) -> dict:
    match = re.fullmatch(r"(?P<path>[^@#]+)(?:@(?P<pos>[-\d.,]+))?(?:#(?P<color>[0-9a-fA-F]{6}))?", text)
    if not match:
        sys.exit(f"Bad part spec: {text}")
    path = Path(match["path"]).expanduser().resolve()
    if not path.is_file():
        sys.exit(f"Part file not found: {path}")
    pos = [float(v) for v in match["pos"].split(",")] if match["pos"] else [0.0, 0.0, 0.0]
    if len(pos) != 3:
        sys.exit(f"Position needs X,Y,Z: {text}")
    color = match["color"] or PALETTE[index % len(PALETTE)]
    return {"path": str(path), "pos": pos, "color": [int(color[i : i + 2], 16) / 255 for i in (0, 2, 4)]}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--part", action="append", required=True)
    ap.add_argument("--views", default="iso,top,front,right")
    ap.add_argument("--section")
    ap.add_argument("--size", default="1400x1000")
    ap.add_argument("--name")
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args()

    for tool in ("freecad", "xvfb-run"):
        if not shutil.which(tool):
            sys.exit(f"{tool} is not installed. On Arch: sudo pacman -S freecad xorg-server-xvfb")

    parts = [parse_part(p, i) for i, p in enumerate(args.part)]
    views = [v for v in args.views.split(",") if v]
    bad = set(views) - {"iso", "top", "front", "right", "bottom"}
    if bad:
        sys.exit(f"Unknown views: {sorted(bad)}")
    section = None
    if args.section:
        m = re.fullmatch(r"([xyz])=(-?[\d.]+)", args.section)
        if not m:
            sys.exit("--section must look like x=12")
        section = {"axis": m[1], "value": float(m[2])}
    args.out.mkdir(parents=True, exist_ok=True)
    w, h = (int(v) for v in args.size.split("x"))

    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "fc_render_inner.py"
        script.write_text(INNER)
        status = Path(tmp) / "status.json"
        config = {
            "parts": parts,
            "views": views,
            "section": section,
            "size": [w, h],
            "out": str(args.out.resolve()),
            "name": args.name or Path(parts[0]["path"]).stem,
            "status": str(status),
        }
        env = dict(os.environ, FC_RENDER_CONFIG=json.dumps(config), QT_QPA_PLATFORM="xcb", LIBGL_ALWAYS_SOFTWARE="1")
        env.pop("WAYLAND_DISPLAY", None)
        cmd = ["xvfb-run", "-a", "-s", f"-screen 0 {w}x{h}x24", "freecad", str(script)]
        try:
            proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired:
            print(f"FreeCAD did not finish within {args.timeout} s", file=sys.stderr)
            return 1
        if not status.exists():
            print("FreeCAD exited without running the render script:", file=sys.stderr)
            print((proc.stdout + proc.stderr)[-2000:], file=sys.stderr)
            return 1
        result = json.loads(status.read_text())

    if result["error"]:
        print(result["error"], file=sys.stderr)
    expected = len(views) + bool(section)
    good = [p for p in result["images"] if Path(p).is_file() and Path(p).stat().st_size > 0]
    for path in good:
        print(path)
    blank = [p for p, share in result.get("coverage", {}).items() if share < 0.01]
    for path in blank:
        print(f"Image is blank (part not drawn): {path}", file=sys.stderr)
    if len(good) != expected or result["error"] or blank:
        print(f"{len(good) - len(blank)} of {expected} images are usable", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
