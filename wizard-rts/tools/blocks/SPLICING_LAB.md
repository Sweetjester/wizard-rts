# Kon's Splicing Laboratory

Current game version (September 5): 9x5x7 X/Y/Z, using the explicit runtime
profile in `data/block_structures/runtime/kon_quarter_scale.yaml` and bespoke
unscaled `scripts/blocks/compact_splicing_lab.gd`. See `QUARTER_SCALE.md` for
current integration and tests. The dimensions and art description below
document the preserved full-size design master, not the shipping model.

Structure ID: `kons_splicing_laboratory_01`

Source: `data/block_structures/kons_splicing_laboratory.yaml`
Runtime: existing `resources/block_structures/structures.json` library.
Preview: `scenes/blocks/block_splicing_lab_demo.tscn`.

## Physical building

34 x 28 block footprint, 20 blocks tall. Ground-floor muster hall, central
operating aisle, two specimen islands, rear splicing hall, two stairs and an
upper U-shaped gallery. An open atrium keeps units visible from an RTS camera.
The rear chamber has a glazed canopy. Four translucent specimen vats, suspended
organic forms, splicing arms and a double-helix crest distinguish the laboratory.

The skin reuses the established painted masonry, gothic glass, foliage and iron
materials. Geometry is real 3D and can be viewed from inside or orbited outside.
Vats replace only selected render instances; their authored occupancy remains.

Two independent gates control the muster entrance and east delivery entrance.
Infantry, archers and climbers can reach the gallery. Heavy units can enter the
laboratory and use the delivery route, but cannot climb its stairs. Stairwells
and specimen islands are explicitly reserved, not inferred from visible meshes.

## Production boundary

This is a completed traversable structure asset, not a newly registered trainer.
The current game installs `barracks` as a tower production module. That rule,
unit roster, cost and training logic have not been changed. YAML records a
production-module anchor and muster exit for a future explicit integration.

Maps can request this structure through their existing plot `block_structure`
field. It is not automatically scattered onto existing maps or inserted into the
build menu. The standalone demo exercises real navigation and gate controls.

## Verification

```powershell
godot --path . res://scenes/blocks/block_splicing_lab_demo.tscn
godot --headless --path . --script tools/blocks/verify_splicing_lab.gd
godot --path . --script tools/blocks/shot_splicing_lab.gd
```

Set `ART_SHOT_DIR` to an existing output directory for the three screenshot views.
The YAML converter is `tools/blocks/convert_structures.py` and requires PyYAML.
Validation runs the nine YAML cases, verifies skin/data independence, and checks
both gate visuals. Existing unrelated schema warnings are retained by conversion.
