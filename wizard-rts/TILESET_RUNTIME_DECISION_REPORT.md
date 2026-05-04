# TileSet Runtime Decision Report

## Scope

This report is documentation only. It does not change map generation logic, gameplay systems, roads, plots, pathfinding, waves, units, buildings, or TileSet resources.

## 1. Runtime TileSet Actually Used By The Map

The active runtime map scene is `res://scripts/map/main_map.tscn`.

That scene assigns this TileSet:

`res://assets/tiles/voxel/voxel_tileset.tres`

It is assigned to the three runtime terrain TileMapLayer nodes:

- `TileMapLow`
- `TileMapMid`
- `TileMapHigh`

This means the current runtime terrain rendering is driven by `voxel_tileset.tres`, not by the Tiny Swords plot TileSet.

Important finding: `voxel_tileset.tres` has zero terrain sets. Because of that, Godot terrain autotiling cannot work on the current runtime map layers.

## 2. Recommended Single Source Of Truth

The single source of truth for runtime terrain rendering should become:

`res://resources/tilesets/tiny_swords_plot_tileset.tres`

Reasoning:

- It is based on the target Tiny Swords art pack.
- It already has terrain-set setup started.
- It matches the direction for future terrain rendering: grass islands, cliffs, water, shorelines, roads, and buildable ground.
- The current voxel TileSet is useful as a prototype/debug source, but it has no terrain sets and does not support Godot terrain autotiling.

However, `tiny_swords_plot_tileset.tres` is not ready to become the runtime TileSet yet. It currently has terrain sets for grass and cliff only. It needs more terrain sets before it can render the current map generation correctly.

## 3. Scenes And Scripts That Assign Runtime TileSets

### `res://scripts/map/main_map.tscn`

This is the main runtime scene assigning the active terrain TileSet.

It declares:

`res://assets/tiles/voxel/voxel_tileset.tres`

And assigns it to:

- `TileMapLow`
- `TileMapMid`
- `TileMapHigh`

### `res://scripts/map/map_generator.gd`

This script does not assign a TileSet directly. It reads the existing TileSet from `TileMapLow` in `_load_tiles()` and then paints runtime map cells.

Current behavior:

- Reads `layer_low.tile_set`.
- Builds a terrain-name lookup from texture filenames.
- Paints terrain using `set_cell()`.

This means `map_generator.gd` depends on whatever TileSet the scene has already assigned.

### `res://scripts/map/plots/PlotGenerator.gd`

This script creates its own plot-local TileSet at runtime with `_build_tileset()`.

It creates logical layers:

- `Water`
- `WaterFoam`
- `GrassLandmass`
- `CliffFaces`
- `CliffTops`
- `Overhang`
- `Decoration`

It is separate from the main runtime map layers. It does use `set_cells_terrain_connect()` for grass, but it still uses direct `set_cell()` for water, foam, cliff faces, cliff tops, overhangs, ramps, and decorations.

### `res://scripts/map/editor/map_editor.gd`

This script also builds an editor TileSet dynamically for the map editor. It is tooling, not the live runtime terrain source.

## 4. Map Layers Using `voxel_tileset.tres`

The following runtime map layers use `res://assets/tiles/voxel/voxel_tileset.tres`:

- `res://scripts/map/main_map.tscn` - `TileMapLow`
- `res://scripts/map/main_map.tscn` - `TileMapMid`
- `res://scripts/map/main_map.tscn` - `TileMapHigh`

Other visual nodes in `main_map.tscn` are overlays or systems, not TileMapLayer terrain sources:

- `TerrainReliefLayer`
- `WaterLightingEffects`
- `SunlightShadows`
- `DayNightCycle`
- `LightingLayer`
- `FogOfWar`
- `GridOverlay`

These do not own the terrain TileSet.

## 5. Map Layers Using `tiny_swords_plot_tileset.tres`

No main runtime map layer currently uses:

`res://resources/tilesets/tiny_swords_plot_tileset.tres`

The Tiny Swords plot TileSet exists as a resource, and the plot generator has matching Tiny Swords logic, but the main runtime scene does not assign that resource to `TileMapLow`, `TileMapMid`, or `TileMapHigh`.

The current Tiny Swords usage is isolated to plot/editor tooling:

- `res://scripts/map/plots/PlotGenerator.gd` - builds a plot-local Tiny Swords TileSet dynamically.
- `res://scripts/map/editor/map_editor.gd` - builds a tooling TileSet dynamically.
- `res://resources/tilesets/tiny_swords_plot_tileset.tres` - saved resource with partial terrain setup.

## 6. Terrain Types Required By Current Map Generation

The current map generator needs the runtime TileSet to support these terrain categories.

### Grass / Ground

Required for:

- `E_LOW`
- `E_MID`
- `E_HIGH`
- `frontier_canvas`
- `test_canvas`
- `ai_arena`
- `siege_lane`
- `plot_grass`

Current terrain names include:

- `low_ground`
- `mid_ground`
- `high_ground`

### Water

Required for:

- `E_WATER`
- lakes
- plot test water
- island/shore maps

Current terrain names include:

- `water`

### Road / Path

Required for:

- generated roads
- guaranteed traversal paths
- road branches to content plots

Current feature names include:

- `path`

Current terrain names include:

- `path`

### Ramp

Required for:

- high-ground base access
- elevation transition cells
- plot ramps

Current grid/feature names include:

- `E_RAMP`
- `ramp`
- `plot_ramp`

Current terrain names include:

- `path_slope`

### Cliff / Elevation Edge

Required for:

- visible low/mid/high terrain separation
- impassible elevation borders
- high-ground bases
- island cliffs
- plateau edges

Current runtime elevation logic exists in the grid and height map, but the active voxel TileSet cannot autotile cliff edges because it has no terrain sets.

### Coast / Shore

Required for:

- grass next to water
- lake edges
- island coastlines
- water foam/shore treatment

Current plot tooling has foam and water-edge logic, but the main runtime TileSet has no shoreline terrain set.

### Base Floor / Buildable Ground

Required for:

- `base_floor`
- `economy_space`
- `content_plot_blank`
- buildable content plots
- high-ground base plots

Current terrain/feature names include:

- `base_floor`
- `economy_plot`
- `content_plot_blank`
- `tower_floor`
- `bandit_floor`

### Blockers / Forest / Mountain

Required for:

- `E_BLOCKED`
- map borders
- forests
- mountains
- impassible terrain
- arena walls
- plot walls

Current terrain/feature names include:

- `map_border`
- `forest_blocker`
- `mountain`
- `ai_wall`
- `tower_wall`
- `bandit_wall`
- `giant_mushroom`
- `foliage`

Some blockers can remain direct object placement later, but map-scale blockers need a consistent terrain or object-stamp policy.

## 7. Missing Terrain Sets In The Chosen Runtime TileSet

Chosen future runtime TileSet:

`res://resources/tilesets/tiny_swords_plot_tileset.tres`

Currently present:

- Terrain set `0`, terrain `0`: `grass`
- Terrain set `1`, terrain `0`: `cliff`

Missing for current runtime map rendering:

- `water`
- `coast` / `shore`
- `road` / `path`
- `ramp`
- `base_floor` / `buildable_ground`
- `blocked_forest`
- `blocked_mountain`
- optional `low_ground`, `mid_ground`, `high_ground` variants if elevation is represented by terrain instead of separate layers

Most important missing item: water. Without water in a compatible terrain set, grass-to-water coastline autotiling cannot be solved cleanly.

## 8. Minimum Terrain Sets Needed

To make the runtime map render correctly with Godot terrain autotiling, the minimum recommended TileSet structure is:

### Terrain Set 0: `surface`

Use for normal connected floor terrain.

Minimum terrain IDs:

- `grass`
- `water`
- `road`
- `base_floor`

Recommended additions:

- `shore` if the pack uses explicit shore/foam tiles that cannot be represented by grass-water peering alone
- `mud` or `variant_grass` for future biome variation

This set should be configured so grass and water can resolve coastline transitions through terrain peering bits.

### Terrain Set 1: `elevation`

Use for cliff and height-transition terrain.

Minimum terrain IDs:

- `cliff`
- `ramp`

Recommended additions:

- `cliff_top`
- `cliff_face`
- `cliff_bottom`
- `waterfall` if water can run over cliff edges

### Terrain Set 2: `blockers`

Use only if blockers are terrain-driven.

Minimum terrain IDs:

- `forest_blocker`
- `mountain_blocker`

Alternative: keep blockers as direct object/prop placement with collision metadata. This is acceptable if blockers are not expected to blend like terrain.

## 9. Recommended Decision

Do not create a new TileSet at runtime for the main map.

Instead:

1. Complete `res://resources/tilesets/tiny_swords_plot_tileset.tres` in the editor/import pipeline.
2. Add the missing terrain sets and terrain IDs listed above.
3. Verify grass and water with a minimal `set_cells_terrain_connect()` island test.
4. Only after the terrain sets work, switch `TileMapLow`, `TileMapMid`, and `TileMapHigh` in `res://scripts/map/main_map.tscn` from `voxel_tileset.tres` to the completed Tiny Swords TileSet.
5. Refactor terrain painting in `map_generator.gd` to batch cells by terrain type and call `set_cells_terrain_connect()`.
6. Keep `set_cell()` only for props, decorations, debug visuals, and non-terrain objects.

## 10. `set_cell()` Usage To Retire Later

These are the important terrain-related direct paint sites that should be replaced later, after the runtime TileSet has the required terrain sets:

- `res://scripts/map/map_generator.gd` - `_paint()`
- `res://scripts/map/map_generator.gd` - `_paint_square_grid_map()`
- `res://scripts/map/map_generator.gd` - `_paint_objects()`
- `res://scripts/map/map_generator.gd` - `_paint_plots()`
- `res://scripts/map/map_generator.gd` - `_set_plot_cell()`

`set_cell()` can remain for:

- props
- decorations
- debug markers
- preview brushes
- non-terrain objects
- editor-only manual painting

## Final Summary

The current runtime map cannot use Godot autotiling because its active TileSet, `voxel_tileset.tres`, has zero terrain sets.

The correct direction is to make `tiny_swords_plot_tileset.tres` the completed runtime terrain source, but only after adding the missing terrain sets for water, shore/coast, road, ramp, base/buildable ground, and blockers.

The next technical milestone should be a minimal Tiny Swords terrain test where grass and water are both painted through `set_cells_terrain_connect()` and the coastline resolves automatically.
