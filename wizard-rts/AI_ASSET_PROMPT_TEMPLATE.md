# AI Asset Prompt Template

Use this document to convert an asset spec into consistent AI image, sprite, texture, or concept prompts.

AI output is not final production art by default. Generated images should be reviewed, cleaned, scaled, and imported through the normal asset pipeline.

## Prompt Inputs

Fill these fields from `ASSET_SPEC_TEMPLATE.md`:

- Asset name:
- Category:
- Biome:
- Gameplay purpose:
- Footprint:
- Height:
- Silhouette:
- Colour palette:
- Material style:
- Camera angle:
- Animation needs:
- Export target:

## General Prompt Formula

```text
Create a stylised fantasy RTS [CATEGORY] asset for a wizard strategy game.

Asset: [ASSET NAME]
Biome: [BIOME]
Gameplay purpose: [GAMEPLAY PURPOSE]
Footprint: [FOOTPRINT] gameplay tiles
Relative height: [HEIGHT]

Visual direction:
- Chunky low-poly / voxel-adjacent fantasy shape language
- Readable from an oblique RTS camera
- Clear silhouette: [SILHOUETTE]
- Colour palette: [COLOUR PALETTE]
- Material style: [MATERIAL STYLE]
- Broad forms, simple readable details, no photorealism

Constraints:
- Must preserve gameplay readability
- Must not include tiny noisy detail
- Must not obscure selection or footprint
- Must fit the [BIOME] biome style
- Must be suitable for Godot asset production

Output:
- [OUTPUT TYPE]
- Clean background or transparent background where supported
- Centered asset
- No text, watermark, UI, frame, or labels
```

## Prop Prompt

```text
Create a stylised fantasy RTS prop for a wizard strategy game.

Asset: [ASSET NAME]
Biome: [BIOME]
Purpose: [BLOCKER / DECORATION / RESOURCE / LANDMARK]
Footprint: [FOOTPRINT] tiles
Height: [HEIGHT] Godot units

Design a chunky, readable [PROP TYPE] with a strong silhouette visible from an oblique top-down RTS camera. Use [PRIMARY COLOUR FAMILY] with [ACCENT COLOUR] accents. The prop should feel hand-crafted, low-poly, and magical, with broad shapes and minimal fine detail.

Important:
- If blocker: base must clearly fill its gameplay tile.
- If decoration: must not look like a blocker.
- If resource: must stand out from terrain and props.
- Avoid photorealism, thin branches, tiny noise, labels, text, UI, and watermarks.

Output as [transparent PNG / concept render / orthographic reference].
```

## Building Prompt

```text
Create a stylised fantasy RTS building for a wizard strategy game.

Asset: [ASSET NAME]
Biome: [BIOME]
Gameplay role: [ROLE]
Footprint: [FOOTPRINT] tiles
Height band: [HEIGHT]

The building should have a clear readable footprint and a strong top-down oblique silhouette. Use chunky magical architecture, broad roof masses, readable entrances, and role-defining details. Palette: [COLOUR PALETTE]. Material language: [STONE / WOOD / CRYSTAL / MUSHROOM / RUIN / ARCANE].

Must be readable at RTS camera distance. Avoid tiny roof clutter, photoreal textures, thin spikes, text, UI, and excessive glow.

Output as [concept / 3D render reference / billboard source].
```

## Billboard Unit Prompt

```text
Create a stylised fantasy RTS billboard unit sprite for a wizard strategy game.

Unit: [ASSET NAME]
Role: [ROLE]
Biome/faction: [BIOME OR FACTION]
Footprint: [FOOTPRINT] tile
Pose: [IDLE / WALK / ATTACK / CAST / DEATH]

Design the unit for an oblique top-down RTS camera. The silhouette must clearly show [KEY SILHOUETTE FEATURES]. Use exaggerated readable proportions, broad shapes, and a clean fantasy palette: [COLOUR PALETTE]. Include visible team-colour support on [TEAM COLOUR LOCATION].

Output requirements:
- Transparent background
- Centered sprite
- Consistent ground contact point
- No text, UI, watermark, frame, or shadow baked into the background
- Suitable for billboard rendering in Godot
```

## Terrain Tile Prompt

```text
Create a stylised low-poly fantasy RTS terrain tile.

Terrain type: [LOW / HIGH / CLIFF / ROAD / RAMP / WATER]
Biome: [BIOME]
Gameplay meaning: [MEANING]
Tile scale: 1 gameplay tile

The tile must be clean, chunky, and readable from an RTS camera. Use broad colour areas and low detail. It must visually connect with adjacent tiles and preserve the grid-based shape.

Special rules:
- Road: warm readable path surface, no floating edges.
- Ramp: clear slope from low to high, carved into terrain.
- Cliff: obvious vertical height step.
- Water: flat readable blue surface.

Avoid photorealism, high-frequency noise, labels, UI, and excessive texture variation.
```

## Negative Prompt Library

Use as applicable:

```text
photorealistic, realistic terrain, noisy texture, tiny details, unreadable silhouette, thin fragile shapes, excessive bloom, excessive glow, text, watermark, logo, UI, frame, cropped asset, blurry, dark muddy palette, horror realism, modern objects
```

## Review Checklist

- Does the generated image match the asset spec?
- Is the gameplay footprint clear?
- Is the silhouette readable at RTS distance?
- Does it match the biome?
- Does it avoid noise and realism?
- Can it be cleaned or modeled from?
- Does it need manual paintover?
