# Asset Replacement Status

## Active Biome

- **Biome:** `DARK_FOREST_FRONTIER`
- **Asset pack:** `res://resources/asset_packs/dark_forest_frontier_asset_pack.json`
- **Primary renderer:** `res://scripts/map/map_3d_renderer.gd`
- **Preview scene:** `res://scenes/assets/asset_3d_preview.tscn`
- **Showcase scene:** `res://scenes/biomes/dark_forest_frontier_showcase.tscn`

## Replacement System

`AssetRegistry` now supports 3D asset categories through `asset_3d_categories` entries in JSON asset packs.

Supported category fields:

- `material_path`
- `assets`
- `path`
- `folder`
- `extensions`
- `footprint`
- `height_offset`
- `rotation_random`
- `scale_random`
- `biome`

The 3D map renderer asks `AssetRegistry` for registered category visuals first. If a category or asset is missing, it keeps the existing placeholder mesh/material path and records a fallback warning count.

## Supported Categories

### Terrain

- `LOW_GROUND_TILE`
- `HIGH_GROUND_TILE`
- `ROAD_TILE`
- `WATER_TILE`
- `CLIFF_SIDE`
- `CLIFF_CORNER`
- `RAMP_MESH`

### Props And Blockers

- `TREE_BLOCKER`
- `ROCK_BLOCKER`
- `MUSHROOM_BLOCKER`
- `ROOT_BLOCKER`
- `RUIN_PROP`
- `SHRINE_PROP`
- `TORCH_PROP`
- `ROAD_DECOR`
- `WATER_EDGE_DECOR`

### Plot Markers

- `BASE_PLOT_MARKER`
- `CONTENT_PLOT_MARKER`
- `OUTPOST_MARKER`

## Implemented Categories

All supported categories are implemented in `DARK_FOREST_FRONTIER`.

Terrain tile categories currently use registered materials on the existing grid meshes:

- `LOW_GROUND_TILE`
- `HIGH_GROUND_TILE`
- `ROAD_TILE`
- `WATER_TILE`
- `BASE_PLOT_MARKER`
- `CONTENT_PLOT_MARKER`
- `OUTPOST_MARKER`

Mesh replacement categories currently instantiate registered GLB scenes:

- `CLIFF_SIDE`
- `CLIFF_CORNER`
- `RAMP_MESH`
- `TREE_BLOCKER`
- `ROCK_BLOCKER`
- `MUSHROOM_BLOCKER`
- `ROOT_BLOCKER`
- `RUIN_PROP`
- `SHRINE_PROP`
- `TORCH_PROP`
- `ROAD_DECOR`
- `WATER_EDGE_DECOR`

## Generated Placeholder Assets

Generated GLB assets are placed under:

- `res://assets_game/terrain/cliffs/dark_forest_frontier/`
- `res://assets_game/terrain/ramps/dark_forest_frontier/`
- `res://assets_game/props/trees/dark_forest_frontier/`
- `res://assets_game/props/rocks/dark_forest_frontier/`
- `res://assets_game/props/mushrooms/dark_forest_frontier/`
- `res://assets_game/props/roots/dark_forest_frontier/`
- `res://assets_game/props/ruins/dark_forest_frontier/`
- `res://assets_game/props/decor/dark_forest_frontier/`

Source `.blend` files are written under:

- `res://assets_game/source/blender/dark_forest_replacement/`

## Fallback Categories

Fallback rendering remains available for every category. The renderer does not crash if a registered asset is missing.

Current fallback behavior:

- Terrain tiles fall back to colored Godot materials.
- Roads fall back to red/brown overlay tiles.
- Water falls back to a flat blue tile.
- Ramps fall back to the orange debug ramp mesh.
- Cliffs fall back to the existing placeholder cliff side/corner generation.
- Blockers fall back to placeholder cubes/billboards.
- Plot markers fall back to transparent debug materials.
- Decor and shrine props are skipped when no asset is available.

## Debug Output

The 3D map prototype prints:

- active asset pack
- biome name
- loaded category count
- asset count per category
- missing categories
- missing legacy tags
- fallback count
- blocker density
- blocker mesh count
- decor mesh count
- plateau count
- cliff edge cell count

The asset preview scene prints:

- active asset pack
- category count
- preview item count

## Current Limitations

- Ground, high ground, roads, and water use registered materials on procedural grid meshes, not individual GLB tile meshes.
- Cliff side and corner chunks are placed per transition cell and are not yet merged or optimized.
- Ramp replacement uses registered GLB variants, but orientation still follows the prototype ramp placement rules.
- Road and water edge decor are sparse prototype placements, not final authored dressing.
- Asset variants are placeholder quality and intended to validate the production pipeline.

## Next Recommended Assets

- Add two or three more cliff side silhouettes to reduce repetition.
- Add road edge and road junction decor variants.
- Add water reeds, dark stones, and muddy bank pieces for `WATER_EDGE_DECOR`.
- Add separate small ruin fragments for `RUIN_PROP`.
- Add a more distinct shrine landmark for `SHRINE_PROP`.
- Add biome-specific base and content marker meshes once gameplay marker language settles.
