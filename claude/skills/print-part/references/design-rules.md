# FDM design rules

Starting values for a 0.4 mm nozzle at 0.2 mm layers. Make each one a parameter, since a test print settles the real value.

## Orientation and strength

- Layers are the weak direction. Printed parts are much weaker when pulled apart across layer lines than along them.
- Point flexing and main loads along the layers, in the XY plane. A snap arm should bend in XY when printed flat, not lift off the bed.
- Parts that are mostly a flat extruded shape are the easiest case: strong, no supports, one flat face on the bed.
- Choose the flattest large face for the bed. It gets the best adhesion.

## Avoiding supports

- Overhangs up to 45 degrees print without support.
- Replace a flat roof with a 45 degree chamfer, or leave the feature open on top.
- Short bridges work, but they sag and leave a rough underside, so avoid them on precise fits.
- A chamfer under a horizontal hole or at the base of a side wall is better than a fillet. Bottom-edge fillets become steep overhangs near the bed.
- Dovetails and 45 degree lips retain a sliding part in Z with no bridging.

## Sizes

| Feature | Starting value |
|---|---|
| Wall that carries load | 1.6 mm or more (4 lines) |
| Thinnest reliable wall | 0.8 mm (2 lines) |
| Sliding fit, per face | 0.15 to 0.2 mm |
| Loose fit, per face | 0.3 to 0.4 mm |
| Press fit, per face | 0 to 0.05 mm, test it first |
| Narrowest open slit | about 1 mm; first-layer spread can close less |
| Screw hole | Screw diameter + 0.3 mm |
| Bed-side edges | 0.3 to 0.8 mm chamfer, to absorb first-layer spread |

Round widths to multiples of the line width where you can, so walls fill with whole lines rather than thin gap fill.

## Flexing parts

For a cantilever arm of length L, width w in the bending direction, and tip travel d:

- Strain = 1.5 x d x w / L squared
- Stress = strain x E
- Tip force = 3 x E x I x d / L cubed, where I = h x w cubed / 12

Typical printed values: PETG has E of about 2000 MPa and yield near 50 MPa. PLA has E of about 3500 MPa and yield near 55 MPa. PLA is stiffer and more brittle, so it reaches yield at much less bending.

For parts that flex repeatedly, keep peak stress below about 70% of yield. PETG is usually the better choice. Longer arms help most, because strain falls with the square of length. Also:

- Round the root of the arm. Cracks start at sharp inside corners.
- Add a hard stop, so a user can't bend the arm past its limit.

## Loads and creep

- Printed plastic creeps under constant load, and PLA also softens at about 55 degrees C. A car in summer can exceed that.
- State the assumed load in `checks.py`. Choose it above the expected load, and say that you chose it.
- Don't call a part safe from calculations alone. Printed strength varies with settings, material and moisture.
