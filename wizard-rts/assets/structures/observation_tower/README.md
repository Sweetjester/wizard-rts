# Kon's Observation Tower: Painted 3D Skin

The live tower now uses the [HD V3 remaster](../observation_tower_hd/README.md).
The images and notes below document the previous painted V2 baseline and are
retained for comparison. They are not screenshots of the current remaster.

The live BlockStructureBuilder applies ObservationTowerSkin to
kons_observation_wizard_tower_01. This is real, orbitable 3D surface dressing,
not a billboard or an AI paintover displayed in front of the building.

## Quality approach

- Generated illustrated masonry albedo, applied continuously across block faces.
- Real projecting corner stones, window surrounds, timber braces and ironwork.
- Surface-mounted gothic lancets with emissive cyan glass and bounded local lights.
- Smaller burgundy leaves on branching stems instead of a flat red wall decal.
- Roof placeholders replaced visually with a seated ribbed observatory dome.
- Solid balcony-support placeholders replaced visually with timber diagonals.
- Hanging lantern arm and chain rebuilt as narrow structural members.

The screenshot files tower_front.png, tower_back.png and tower_crown.png are
captured directly from Godot's Forward+ renderer. Forward+ glow contributes to
the light bleed; another renderer or different environment lighting can look
different. Surface detail and silhouettes remain actual assets in every view.

## Gameplay boundary

YAML, solid cells, authored navigation, link widths, gate states and collision
remain unchanged. Only selected render instances are replaced. Existing collision
in the former balcony support and roof volumes therefore remains conservative.
The added dome and finial fit below y=35, inside the YAML's inclusive reserved
airspace through y=34. The rectangular observatory floor is retained.

This skin targets the standalone observation-tower ID. The flattened citadel has
its own existing skin; its differently placed tower is not silently replaced.

## Review

From the Godot project directory:

```powershell
godot --path . res://scenes/blocks/block_tower_demo.tscn
godot --path . --script tools/blocks/shot_observation_tower.gd
godot --headless --path . --script tools/blocks/verify_art_skin.gd
godot --headless --path . --script scripts/core/block_structure_smoke_test.gd
```

The interactive demo supports orbit/zoom, gate switching and navigation overlays.
The capture script uses that same builder and hides the debug overlays.

## Provenance and limits

Masonry was generated using the built-in image generator with the user's supplied
castle reference. The prompt is recorded in art_prompt.txt. Existing shared glass,
iron, wood and leaf shaders supply the other materials.

This materially improves the in-engine result but does not reproduce every mark
of the concept illustration. Bespoke sculpted shaft geometry, richer painted
wood/roof atlases and further irregular silhouette work remain art-production
opportunities. The present implementation deliberately retains the block layout.
