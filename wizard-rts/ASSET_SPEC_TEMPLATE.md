# Asset Spec Template

Use this template for every production asset request, whether authored by hand, generated with AI, or built in Blender.

## Asset Identity

- Asset name:
- Asset id:
- Category:
- Subcategory:
- Biome:
- Variant count:
- Priority:
- Owner:
- Status:

## Gameplay Purpose

- Gameplay purpose:
- Blocks movement: yes/no
- Selectable: yes/no
- Targetable: yes/no
- Used by procedural generation: yes/no
- Placement context:
- Related systems:

## Footprint And Scale

- Gameplay footprint in tiles:
- Visual footprint in Godot units:
- Height in Godot units:
- Pivot location:
- Ground contact area:
- Overhang allowed: yes/no
- Clearance notes:

## Silhouette

- Primary read:
- Secondary read:
- Camera angle requirements:
- Must be readable at default RTS zoom: yes/no
- Important silhouette features:
- Forbidden silhouette features:

## Colour Palette

- Primary colour family:
- Secondary colour family:
- Accent colour:
- Team colour support: yes/no
- Emissive or magic colour:
- Biome palette notes:
- Value contrast requirement:

## Materials And Surface Treatment

- Material style:
- Texture style:
- Roughness target:
- Metallic: yes/no
- Transparency: yes/no
- Shader requirements:
- Fallback material:

## Animation Requirements

- Animation required: yes/no
- Idle:
- Move:
- Attack:
- Cast:
- Death/despawn:
- Looping requirements:
- Frame count or duration:
- Billboard frame directions:

## Export Requirements

- Source file:
- Export format:
- Godot destination path:
- Texture destination path:
- Naming convention:
- Scale:
- Apply transforms before export: yes/no
- Pivot checked: yes/no
- Collision required: yes/no
- Billboard render required: yes/no

## Procedural Placement Rules

- Allowed biomes:
- Allowed terrain:
- Minimum spacing:
- Maximum density:
- Can appear near roads: yes/no
- Can appear near ramps: yes/no
- Can appear in base plots: yes/no
- Can appear in content plots: yes/no
- Edge placement rules:

## Acceptance Checklist

- Matches gameplay footprint.
- Reads clearly at RTS camera distance.
- Matches biome palette.
- Does not hide roads, ramps, or units.
- Imported into Godot at correct scale.
- Has preview screenshot.
- Has source file retained.
- Has fallback material or placeholder.

## Notes

- Open questions:
- References:
- Revision history:
