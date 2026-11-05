#!/usr/bin/env python3
"""Slice STL files with Bambu Studio's A1 profiles and report estimates.

Usage:
  slice.py --out DIR [--material petg] [--layer-height 0.2] [--walls 4] [--infill 40]
           [--layers 0.2,3.0] [--supports] [--brim 5] a.stl b.stl

Slices each part alone, then all parts on one plate. Writes estimates.json, a
plate.3mf to open in Bambu Studio and, for each part, toolpath PNGs of the layers
at the given Z heights. Run with a Python that has matplotlib for the images.
"""

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

APP = Path("/opt/bambustudio-bin/bin/bambu-studio")
PROFILES = Path("/opt/bambustudio-bin/resources/profiles/BBL")
MACHINE = "Bambu Lab A1 0.4 nozzle"
MATERIALS = {"petg": "Bambu PETG Basic @BBL A1", "pla": "Bambu PLA Basic @BBL A1"}


def find_profile(kind: str, name: str) -> Path:
    matches = sorted((PROFILES / kind).rglob(f"{name}.json"), key=lambda p: len(p.parts))
    if not matches:
        raise RuntimeError(f"No {kind} profile named '{name}' in {PROFILES / kind}")
    return matches[0]


def resolve_profile(kind: str, name: str) -> dict:
    """Merge a profile with its parents.

    The command line ignores `inherits` and `include` and silently falls back to
    defaults. That produces a successful slice with the wrong material and speeds.
    """
    data = json.loads(find_profile(kind, name).read_text())
    merged = resolve_profile(kind, data["inherits"]) if data.get("inherits") else {}
    for included in data.get("include", []):
        merged.update(resolve_profile(kind, included))
    merged.update(data)
    merged.pop("include", None)
    merged.pop("inherits", None)
    return merged


def process_name(layer_height: float) -> str:
    """Bambu names these by height and style, such as '0.16mm Optimal @BBL A1'."""
    names = sorted(p.stem for p in (PROFILES / "process").glob("*mm * @BBL A1.json"))
    matches = [n for n in names if n.startswith(f"{layer_height:.2f}mm ")]
    if not matches:
        raise RuntimeError(f"No A1 profile for {layer_height} mm layers. Available: {sorted({n.split()[0] for n in names})}")
    standard = [n for n in matches if " Standard " in n]
    return (standard or matches)[0]


def write_profiles(folder: Path, args) -> tuple[Path, Path, Path, dict]:
    process = resolve_profile("process", process_name(args.layer_height))
    process.update(wall_loops=str(args.walls), sparse_infill_density=f"{args.infill}%")
    if args.supports:
        process["enable_support"] = "1"
    if args.brim is not None:
        process.update(brim_type="outer_only" if args.brim > 0 else "no_brim", brim_width=str(args.brim))
    filament = resolve_profile("filament", MATERIALS.get(args.material, args.material))
    paths = []
    for kind, data in (("machine", resolve_profile("machine", MACHINE)), ("process", process), ("filament", filament)):
        path = folder / f"{kind}.json"
        path.write_text(json.dumps(data))
        paths.append(path)
    return paths[0], paths[1], paths[2], filament


def run_slicer(models: list[Path], out: Path, args) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        machine, process, filament_path, filament = write_profiles(Path(tmp), args)
        cmd = ["xvfb-run", "-a", "bambu-studio", "--debug", "2", "--slice", "0", "--arrange", "1", "--orient", "0",
               "--curr-bed-type", args.plate, "--load-settings", f"{machine};{process}",
               "--load-filaments", str(filament_path), "--outputdir", str(out), "--export-3mf", "plate.3mf"]
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        proc = subprocess.run(cmd + [str(m) for m in models], capture_output=True, text=True, timeout=args.timeout, env=env)

    result_file = out / "result.json"
    result = json.loads(result_file.read_text()) if result_file.is_file() else {}
    if proc.returncode or result.get("return_code") or not result.get("sliced_plates"):
        reason = result.get("error_string") or (proc.stdout + proc.stderr).strip()[-800:]
        raise RuntimeError(f"Bambu Studio failed on {[m.name for m in models]} (exit {proc.returncode}): {reason}")

    plate = result["sliced_plates"][0]
    with zipfile.ZipFile(out / "plate.3mf") as archive:
        info = archive.read("Metadata/slice_info.config").decode()
    outside = 'key="outside" value="true"' in info
    types = re.findall(r'<filament\b[^>]*?\stype="([^"]+)"', info)
    expected = filament["filament_type"][0]
    # Guards against the silent fallback described in resolve_profile.
    if types != [expected]:
        raise RuntimeError(f"Sliced with filament {types}, expected {expected}. The profile was not applied.")

    gcode = (out / "plate_1.gcode").read_text(errors="replace")
    header = re.search(r"model printing time: ([^;]+); total estimated time: (.+)", gcode)
    layers = re.search(r"total layer number: (\d+)", gcode)
    grams = sum(f["total_used_g"] for f in plate["filaments"])
    return {
        "time": header[1].strip(),
        "total_time": header[2].strip(),
        "print_minutes": round(plate["main_predication"] / 60, 1),
        "total_minutes": round(plate["total_predication"] / 60, 1),
        "filament_g": round(grams, 2),
        "cost": round(grams / 1000 * float(filament["filament_cost"][0]), 3),
        "layers": int(layers[1]) if layers else None,
        "outside_bed": outside,
        "warning": plate.get("warning_message") or "",
        "feature_seconds": {k: round(v) for k, v in plate["feature_type_times"].items()},
    }


def arc_points(x, y, nx, ny, i, j, clockwise, step=0.25):
    cx, cy = x + i, y + j
    radius = math.hypot(i, j)
    start, end = math.atan2(y - cy, x - cx), math.atan2(ny - cy, nx - cx)
    sweep = end - start
    if clockwise and sweep >= 0:
        sweep -= 2 * math.pi
    elif not clockwise and sweep <= 0:
        sweep += 2 * math.pi
    count = max(2, int(abs(sweep) * radius / step))
    points = [(cx + radius * math.cos(start + sweep * k / count), cy + radius * math.sin(start + sweep * k / count))
              for k in range(1, count)]
    return points + [(nx, ny)]


def read_layers(gcode: Path) -> dict[float, list]:
    """Extruding moves per layer as (feature, x0, y0, x1, y1). Arcs become short lines.

    Everything before the first layer is skipped, because the start routine's
    purge lines aren't part of the model.
    """
    layers: dict[float, list] = {}
    z = kind = x = y = None
    for line in gcode.read_text(errors="replace").splitlines():
        if line.startswith("; Z_HEIGHT:"):
            z = round(float(line.split(":")[1]), 3)
            layers.setdefault(z, [])
        elif line.startswith("; FEATURE:"):
            kind = line.split(":")[1].strip()
        elif line[:3] in ("G0 ", "G1 ", "G2 ", "G3 "):
            words = {w[0]: float(w[1:]) for w in line.split(";")[0].split()[1:] if re.fullmatch(r"[XYIJEF]-?[\d.]+", w)}
            nx, ny = words.get("X", x), words.get("Y", y)
            if z is not None and kind != "Custom" and words.get("E", 0) > 0 and None not in (x, y, nx, ny):
                if line[1] in "23":
                    px, py = x, y
                    for ax, ay in arc_points(x, y, nx, ny, words.get("I", 0), words.get("J", 0), line[1] == "2"):
                        layers[z].append((kind, px, py, ax, ay))
                        px, py = ax, ay
                elif (nx, ny) != (x, y):
                    layers[z].append((kind, x, y, nx, ny))
            x, y = nx, ny
    return {k: v for k, v in layers.items() if v}


COLORS = {"Inner wall": "#f2b705", "Outer wall": "#d9480f", "Overhang wall": "#1864ab",
          "Sparse infill": "#c2255c", "Internal solid infill": "#7048e8", "Top surface": "#e03131",
          "Bottom surface": "#7048e8", "Bridge": "#1c7ed6", "Gap infill": "#2b8a3e", "Skirt": "#868e96", "Brim": "#868e96"}


def draw_layers(layers: dict, stem: str, out: Path, z_targets: list[float], line_width: float = 0.42) -> list[str]:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib.collections import LineCollection
    except ImportError:
        print("matplotlib is missing, so toolpath images were skipped", file=sys.stderr)
        return []
    images = []
    for z in sorted({min(layers, key=lambda k: abs(k - t)) for t in z_targets}):
        moves = [m for m in layers[z] if m[0] not in ("Skirt", "Brim")] or layers[z]
        xs = [m[1] for m in moves] + [m[3] for m in moves]
        ys = [m[2] for m in moves] + [m[4] for m in moves]
        pad = 2
        span_x, span_y = max(xs) - min(xs) + 2 * pad, max(ys) - min(ys) + 2 * pad
        scale = 11 / max(span_x, span_y)  # inches per mm
        fig, ax = plt.subplots(figsize=(span_x * scale, span_y * scale + 0.5), dpi=130)
        for kind in sorted({m[0] for m in moves if m[0]}):
            segments = [((m[1], m[2]), (m[3], m[4])) for m in moves if m[0] == kind]
            # Drawn at true extrusion width, so gaps on the image are real gaps.
            ax.add_collection(LineCollection(segments, colors=COLORS.get(kind, "#495057"), label=kind,
                                             linewidths=line_width * scale * 72, capstyle="round"))
        ax.set_xlim(min(xs) - pad, max(xs) + pad)
        ax.set_ylim(min(ys) - pad, max(ys) + pad)
        ax.set_aspect("equal")
        ax.set_title(f"{stem}, layer at Z = {z:g} mm", fontsize=11)
        ax.tick_params(labelsize=8)
        ax.legend(fontsize=7, loc="upper right", framealpha=0.85)
        path = out / f"{stem}_layer_z{z:g}.png"
        fig.tight_layout()
        fig.savefig(path)
        plt.close(fig)
        images.append(str(path))
    return images


def bridge_heights(layers: dict) -> list[float]:
    return sorted(z for z, moves in layers.items() if any(m[0] == "Bridge" for m in moves))


def fmt(stats: dict) -> str:
    return (f"{stats['time']:>10} print  {stats['total_time']:>10} total  {stats['filament_g']:6.2f} g  "
            f"{stats['cost']:6.2f}  {stats['layers'] or 0:4d} layers")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("models", nargs="+", type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--material", default="petg", help="petg, pla, or an exact Bambu filament profile name")
    ap.add_argument("--layer-height", type=float, default=0.2)
    ap.add_argument("--walls", type=int, default=3)
    ap.add_argument("--infill", type=int, default=15)
    ap.add_argument("--brim", type=float, help="Brim width in mm. Omit it for Bambu's automatic choice.")
    ap.add_argument("--supports", action="store_true")
    ap.add_argument("--plate", default="Textured PEI Plate")
    ap.add_argument("--layers", default="", help="Z heights for toolpath images, for example 0.2,3.0")
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--keep-gcode", action="store_true")
    args = ap.parse_args()

    if not shutil.which("bambu-studio") or not shutil.which("xvfb-run"):
        sys.exit("Needs Bambu Studio and Xvfb. On Arch: paru -S bambustudio-bin && sudo pacman -S xorg-server-xvfb")
    if not os.access(APP, os.X_OK) or not os.access(PROFILES, os.R_OK):
        sys.exit("Bambu Studio's folder isn't readable, which the AUR package causes on each install or update. "
                 "Fix it with: sudo chmod -R a+rX /opt/bambustudio-bin")
    for model in args.models:
        if not model.is_file():
            sys.exit(f"Model not found: {model}")
    args.out.mkdir(parents=True, exist_ok=True)
    z_targets = [float(v) for v in args.layers.split(",") if v]

    report = {
        "slicer": "Bambu Studio with its own A1 profiles",
        "settings": {"material": args.material, "layer_height": args.layer_height, "walls": args.walls,
                     "infill_percent": args.infill, "brim_mm": args.brim, "supports": args.supports, "plate": args.plate},
        "parts": {},
        "images": [],
        "notes": [],
    }
    with tempfile.TemporaryDirectory() as tmp:
        for model in args.models:
            work = Path(tmp) / model.stem
            stats = run_slicer([model], work, args)
            layers = read_layers(work / "plate_1.gcode")
            stats["bridge_heights_mm"] = bridge_heights(layers)
            report["parts"][model.stem] = stats
            report["images"] += draw_layers(layers, model.stem, args.out, z_targets)
            print(f"{model.stem:<14}{fmt(stats)}")
            if stats["bridge_heights_mm"]:
                print(f"  Bridge toolpaths at Z = {stats['bridge_heights_mm']} mm")
            if args.keep_gcode:
                shutil.copy(work / "plate_1.gcode", args.out / f"{model.stem}.gcode")
            if len(args.models) == 1:
                shutil.copy(work / "plate.3mf", args.out / "plate.3mf")
        if len(args.models) > 1:
            work = Path(tmp) / "_plate"
            stats = run_slicer(args.models, work, args)
            report["plate"] = stats
            shutil.copy(work / "plate.3mf", args.out / "plate.3mf")
            print(f"{'full plate':<14}{fmt(stats)}")

    for name, stats in {**report["parts"], "plate": report.get("plate")}.items():
        if stats and stats["outside_bed"]:
            report["notes"].append(f"{name}: extends outside the printable area")
        if stats and stats["warning"]:
            report["notes"].append(f"{name}: {stats['warning']}")
    for note in report["notes"]:
        print(f"note: {note}")
    (args.out / "estimates.json").write_text(json.dumps(report, indent=2))
    print(f"\nWrote {args.out / 'estimates.json'} and {args.out / 'plate.3mf'}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as err:
        print(err, file=sys.stderr)
        sys.exit(1)
