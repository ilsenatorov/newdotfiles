---
name: print-part
description: Turn a written spec into a 3D-printable part: design it as parametric build123d code, check printability, show FreeCAD renders, slice it for print time and filament estimates, and publish a report page. Use this whenever someone wants to design, model, make or 3D print a part, bracket, clip, case, mount, adapter or replacement piece, or hands over requirements for something to print, even if they never mention CAD, build123d or a slicer. Also use it to change or improve a part built this way.
---

# Print part

Takes a part from spec to printable files, with evidence at each step. The default printer is a Bambu Lab A1 with a 0.4 mm nozzle, in PETG or PLA.

Tools: `~/.venvs/build123d` (Python with build123d, trimesh, pyvista, matplotlib), FreeCAD and Bambu Studio. System Python may be too new for build123d's CAD kernel. On a machine without these tools, set them up as follows, after telling the user what you'll install:

```bash
uv venv --python 3.12 ~/.venvs/build123d
uv pip install --python ~/.venvs/build123d/bin/python build123d trimesh pyvista matplotlib
sudo pacman -S --needed freecad xorg-server-xvfb
paru -S bambustudio-bin                     # from the AUR, so read its build script first
sudo chmod -R a+rX /opt/bambustudio-bin     # the package installs as root-only
```

If an install is blocked or fails, report that and let the user decide. Don't work around it.

## 1. Pin down the spec

Save the requirements as `~/Projects/<part>/spec.md`. Work out what the part mates with, what loads it carries, how often it moves and which material to use.

Ask only about what you can't assume safely, and above all about the real dimensions of mating objects. A wrong strap width or screw spacing wastes a print, and no check can catch it. State your other assumptions in `spec.md` and in your reply.

If failure could hurt someone, as with climbing gear, anything overhead or anything holding body weight, don't present a printed part as safe for that job. Design it only for a non-critical role and say so plainly.

## 2. Choose the print orientation first

Orientation decides strength and whether the part prints without supports, so it comes before the shape. Read `references/design-rules.md` now. Tell the user the concept in a sentence or two before modelling.

## 3. Model it

Write `build.py` with every tunable dimension in a frozen `Params` dataclass at the top, with clearances first so they're easy to change after a test print. Export STL and STEP for each part to `out/`. Read `references/build123d-notes.md` for working patterns and known traps.

## 4. Check the geometry

Write `checks.py` for what this design has to do. The generic check can't know this, and these are the checks that find real mistakes:

- **Fit:** no interference between mating parts, tested with boolean intersection.
- **Function:** move parts and test the result. Does a latch catch when pulled? Does it clear when released?
- **Load:** hand estimates of stress and deflection, with the assumed load and material values stated. These are estimates, so call them that.

Then run the generic printability check, which exits non-zero on failure:

```bash
~/.venvs/build123d/bin/python ~/.claude/skills/print-part/scripts/printcheck.py \
  --json out/printcheck.json out/a.stl out/b.stl
```

It checks for a closed mesh, a flat base, bed fit, overhangs past 45 degrees and flat roofs. Add `--allow-bridges` or `--allow-supports` only when the design deliberately needs them, and tell the user.

## 5. Render it and look

Use the freecad-render skill to produce per-part views, an assembled view if there are several parts, and a section through the critical fit. Open the images. Passing checks don't prove the part looks right, and a look often finds what they miss.

## 6. Slice it

Use the slicer-estimate skill with the settings you intend to recommend, drawing toolpaths at the first layer and at the heights of the most delicate features. Open those images too.

If a step shows a problem, fix the model and rerun from step 4, so all results describe the same geometry.

## 7. Publish the report

Build one self-contained page with the renders, estimates and checks:

```bash
~/.venvs/build123d/bin/python ~/.claude/skills/print-part/scripts/make_report.py \
  --title "Part Name" --summary "One or two sentences on what it is and how it works." \
  --estimates out/slice/estimates.json --printcheck out/printcheck.json \
  --render out/freecad/*.png --toolpath out/slice/*.png \
  --file out/a.stl --file out/a.step --file build.py \
  --note "Measure the mating part before printing." --out out/report.html
```

Publish `out/report.html` with the Artifact tool: `file_path` plus `icon: "cube"` on the first publish, and `Artifact` quickstart first as that tool requires. Republish to the same URL after changes. Use `--note` for project-specific risks and things only a real print can settle.

## 8. Reply

Give the report link, then lead with whether the part is ready to test-print. Include print time, filament, recommended material and settings, and the risks the checks can't rule out. Distinguish what was computed from what has been physically tested. Until someone prints it, nothing has been physically tested.

Keep a short `README.md` in the project with print settings, assembly steps and a table of which parameter to change for each likely fit problem.
