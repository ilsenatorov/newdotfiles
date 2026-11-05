#!/usr/bin/env python3
"""Check STL files for printing without supports, in the orientation they were exported.

Usage: printcheck.py [--bed 256x256x256] [--allow-bridges] [--allow-supports]
                     [--json results.json] a.stl b.stl
Exits non-zero if any check fails.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import trimesh

BED_TOLERANCE = 0.01  # mm above the bed still counted as touching it
AREA_TOLERANCE = 0.01  # mm2 ignored as mesh noise
# Faces designed at exactly 45 degrees land slightly either side after meshing.
ANGLE_MARGIN = 0.01


def where(mesh: trimesh.Trimesh, mask: np.ndarray) -> str:
    points = mesh.triangles[mask].reshape(-1, 3)
    low, high = points.min(axis=0), points.max(axis=0)
    return f"X {low[0]:.1f} to {high[0]:.1f}, Y {low[1]:.1f} to {high[1]:.1f}, Z {low[2]:.1f} to {high[2]:.1f}"


def check_part(path: Path, bed: tuple[float, float, float], allow_bridges: bool, allow_supports: bool) -> list[dict]:
    mesh = trimesh.load_mesh(path)
    results = []

    def add(name: str, status: str, detail: str = "") -> None:
        results.append({"part": path.stem, "check": name, "status": status, "detail": detail})

    add("closed mesh", "pass" if mesh.is_watertight else "fail",
        "" if mesh.is_watertight else "The mesh has holes, so slicers may misread it.")

    low, high = mesh.bounds
    size = high - low
    add("sits on the bed", "pass" if abs(low[2]) < BED_TOLERANCE else "fail", f"lowest point at Z = {low[2]:.2f} mm")
    fits = all(size[i] <= bed[i] for i in range(3))
    add("fits the printer", "pass" if fits else "fail", f"{size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm")

    centers, normals, areas = mesh.triangles_center, mesh.face_normals, mesh.area_faces
    on_bed = centers[:, 2] - low[2] < BED_TOLERANCE
    down = normals[:, 2] < 0
    contact = areas[on_bed & down].sum()
    footprint = size[0] * size[1]
    stable = contact >= 0.15 * footprint
    add("bed contact", "pass" if stable else "warn",
        f"{contact:.0f} mm2 touches the bed" + ("" if stable else f", under 15% of its {footprint:.0f} mm2 footprint; consider a brim"))

    roofs = ~on_bed & (normals[:, 2] < -0.999)
    roof_area = areas[roofs].sum()
    if roof_area < AREA_TOLERANCE:
        add("no flat roofs", "pass", "nothing needs bridging")
    else:
        add("no flat roofs", "warn" if allow_bridges else "fail", f"{roof_area:.1f} mm2 at {where(mesh, roofs)}")

    steep = ~on_bed & (normals[:, 2] < -np.cos(np.radians(45)) - ANGLE_MARGIN) & ~roofs
    steep_area = areas[steep].sum()
    if steep_area < AREA_TOLERANCE:
        add("no overhang past 45 degrees", "pass")
    else:
        add("no overhang past 45 degrees", "warn" if allow_supports else "fail", f"{steep_area:.1f} mm2 at {where(mesh, steep)}")
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("models", nargs="+", type=Path)
    ap.add_argument("--bed", default="256x256x256", help="Printer build volume in mm (default: Bambu Lab A1)")
    ap.add_argument("--allow-bridges", action="store_true")
    ap.add_argument("--allow-supports", action="store_true")
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()

    bed = tuple(float(v) for v in args.bed.split("x"))
    results = []
    for model in args.models:
        if not model.is_file():
            sys.exit(f"Model not found: {model}")
        results += check_part(model, bed, args.allow_bridges, args.allow_supports)
    for r in results:
        print(f"[{r['status'].upper():4}] {r['part']}: {r['check']}" + (f": {r['detail']}" if r["detail"] else ""))
    if args.json:
        args.json.write_text(json.dumps(results, indent=2))
    failed = [r for r in results if r["status"] == "fail"]
    print(f"\n{len(failed)} failed, {sum(r['status'] == 'warn' for r in results)} warnings, {len(results)} checks")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
