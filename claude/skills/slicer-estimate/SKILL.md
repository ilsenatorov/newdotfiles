---
name: slicer-estimate
description: Slice STL files with Bambu Studio for a Bambu Lab A1 with a 0.4 mm nozzle and report print time, filament weight, cost and layer count, with toolpath images that show whether fine features survive slicing. Use this whenever someone asks how long a part takes to print, how much filament it uses, whether it will slice properly, or wants to compare PETG and PLA or different settings, even if they don't mention a slicer. For a full spec-to-print workflow, use print-part, which calls this.
---

# Slicer estimate

Uses Bambu Studio's command line with its own A1 profiles. Run it with the build123d environment, which has `matplotlib`:

```bash
~/.venvs/build123d/bin/python ~/.claude/skills/slicer-estimate/scripts/slice.py \
  --out out/slice --material petg --walls 4 --infill 40 --layers 0.2,3.0 out/a.stl out/b.stl
```

| Option | Default | Use |
|---|---|---|
| `--material` | `petg` | `petg`, `pla`, or an exact Bambu filament profile name |
| `--layer-height` | `0.2` | Must match a Bambu A1 profile; an error lists the heights available |
| `--walls` | `3` | Wall count |
| `--infill` | `15` | Infill percent |
| `--brim` | automatic | Brim width in mm; `0` turns it off |
| `--supports` | off | Generate supports |
| `--plate` | `Textured PEI Plate` | Build plate. Bambu rejects PETG on the Cool Plate. |
| `--layers` | none | Z heights to draw as toolpath images |
| `--keep-gcode` | off | Keep each part's G-code for inspection |

It reports each part alone and, with more than one model, the full plate. Results go to `estimates.json`. `plate.3mf` holds the sliced plate, for opening in Bambu Studio.

If the script says the Bambu Studio folder isn't readable, tell the user to run `sudo chmod -R a+rX /opt/bambustudio-bin`, or run it if they've approved it. The AUR package installs its files as root-only, so this comes back after each update.

## Read the numbers correctly

- **Print time** is the model only. **Total time** adds the A1's start routine, so give that for how long the job takes. Comparing parts is clearer with print time.
- **Cost** uses the price in Bambu's profile, with no currency stated. Scale it to what the filament costs.
- These are Bambu Studio's predictions, not measurements. The real time can differ.

## Use the toolpath images

Choose `--layers` to cross the features most at risk: the first layer and any height with slits, thin walls, or flexing arms. Open the images with the Read tool. Lines are drawn at true extrusion width, so a gap in the image is a real gap. Check that:

- Narrow gaps stay open, especially on the first layer, where plastic spreads.
- Load-bearing or flexing features are solid walls, not sparse infill.
- Thin walls have toolpaths at all. A wall too thin to print disappears from the image.

The script prints any heights with Bridge toolpaths. Bambu also uses this label for the first solid layer over sparse infill, inside the part, which is normal. To tell it apart from a real unsupported span, look at that layer and compare the height with the design.

## Printing

Tell the user to open `plate.3mf` or the STLs in Bambu Studio, review the plate and print from there. This workflow hasn't been checked on a real printer, so don't send a job to the printer from the command line.

## Profile handling

The command line ignores profile inheritance and falls back to defaults without an error, which gives a successful slice with the wrong material and speeds. `slice.py` merges each profile with its parents and fails if the sliced filament doesn't match. Keep both protections if you change it.

A different Bambu printer needs the `MACHINE` constant and the process profile name changed.
