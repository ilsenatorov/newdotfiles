---
name: show
description: Use when the user types /show or asks to see, open, view or inspect the whole build, assembly or model of a CAD/3D-printing/PCB repo in FreeCAD (repos with FreeCAD/CadQuery build scripts, .FCStd, .step, or .kicad_pcb files).
---

# /show: the whole build in the FreeCAD GUI

Each repo gets one committed loader, `show.py`, that runs inside FreeCAD and puts everything in one document with as
much detail as the repo has. `/show` = find or write that loader, (re)build if needed, run it, look at it, report.
Worked example: `~/Projects/climbing/ClimbingFan/stand/show.py`.

## 1. Find the loader
`git ls-files '*show.py'`. If one exists and still matches the repo's build, skip to step 3.

## 2. Write the loader (first /show in a repo)
Read the repo's AGENTS.md/CLAUDE.md/README for the build command and outputs first. The loader, in this order:
- **Most detailed source wins:** a jointed-assembly script (exec it in the GUI, so joints get view providers) >
  a pose/assembly builder function > per-part STEP/BREP > plain `.FCStd` files (just open them all).
- **Colours:** FCStd saved headless has no colours. Set `ViewObject.ShapeAppearance = App.Material(DiffuseColor=…)`
  per object by material (printed plastic, TPU black, steel silver, aluminium, battery black, PCB green…).
- **Every `.kicad_pcb`:** export it with
  `kicad-cli pcb export step -f --subst-models --include-tracks --include-pads --include-zones --include-silkscreen --include-soldermask --user-origin <the generator's board origin> -o out/…/board.step <pcb>`,
  then `ImportGui.insert(step, doc.Name)` (keeps the colours). Move the new top-level object (`o not in before and not o.InList`)
  to where the build puts the board. KiCad puts the board's bottom face at z=0, top up. Make the PCB placeholder see-through, but don't hide it.
- **Joints:** hide the `Grounded*` joints (their padlocks bury the model) and keep the moving joints visible.
  Activate `AssemblyWorkbench` when there is an Assembly, then `viewIsometric()` and `fitAll()`.
- Paths from `os.path.dirname(os.path.abspath(__file__))`. FreeCAD sets `__file__` both for `freecad show.py` and for MCP exec with `{'__file__': p}`.
- Mention the loader in the repo's AGENTS.md next to the build commands.

## 3. Build if stale
If the loader's inputs (brep/step cache, `out/…`) are missing or older than the sources, run the repo's build first.

## 4. Run it
- `mcp__freecad__get_rpc_status` succeeds: there's a GUI. Run `exec(open(p).read(), {'__file__': p, '__name__': '__main__'})`
  through `mcp__freecad__execute_code` with `timeout=300`. Don't close the user's other documents.
- No GUI: run `freecad <abs path>/show.py` with `run_in_background`. The MCP RPC comes up with the GUI.

## 5. Check it, then report
Take a screenshot (`execute_code` / `get_view`, and use `focus_object` for the board). Check positions numerically:
an `ImportGui` child's `Shape.BoundBox` is in **local** coordinates, so measure the top-level `App::Part`.
Tell the user what's shown and what is still a placeholder.

| Symptom | Cause / fix |
|---|---|
| `File to load not existing or not readable` | build cache missing: run the build first |
| `Could not add 3D model … ${KICAD…_3DMODEL_DIR}` | footprint model missing: fetch STEP models (e.g. `easyeda2kicad --3d`) or keep the placeholder |
| board at the origin in the screenshot | moved a child, not the top-level import |
| everything grey | colours were set headless (`App.GuiUp` False) or not at all |
