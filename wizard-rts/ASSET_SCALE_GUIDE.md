# Asset Scale Guide

## Core Scale

The visual prototype treats one generated logical grid cell as one 3D terrain tile.

Reference scale:

- 1 gameplay tile = 1.0 Godot 3D unit
- Low ground surface = y 0.0
- High ground surface = y 1.0
- Water surface = about y -0.2
- Terrain tile top size = about 1.0 x 1.0

All production assets should be authored against this scale unless a specific scene defines otherwise.

## Gameplay Tile Scale

Tile usage:

- Standard walkable cell: 1 x 1 tile
- Road cell: 1 x 1 tile, visually inset inside the terrain tile
- Ramp cell: 1 x 1 tile sloped between low and high
- Blocker cell: 1 x 1 tile occupied visually and logically
- Plot areas: rectangular groups of gameplay tiles

Asset boundaries should stay readable inside the tile grid. Decorative overhangs are allowed only when they do not confuse gameplay footprint.

## Unit Footprints

Units are expected to be billboard sprites or simple 3D placeholders.

Suggested scale:

| Unit Type | Gameplay Footprint | Visual Width | Visual Height |
| --- | ---: | ---: | ---: |
| Tiny minion | 1 tile | 0.45-0.60 | 0.75-1.00 |
| Standard unit | 1 tile | 0.60-0.80 | 1.00-1.35 |
| Large unit | 1-2 tiles | 0.90-1.30 | 1.40-2.00 |
| Hero/wizard | 1 tile | 0.75-0.95 | 1.35-1.80 |
| Boss/elite | 2+ tiles | 1.50-2.50 | 2.20-3.50 |

Readability rules:

- A selected standard unit should be visible at default RTS zoom.
- Billboard art should include transparent padding but not excessive empty bounds.
- Unit visual width may be smaller than footprint, but selection/movement footprint must remain clear.

## Building Footprints

Buildings must match gameplay footprint exactly.

Suggested categories:

| Building Type | Footprint | Visual Height | Notes |
| --- | ---: | ---: | --- |
| Small utility | 2 x 2 | 1.5-2.5 | Clear roof or top silhouette |
| Production | 3 x 3 | 2.0-3.5 | Strong role silhouette |
| Economy | 3 x 3 or 4 x 4 | 1.8-3.0 | Resource-facing details |
| Defensive tower | 1 x 1 or 2 x 2 | 2.5-4.5 | Tall but not visually thin |
| Landmark | 4 x 4+ | 3.0-6.0 | Used sparingly |

Rules:

- Keep the base footprint rectangular and easy to select.
- Avoid overhangs covering roads or ramps.
- Tall buildings should not hide nearby unit silhouettes.
- Selection rings should remain visible at the building base.

## Tree, Rock, And Blocker Sizes

Blockers must communicate blocked movement.

| Blocker Type | Footprint | Width | Height |
| --- | ---: | ---: | ---: |
| Small rock | 1 x 1 | 0.65-0.95 | 0.35-0.90 |
| Tall rock | 1 x 1 | 0.70-1.00 | 1.00-1.80 |
| Tree | 1 x 1 | 0.80-1.20 | 1.80-3.20 |
| Dense tree cluster | 2 x 2 | 1.80-2.40 | 2.20-3.60 |
| Ruin blocker | 1 x 1 or 2 x 2 | footprint width | 0.80-2.50 |
| Mushroom blocker | 1 x 1 | 0.80-1.20 | 1.40-2.60 |

Rules:

- Blocker base must sit clearly inside occupied tiles.
- Decorative props should be lower and smaller than blockers.
- Clusters should use several chunky forms instead of fine detail.

## Ramp And Cliff Dimensions

Terrain elevation:

- Low = y 0.0
- High = y 1.0
- Ramp connects low to high over its ramp cells

Ramp rules:

- Ramp width should match gameplay entrance width.
- Ramp should extend visually into the plateau with a top landing.
- Bottom landing should be flat and readable.
- Roads should sit on ramp surfaces without floating.
- Ramp direction should point toward plateau interior.

Cliff rules:

- Cliff side height should read as one full elevation step.
- Cliff sides should use darker value than top surfaces.
- Cliff edges near ramps may be softened or recessed.
- Plateau silhouette should stay readable after smoothing.

## Camera Readability Constraints

Default camera assumptions:

- RTS oblique camera
- High map coverage
- Units and props viewed from above
- Terrain readability more important than close-up beauty

Assets must pass:

- 100 percent zoom: category readable
- Default gameplay zoom: footprint readable
- Far tactical zoom: road/ramp/base/content structure readable

Minimum visual guidance:

- Important unit feature width: at least 10 percent of unit height
- Important building feature width: at least 0.25 tile
- Road visible width: at least 0.65 tile
- Ramp visible width: matches gameplay width
- Selection marker visibility: never hidden by asset base

## Scale Approval Checklist

- Asset imported at correct Godot scale.
- Pivot sits at gameplay footprint center or documented alternative.
- Height does not hide critical neighboring gameplay cells.
- Footprint matches asset spec.
- Camera screenshot confirms readability.
- Blockers read as blockers.
- Decorative props do not read as blockers.
