---
name: freecad-render
description: Render STEP or STL parts to PNG images with FreeCAD's viewer on a machine with no display, including assembled views and cross-sections. Use this whenever someone wants to see a 3D model, get images or screenshots from FreeCAD, check how parts fit together, or look inside a part with a section view, even if they only say "show me the part" or "what does it look like". For a full spec-to-print workflow, use print-part, which calls this.
---

# FreeCAD render

Renders 3D parts with FreeCAD under a virtual display. Needs `freecad` and `xorg-server-xvfb`; the script names the install command if either is missing. It uses the system Python and no extra packages.

```bash
python3 ~/.claude/skills/freecad-render/scripts/render.py --out out/freecad --part out/part.step
```

| Option | Use |
|---|---|
| `--part PATH[@X,Y,Z][#RRGGBB]` | Add a part, optionally moved and coloured. Repeat it for assemblies. |
| `--views iso,top,front,right,bottom` | Choose views. The default is iso, top, front and right. |
| `--section x=12` | Add a cut view at that plane on x, y or z. This needs STEP input. |
| `--name assembly` | Set the file prefix. The default is the first part's name. |
| `--size 1400x1000` | Set the image size. |

Prefer STEP: it draws clean edges, while STL shows every mesh triangle.

An assembly example, with the second part moved into its fitted position:

```bash
python3 ~/.claude/skills/freecad-render/scripts/render.py --out out/freecad --name assembled \
  --part out/housing.step --part "out/tongue.step@-15.3,0,1.75#e8590c" --section x=12
```

## Look at every image

Open each PNG with the Read tool before describing it. The script rejects blank images and reports failures, but it can't tell whether the model is right. These are worth checking:

- **Scale:** compare the part's size in the image with its known dimensions. A section is the best place to catch parts in the wrong position, because they look plausible in other views.
- **Fit:** in sections, clearances should look even and nothing should overlap.
- **Features:** holes, slits and chamfers should appear where the design puts them.

## Sharing images

Say what each image shows. `SendUserFile` can fail outside a project thread. If it does, put the images in an Artifact page, as print-part does, and give the local paths too.
