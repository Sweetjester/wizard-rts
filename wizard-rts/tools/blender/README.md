# Blender Pipeline Placeholder Assets

This folder contains a Blender Python generator for the first 3D asset pipeline test.

## Assets

The script creates:

- `cliff_chunk_a.blend`
- `ramp_a.blend`
- `tree_blocker_a.blend`
- `cliff_chunk_a.glb`
- `ramp_a.glb`
- `tree_blocker_a.glb`

These are simple placeholder assets, not final art.

## Run

From the repository root:

```powershell
blender --background --python tools\blender\create_pipeline_placeholders.py
```

If Blender is not on `PATH`, use the full executable path:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --background --python tools\blender\create_pipeline_placeholders.py
```

## Output Locations

Source `.blend` files:

```text
assets_game/source/blender/placeholders/
```

Runtime `.glb` files:

```text
assets_game/terrain/cliffs/cliff_chunk_a.glb
assets_game/terrain/ramps/ramp_a.glb
assets_game/props/trees/tree_blocker_a.glb
```

## Scale And Pivot

The script follows the project scale guides:

- 1 gameplay tile = 1.0 Godot 3D unit
- Terrain/ramp footprint = 1 x 1 tile
- Tree blocker footprint = 1 x 1 tile
- Origin/pivot = center of gameplay footprint at ground level
- Blender Z is authored as height; GLB export uses Y-up conversion for Godot

## Godot Preview

After running the script:

1. Open Godot.
2. Let the editor import the `.glb` files.
3. Create a temporary `Node3D` preview scene.
4. Drag each `.glb` into the scene.
5. Confirm each asset is roughly one terrain tile wide.
6. Confirm pivots sit at the center of the footprint on the ground.
7. View from an oblique RTS camera angle.

## AssetRegistry Notes

The current `AssetRegistry` lists texture props from `assets_game/props/*`. For GLB runtime assets, use one of these approaches:

- Add GLB support to `AssetRegistry._is_supported_texture()` by replacing it with a more general asset extension check.
- Add a new `list_3d_prop_assets(tag)` method that scans for `glb`.
- Add explicit GLB mappings in an asset pack config, for example:

```json
"TREE": {
  "kind": "folder",
  "path": "res://assets_game/props/trees",
  "extensions": ["glb"]
}
```

For terrain pieces, register stable tags such as `CLIFF_EDGE` and `RAMP` with folder or explicit file mappings once the 3D renderer starts consuming external meshes.
