# build123d notes

Patterns that worked with build123d 0.13 in algebra mode (`a + b`, `a - b`, `a & b`).

## Project shape

```python
from dataclasses import dataclass
from pathlib import Path
from build123d import Part, Plane, Polygon, export_step, export_stl, extrude

@dataclass(frozen=True)
class Params:
    fit: float = 0.15  # clearances first, since they get tuned after a test print
    width: float = 20.0

    @property
    def inner(self) -> float:  # derive dimensions, so a change can't leave them inconsistent
        return self.width - 2 * self.fit

def prism(pts, z0: float, z1: float) -> Part:
    """Extrude an XY outline between two heights."""
    return extrude(Plane.XY.offset(z0) * Polygon(*pts, align=None), z1 - z0)

def build(p: Params = Params(), out: Path = Path(__file__).parent / "out") -> dict[str, Part]:
    out.mkdir(exist_ok=True)
    parts = {"bracket": make_bracket(p)}
    for name, part in parts.items():
        export_stl(part, str(out / f"{name}.stl"), tolerance=0.01, angular_tolerance=0.1)
        export_step(part, str(out / f"{name}.step"))
    return parts
```

Model each part with its bed face at Z=0, in print orientation, and use a helper to move parts into place for fit checks.

## Traps

- **`Polygon` centres itself by default.** Pass `align=None` to keep your coordinates.
- **`Plane.XZ` has a normal pointing towards -Y.** Local (x, y) maps to world (x, z), and `extrude` runs towards -Y. To span from -w to +w in Y, use `Plane.XZ.offset(-w)`.
- **Add 0.01 mm of overlap between joined solids.** Faces that only touch can produce invalid or separate solids.
- **Check `part.is_valid` and `len(part.solids()) == 1`.** A piece that isn't really joined still exports without complaint.
- **Cutters should overshoot.** Run them 1 mm past the faces they cut, to avoid zero-thickness skins.

## Useful shapes

A ruled solid between two outlines with the same vertex order. This gives a chamfer on selected edges only, where `chamfer()` is unreliable on awkward geometry:

```python
from build123d import loft

def tapered(bottom, top, z0, z1):
    return loft([Plane.XY.offset(z0) * Polygon(*bottom, align=None),
                 Plane.XY.offset(z1) * Polygon(*top, align=None)], ruled=True)
```

A bar or rail with a custom cross-section, extruded along Y:

```python
bar = extrude(Plane.XZ.offset(-w) * Polygon(*section_xz, align=None), 2 * w)
```

A rounded inside corner, made by adding a small block and cutting a cylinder from it:

```python
fill = box(x0, x0 + r, y0, y0 + r, 0, h)
fill -= extrude(Plane.XY.offset(-1) * Pos(x0 + r, y0 + r) * Circle(r), h + 2)
```

## Testing function with booleans

```python
overlap = (a & b).volume          # fit: expect about 0
hit = (Pos(-0.5, 0, 0) * a & b).volume   # latch: expect > 0 when pulled
```

To test a release, move only the flexing feature by its travel and slide it along its exit path, checking for overlap at several positions.
