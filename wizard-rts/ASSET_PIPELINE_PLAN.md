# Asset Pack Ingestion Pipeline

## Goal

External packs should be imported, classified, and consumed by renderers through stable visual tags instead of scattered atlas coordinates in gameplay or map generation scripts. This plan adds the framework only. It does not change gameplay, map generation behaviour, or the current 2D renderer.

## Folder Structure

```text
assets_external/
  <pack_id>/
    raw/
    source_notes.md

assets_game/
  <pack_id>/
    tiles/
    props/
    units/
    buildings/
    portraits/

resources/asset_packs/
  <pack_id>_asset_pack.json

resources/tilesets/
  <pack_id>_runtime_tileset.tres
```

- `assets_external/`: raw purchased/downloaded packs, kept close to original for audit and re-import.
- `assets_game/`: normalized game-ready assets after slicing, naming, filtering, and import settings.
- `resources/asset_packs/`: metadata resources that explain how this game should use a pack.
- `resources/tilesets/`: Godot `TileSet` resources used at runtime.

## AssetPackConfig

`AssetPackConfig` is a Resource describing one pack and its runtime contract. Pack metadata can be stored as `.tres` later, but the initial sample uses `.json` because external pack ingestion and review is easier when metadata can be generated and diffed as plain text.

Fields:

- `pack_id`: stable id, e.g. `tiny_swords`.
- `display_name`: human-readable name.
- `tile_size`: expected grid tile dimensions.
- `pixel_art`: whether textures should use nearest filtering and pixel snapping.
- `runtime_tileset_path`: the TileSet path renderers should load.
- `supported_visual_tags`: list of tags this pack claims to support.
- `terrain_mappings`: visual tag to terrain set/id or atlas fallback.
- `prop_mappings`: visual tag to prop scene/source/atlas/texture choices.
- `unit_mappings`: reserved for unit sprites/scenes.
- `building_mappings`: reserved for building sprites/scenes.

The config deliberately supports both terrain IDs and direct atlas/source mappings because not every visual in a pack belongs in Godot terrain connect. Terrain such as grass/road should use terrain sets; props, debug markers, and one-off blockers may use direct atlas placement or scenes.

## Visual Tags

These tags are the renderer-facing vocabulary. Map logic should eventually emit logical cell types, and renderers should ask the registry how to draw them.

Core terrain tags:

- `LOW_GROUND`
- `HIGH_GROUND`
- `ROAD`
- `RAMP`
- `WATER`
- `CLIFF_EDGE`

Blocker/prop tags:

- `FOREST_BLOCKER`
- `ROCK_BLOCKER`

Debug/marker tags:

- `BASE_PLOT_MARKER`
- `CONTENT_PLOT_MARKER`

Future tags should be additive. Existing tags should remain stable so map generation does not need to know which art pack is active.

## AssetRegistry

`AssetRegistry` is a lightweight resolver that:

- loads the active `AssetPackConfig`;
- loads the pack runtime TileSet;
- resolves visual tags to terrain mappings, atlas coordinates, scenes, or textures;
- warns when a required tag is missing;
- gives map/rendering code a single query point for asset decisions.

Current minimal API:

```gdscript
load_asset_pack(config_path: String) -> bool
get_active_pack() -> AssetPackConfig
get_runtime_tileset() -> TileSet
has_visual_tag(tag: StringName) -> bool
resolve_visual_tag(tag: StringName) -> Dictionary
resolve_terrain(tag: StringName) -> Dictionary
require_visual_tags(tags: Array[StringName]) -> Array[StringName]
```

## Renderer Integration Plan

No integration is implemented yet. The intended migration is:

1. Keep map generation producing logical data only:
   - elevation grid
   - feature grid
   - road cells
   - plot metadata
   - blocker/content tags
2. Add an `AssetRegistry` dependency to the map renderer, not the map generator.
3. Replace hardcoded constants such as terrain set ids, water source ids, and atlas coordinates with registry queries:
   - `LOW_GROUND`/`HIGH_GROUND` -> grass terrain set/id.
   - `ROAD` -> road terrain set/id.
   - `WATER` -> water terrain set/id or atlas fallback until water terrain is configured.
   - `FOREST_BLOCKER` -> prop source/atlas or scene.
   - `BASE_PLOT_MARKER`/`CONTENT_PLOT_MARKER` -> debug material/atlas/scene.
4. Keep `set_cells_terrain_connect()` for connected terrain returned by terrain mappings.
5. Keep `set_cell()` only for registry-approved atlas/prop/debug mappings.
6. Add validation before painting:
   - registry has all required tags for active map mode;
   - runtime TileSet path matches active pack;
   - terrain mappings refer to terrain sets that exist.

This lets us swap Tiny Swords, custom generated art, or future high-resolution packs without rewriting map generation.

## Risks

- Some packs do not contain true terrain/autotile equivalents for every tag, especially water, cliffs, ramps, and roads.
- Godot `TileSet` terrain peering data still has to be configured carefully in editor/resource files; metadata cannot make a bad terrain set connect correctly.
- A single tag may need different visuals by elevation or biome later. The mapping schema should support variants rather than forcing new logic into `map_generator.gd`.
- Units/buildings have different requirements from terrain. Their mappings should eventually point to scenes/sprite sheets and animation descriptors, not tile atlas cells.

## Next Steps

1. Create or refine `AssetPackConfig` for Tiny Swords.
2. Add an editor/import helper that scans an external pack folder and produces a draft config with missing tags marked.
3. Move current terrain constants from `map_generator.gd` into renderer-facing code that uses `AssetRegistry`.
4. Configure water, cliff, ramp, and shore terrain sets in the runtime TileSet where the pack supports them.
5. Add smoke tests that load each pack config and verify required visual tags resolve.
