# Wizard RTS Style Bible

## Purpose

This style bible defines the visual target for long-term asset production in the wizard RTS project. It applies to procedural terrain, props, buildings, billboard units, biome variants, generated assets, and Blender-authored assets.

The game should read as a stylised fantasy RTS: clear from a pulled-back camera, charming at close inspection, and structured enough for procedural maps. Gameplay readability always wins over realism.

## Overall Art Direction

The world is chunky, readable, magical, and tactical.

Primary influences:

- Low-poly fantasy dioramas
- Voxel-adjacent terrain silhouettes
- Classic RTS readability
- Painted miniature terrain
- Billboard sprite units placed on simple 3D terrain

Avoid:

- Realistic terrain noise
- Thin fragile silhouettes
- High-frequency texture detail
- Overly dark or muddy assets
- Photoreal materials
- Unreadable unit-scale decoration

The target visual language is: broad forms first, clear silhouette second, stylised surface detail third.

## Terrain Style

Terrain is the visual foundation of the map and must preserve the logical grid.

Rules:

- One gameplay tile equals one terrain tile in the visual prototype.
- Low ground is flat and readable.
- High ground forms clear plateaus.
- Cliffs are chunky vertical sides with obvious height contrast.
- Ramps are carved into plateau edges, not pasted beside cliffs.
- Roads sit on terrain surfaces and must not float or clip.
- Water is a flat readable plane below terrain.
- Blockers must visibly occupy gameplay-blocking cells.

Terrain should use broad colour regions with limited texture noise. Edge detail may be added later, but the playable shape must remain clear from the RTS camera.

## Unit Style

Units are planned as billboard sprites or billboard-like hybrid assets.

Rules:

- Units must read at camera distance before animation or detail.
- Silhouette must identify role: caster, melee, ranged, siege, flying, support.
- Team colour must be visible on the upper body, banner, glow, robe trim, weapon effect, or base accent.
- Unit animations should use broad readable poses.
- Small units need exaggerated heads, weapons, hats, staffs, shields, or shoulders.
- Effects must not hide the unit footprint.

Billboard units should be designed for top-down oblique viewing, not side-scroller viewing.

## Prop Style

Props support gameplay readability and biome identity.

Categories:

- Blockers: trees, rocks, ruins, mushrooms, crystal clusters
- Dressing: grass clumps, flowers, small stones, bones, debris
- Landmarks: large ruins, magical stones, ritual circles, statues
- Resource props: crystals, mana wells, ore, harvest nodes

Rules:

- Blocker props must clearly fill their gameplay cell.
- Decorative props must never look like blockers.
- Resource props need a distinct silhouette and colour family.
- Large props should be built from chunky masses, not thin branches or spikes.
- Props should vary in height and width but stay within assigned scale bands.

## Building Style

Buildings should feel like magical RTS structures built from readable blocks.

Rules:

- Footprint must match gameplay footprint.
- Primary silhouette must be visible from the RTS camera.
- Production buildings need strong role identity.
- Defensive buildings need verticality and facing clarity.
- Economy buildings need resource association.
- Magical buildings should use glow accents sparingly.

Avoid small roof clutter that only reads at close camera angles.

## Lighting Style

Lighting should make elevations and silhouettes readable.

Rules:

- Use a warm key light and cool ambient fill.
- Keep shadows soft enough that gameplay cells remain readable.
- Avoid pitch-black blocker clusters.
- High ground should be visibly separated from low ground.
- Magic glows should accent focal points, not replace form readability.

Lighting should support a board-game miniature feeling rather than cinematic realism.

## Colour Palette Philosophy

Use distinct but harmonious colour families by gameplay role.

Terrain:

- Low grass: mid-value green
- High grass: deeper green
- Cliff sides: darker muted green or stone-green
- Roads: warm red-brown or clay
- Ramps: warm debug orange until final ramp art exists
- Water: saturated blue with lower value than terrain

Gameplay markers and debug:

- Base plots: yellow
- Content plots: purple
- Ramps/debug carve: orange/yellow
- Path debug: cyan

Production asset palettes should follow these rules:

- No single biome should become one flat hue.
- Use value contrast before saturation contrast.
- Reserve high saturation for magic, resources, team colour, and selection feedback.
- Keep roads visually distinct from dirt cliffs and props.
- Biome variants may shift hue, but gameplay categories must remain recognizable.

## Silhouette And Readability Rules

Every asset must pass the three-second RTS read test:

1. Can the player tell what category it is?
2. Can the player tell whether it blocks movement?
3. Can the player tell its approximate footprint?

Rules:

- Use broad shapes and stepped proportions.
- Keep important silhouettes visible from a 45 to 60 degree camera angle.
- Avoid long thin protrusions unless they are role-defining.
- Keep units separated from ground colour by value or outline.
- Props on high ground must not hide ramp entrances.
- Building footprints must be legible even when selected markers are off.

## Biome Consistency Rules

Each biome should define:

- Ground colour family
- Cliff colour family
- Road material
- Water treatment
- Blocker prop family
- Resource visual treatment
- Landmark material language
- Ambient lighting bias

Biome swaps should not change gameplay meaning. A forest tree, desert cactus, crystal pillar, and mushroom blocker can all replace the same blocker role if their footprint and readability match.

Biome variants must preserve:

- Road readability
- Ramp readability
- Water readability
- Blocker readability
- Base/content plot readability
- Unit contrast

## Production Readiness Checklist

Before an asset enters the project:

- It has an asset spec.
- Its footprint matches gameplay needs.
- Its pivot is correct.
- It has an approved silhouette from RTS camera distance.
- It has a biome assignment.
- It has export settings documented.
- It has Godot import settings verified.
- It does not rely on final shaders to be readable.
