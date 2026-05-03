# Procedural Island Plot Generator Design

This document defines the first production-facing plot generator for asset-native island content. It is intentionally separate from the existing world map generator so we can validate terrain composition, anchors, and asset use without carrying old map assumptions forward.

## Tile Layer Model

| Logical layer | Node | Z index | Placement |
| --- | --- | ---: | --- |
| `water` | `Water` | 0 | Direct fill, one water tile over the full plot bounds. |
| `water_foam` | `WaterFoam` | 1 | Coastline overlay generated from the land/water mask. |
| `grass_landmass` | `GrassLandmass` | 2 | Terrain pass over an organic bool grid. |
| `cliff_faces` | `CliffFaces` | 3 | Cliff face overlay below raised plateau edges. |
| `cliff_tops` | `CliffTops` | 4 | Raised walkable plateau terrain pass. |
| `overhang` | `Overhang` | 5 | Weighted direct placement on cliff lips. |
| `decoration` | `Decoration` | 6 | Weighted direct placement for bushes, rocks, and water rocks. |

Gameplay metadata is held in generated grids: `walkable_grid`, `elevation_grid`, and connection anchors.

## Terrain Plan

The Tiny Swords terrain atlas target is:

`Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png`

It is `576x384`, using `64x64` cells.

The first grass terrain pass uses these atlas cells:

| Atlas coord | Meaning |
| --- | --- |
| `(0, 0)` | grass top-left coast |
| `(1, 0)` | grass top edge |
| `(2, 0)` | grass top-right coast |
| `(0, 1)` | grass left edge |
| `(1, 1)` | grass center |
| `(2, 1)` | grass right edge |
| `(0, 2)` | grass bottom-left coast |
| `(1, 2)` | grass bottom edge |
| `(2, 2)` | grass bottom-right coast |

The intended Godot terrain peering bits are the eight square-tile neighbors:

`TOP_LEFT`, `TOP`, `TOP_RIGHT`, `LEFT`, `RIGHT`, `BOTTOM_LEFT`, `BOTTOM`, `BOTTOM_RIGHT`.

Detailed peering plan for the first grass terrain set:

| Atlas coord | Grass peering bits |
| --- | --- |
| `(0, 0)` | `RIGHT`, `BOTTOM`, `BOTTOM_RIGHT` |
| `(1, 0)` | `LEFT`, `RIGHT`, `BOTTOM_LEFT`, `BOTTOM`, `BOTTOM_RIGHT` |
| `(2, 0)` | `LEFT`, `BOTTOM_LEFT`, `BOTTOM` |
| `(0, 1)` | `TOP`, `TOP_RIGHT`, `RIGHT`, `BOTTOM_RIGHT`, `BOTTOM` |
| `(1, 1)` | all eight bits |
| `(2, 1)` | `TOP`, `TOP_LEFT`, `LEFT`, `BOTTOM_LEFT`, `BOTTOM` |
| `(0, 2)` | `TOP`, `TOP_RIGHT`, `RIGHT` |
| `(1, 2)` | `LEFT`, `RIGHT`, `TOP_LEFT`, `TOP`, `TOP_RIGHT` |
| `(2, 2)` | `TOP`, `TOP_LEFT`, `LEFT` |

The implementation currently generates a `TileSet` at runtime and stores the terrain mapping metadata on it. It also applies a deterministic neighbor-mask refresh after calling `set_cells_terrain_connect`, because the pack does not ship a ready `.tres` with peering bits and this prevents the common "wrong coast tile" failure while the editor TileSet is being tuned.

A saved editor resource is also generated at:

`res://resources/tilesets/tiny_swords_plot_tileset.tres`

To tune this in the Godot editor:

1. Open `resources/tilesets/tiny_swords_plot_tileset.tres`.
2. Select source `1`, which is `Tilemap_color1.png`.
3. Create terrain set `0`, mode `Match Corners and Sides`, terrain `grass`.
4. Assign the peering bits from the table above to atlas cells `(0,0)` through `(2,2)`.
5. Create terrain set `1`, mode `Match Corners and Sides`, terrain `cliff`.
6. Assign the cliff top and face cells listed in the TileSet metadata: `(5,0)`, `(6,0)`, `(6,3)`, `(6,4)`, `(0,3)`, `(1,3)`.
7. Once the editor terrain set is visually correct, the generator's mask fallback can be removed or kept as a safety check.

## Pipeline

1. `clear_layers()`
2. `generate_landmass_shape(seed, size, roughness)`
3. `largest_connected_component()`
4. `ensure_minimum_land()`
5. `place_cliffs(grass_grid)`
6. `build_metadata()`
7. `paint_water_base()`
8. `paint_grass_terrain()`
9. `paint_water_foam()`
10. `paint_cliff_terrain()`
11. `place_overhangs()`
12. `scatter_decoration()`
13. `find_connection_anchors()`

## Configuration

`MapPlotConfig` exposes the seed, plot size, landmass roughness, cliff count/size, decoration densities, and anchor counts. The reference-style default seed is `110142`.

## Forward Compatibility

The plot generator exposes:

- `generate(config, offset)`
- `get_connection_anchors()`
- `get_walkable_cells()`
- `get_local_bounds()`
- `get_elevation_at(cell)`

The future `WorldGenerator` should request local `GeneratedPlot` data, place it at a world offset, then connect anchors with roads.
