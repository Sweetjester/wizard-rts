# Blender Export Guide

## Purpose

This guide defines Blender authoring and export rules for assets used by the wizard RTS project. It covers procedural terrain pieces, props, buildings, billboard sources, and biome variants.

## Units And Scale

Blender scene setup:

- Unit system: Metric
- Unit scale: 1.0
- 1 Blender unit = 1 Godot 3D unit
- 1 gameplay tile = 1.0 x 1.0 Godot units
- Apply scale before export
- Keep transforms clean unless intentionally animated

Recommended workflow:

1. Model against a 1 x 1 tile reference plane.
2. Check footprint from top view.
3. Check silhouette from oblique RTS camera.
4. Apply transforms.
5. Export to the correct asset folder.
6. Verify in Godot with a preview scene or import test.

## Export Formats

Preferred formats:

- `.glb` for static or animated 3D assets
- `.png` for billboard sprite renders
- `.blend` retained as source file only

Use `.glb` for:

- Buildings
- Props
- Terrain chunks
- Landmark meshes
- Animated 3D source assets

Use `.png` for:

- Billboard units
- Billboard blocker variants
- Sprite sheets
- Rendered prop cards

Avoid `.fbx` unless a specific tool requires it.

## Pivots

Default pivot rules:

- Units: bottom center of gameplay footprint
- Buildings: center of footprint at ground level
- Props/blockers: center of occupied tile at ground level
- Trees: trunk/base center at ground level
- Rocks: center of occupied tile at ground level
- Terrain tile: tile center at top surface reference
- Ramps: center of ramp footprint, ground-aligned

Pivot exceptions must be documented in the asset spec.

## Naming Conventions

Use lowercase snake_case.

Pattern:

```text
[category]_[biome]_[asset_name]_[variant]
```

Examples:

```text
prop_forest_oak_blocker_a.glb
prop_swamp_mushroom_blocker_b.glb
building_arcane_wizard_tower_a.glb
unit_fire_imp_idle_sheet.png
terrain_forest_ramp_straight_a.glb
```

Recommended categories:

- `unit`
- `building`
- `prop`
- `terrain`
- `resource`
- `effect`
- `ui`

## Mesh Rules

Static mesh rules:

- Use simple readable forms.
- Remove hidden internal faces where practical.
- Keep origin/pivot correct.
- Apply rotation and scale.
- Use flat or simple stylised normals.
- Avoid excessive bevels.
- Avoid dense triangulation unless needed.

Collision:

- Gameplay collision comes from the logical grid by default.
- Do not author gameplay collision unless a specific system requests it.
- Visual collision may be omitted for prototype assets.

## Materials

Material rules:

- Use simple PBR-compatible materials.
- Prefer few material slots per asset.
- Use broad colour regions.
- Avoid photoreal texture maps.
- Emissive accents are allowed for magic and resources.
- Keep roughness high for miniature/painted feel.

Texture guidance:

- Use power-of-two texture sizes where possible.
- Props: 256-1024 px depending importance.
- Buildings: 512-2048 px depending size.
- Billboard units: source render may be larger, final import size determined by readability.

## Billboard Rendering Rules

Billboard source setup:

- Render with orthographic camera.
- Use transparent background.
- Use consistent oblique angle matching the game camera.
- Keep ground contact point consistent across frames.
- Do not bake large shadows into transparent sprites.
- Leave enough transparent padding for animation, but avoid excessive empty canvas.

Recommended billboard angles:

- Primary: front three-quarter oblique
- Optional: 8-direction set for advanced units
- Camera height angle should match RTS readability, not side-view character art.

Sprite sheet rules:

- Equal cell size for every frame.
- Consistent pivot point.
- Naming includes unit, animation, direction if applicable.
- Export metadata should document frame size and pivot.

## Godot Import Workflow

For `.glb`:

1. Place source export under the approved asset folder.
2. Let Godot import the asset.
3. Check scale in a preview scene.
4. Confirm pivot by placing at a known grid cell.
5. Assign or verify materials.
6. Save any inherited scene if local setup is needed.
7. Register in the asset registry or asset pack config when applicable.

For `.png` billboard assets:

1. Import as texture.
2. Disable unwanted filtering if pixel clarity is required.
3. Keep transparency enabled.
4. Create Sprite3D or billboard material setup.
5. Validate at default RTS camera.
6. Register animation frames or sprite sheet metadata.

## Folder Guidance

Suggested structure:

```text
assets_game/source/blender/
assets_game/source/renders/
assets_game/props/
assets_game/buildings/
assets_game/units/
assets_game/terrain/
resources/asset_packs/
```

Keep source files separate from runtime imports where practical.

## Export Checklist

Before export:

- Scale matches `ASSET_SCALE_GUIDE.md`.
- Pivot is correct.
- Transforms are applied.
- Mesh reads from RTS camera.
- Materials are assigned.
- File name follows convention.
- Asset spec exists.

After Godot import:

- Scale verified.
- Pivot verified.
- Visual footprint verified.
- Default camera screenshot reviewed.
- Asset registered if used procedurally.
- Biome variant tagged.
- No unintended collision or gameplay changes.
